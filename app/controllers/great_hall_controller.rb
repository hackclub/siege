require "ostruct"

class GreatHallController < ApplicationController
  before_action :check_access_permissions
  before_action :check_not_banned
  before_action :preload_current_user_cosmetics

  def index
    # If access was denied, render was already handled in before_action
    return if performed?

    # Check if ballot verification is required and user is not verified
    if Flipper.enabled?(:ballot_verification_required, current_user) && current_user.idv_rec.blank?
      @verification_required = true
      @fallback_message = "You must complete identity verification before you can vote."
      return
    end

    # Check for trick or treating feature
    if Flipper.enabled?(:trick_or_treating, current_user)
      last_interaction = check_recent_trick_or_treat_interaction
      unless last_interaction
        @voting_state = :trick_or_treating
        @trick_or_treat_meeple_color = %w[blue red pink green orange purple cyan yellow].sample
        @votes_json = "[]"
        @ballot = OpenStruct.new(id: 0)
        render :voting_summary
        return
      end
    end

    # Check if user has a ballot for the previous week
    previous_week = helpers.current_week_number - 1

    # Allow voting with any week number (including 0 or negative for testing)
    
    # If multiple ballots allowed, find most recent unvoted ballot or show already voted state
    # Otherwise, find the only ballot (enforced by uniqueness constraint)
    if Flipper.enabled?(:allow_multiple_ballots, current_user)
      @ballot = current_user.ballots.where(week: previous_week, voted: false).order(created_at: :desc).first
      
      # If no unvoted ballot and user is not explicitly creating a new one, show already_voted state
      if @ballot.nil? && params[:create_new] != 'true'
        voted_ballot = current_user.ballots.where(week: previous_week, voted: true).order(created_at: :desc).first
        if voted_ballot
          @ballot = voted_ballot
          @voting_state = :already_voted
          @meeple_message = "What wise logic you have! Your declaration has been submitted. Here are three coins for your trouble!"
          @votes_json = "[]"
          @allow_revote = true
          render :voting_summary
          return
        end
        # Otherwise fall through to create new ballot
      end
    else
      @ballot = current_user.ballots.find_by(week: previous_week)
    end

    if @ballot
      if @ballot.voted?
        @voting_state = :already_voted
        @meeple_message = "What wise logic you have! Your declaration has been submitted. Here are three coins for your trouble!"
        @votes_json = "[]"
        @allow_revote = Flipper.enabled?(:allow_multiple_ballots, current_user)
        render :voting_summary
      else
        # Check if this is a dummy ballot (no votes) and re-evaluate
        if @ballot.votes.empty?
          # Delete the dummy ballot and try to create a real one
          @ballot.destroy
          if create_ballot_with_votes(previous_week)
            redirect_to great_hall_path(step: 1)
            return
          else
            # Still no projects available
            @voting_state = :closed
            @meeple_message = "The diplomats are on their way! They may take a day to arrive."
            @votes_json = "[]"
            @ballot = OpenStruct.new(id: 0) # Dummy ballot to prevent nil error
            render :voting_summary
            return
          end
        end

        # Show the existing ballot with its votes
        @voting_state = :voting
        @votes = @ballot.votes.includes(project: { user: :meeple })

        # Serialize the votes data for JavaScript with minimal user data exposure
        @votes_json = @votes.map do |vote|
          vote_data = {
            id: vote.id,
            week: vote.week,
            voted: vote.voted,
            star_count: vote.star_count,
            project: vote.project.safe_attributes_for_voting.merge(
              user: vote.project.user.safe_attributes_for_voting
            )
          }
          vote_data
        end.to_json
        @current_step = params[:step]&.to_i || 1
        @total_steps = @votes.count + 1 # +1 for summary step

        if @current_step <= @votes.count
          # Show individual project review
          @current_vote = @votes[@current_step - 1]
        end
        # Always render the unified voting view
        render :voting_summary
      end
    else
      # Create a new ballot with 4 votes
      if create_ballot_with_votes(previous_week)
        redirect_to great_hall_path(step: 1)
      else
        # No projects available
        @voting_state = :closed
        @meeple_message = "The diplomats are on their way! They may take a day to arrive."
        @votes_json = "[]"
        @ballot = OpenStruct.new(id: 0) # Dummy ballot to prevent nil error
        render :voting_summary
      end
    end
  end

  def thanks
    @voting_state = :thanks
    @meeple_message = "Thank you for voting!"
    @votes_json = "[]"

    # Set a dummy ballot to prevent template errors (JavaScript won't execute in thanks state)
    @ballot = OpenStruct.new(id: 0)

    render :voting_summary
  end
  
  def reset_ballot
    # Only allow if multiple ballots feature is enabled
    unless Flipper.enabled?(:allow_multiple_ballots, current_user)
      redirect_to great_hall_path, alert: "Multiple ballots are not currently allowed."
      return
    end
    
    # Redirect with create_new flag to bypass already_voted check and create new ballot
    redirect_to great_hall_path(create_new: true)
  end

  def dismiss_trick_or_treater
    current_user.add_audit_log(
      action: "trick_or_treat_dismissed",
      actor: current_user,
      details: {}
    )

    render json: { success: true }
  end

  def give_candy
    if current_user.coins < 5
      render json: { success: false, error: "Insufficient coins" }, status: :unprocessable_entity
      return
    end

    current_user.update!(coins: current_user.coins - 5)

    outcome = determine_trick_or_treat_outcome

    current_user.add_audit_log(
      action: "trick_or_treat_gave_candy",
      actor: current_user,
      details: { outcome: outcome[:type] }
    )

    render json: { success: true, outcome: outcome }
  end

  private

  def create_ballot_with_votes(week)
    # Access permissions already checked in before_action

    # Allow any week number (including 0 or negative for testing)

    # Get projects that are pending voting or submitted for this week
    week_range = helpers.week_date_range(week)
    return unless week_range

    week_start_date = Date.parse(week_range[0])
    week_end_date = Date.parse(week_range[1])

    eligible_projects = Project.visible_to_user(current_user).where(
      created_at: week_start_date.beginning_of_day..week_end_date.end_of_day,
      status: "pending_voting"
    ).where.not(user: current_user) # Exclude user's own projects

    Rails.logger.info "Found #{eligible_projects.count} eligible projects for user #{current_user.id} in week #{week}"

    # Exclude projects that were in previous ballots for this user in this week
    previous_ballot_project_ids = Vote.joins(:ballot)
                                      .where(ballots: { user: current_user, week: week })
                                      .pluck(:project_id)
                                      .uniq

    if previous_ballot_project_ids.any?
      Rails.logger.info "Excluding #{previous_ballot_project_ids.count} projects from previous ballots in week #{week}"
      eligible_projects = eligible_projects.where.not(id: previous_ballot_project_ids)
    end

    Rails.logger.info "After deduplication: #{eligible_projects.count} eligible projects remaining"

    # Pre-calculate actually cast vote counts for all projects in a single query
    # Only count votes where voted: true (actually cast ballots)
    cast_vote_counts = Vote.joins(:project)
                          .where(project: eligible_projects, voted: true)
                          .group(:project_id)
                          .count

    Rails.logger.info "Cast vote counts: #{cast_vote_counts}"

    # Sort projects by cast vote count (least cast votes first) and randomize projects with same vote count
    projects_with_vote_counts = eligible_projects.map do |project|
      cast_vote_count = cast_vote_counts[project.id] || 0
      [ project, cast_vote_count ]
    end.sort_by { |_, cast_vote_count| [ cast_vote_count, rand ] }

    # Take the first 4 projects (or all if less than 4)
    selected_projects = projects_with_vote_counts.first(4).map(&:first)

    Rails.logger.info "Selected #{selected_projects.count} projects for ballot creation"

    # Check if we have enough projects to create a ballot (need at least 4)
    if selected_projects.count < 4
      Rails.logger.info "Not enough projects for ballot: found #{selected_projects.count}, need 4"
      return false # Indicate failure to create ballot
    end

    # Create the ballot with the selected projects
    ActiveRecord::Base.transaction do
      @ballot = current_user.ballots.create!(
        week: week,
        voted: false,
        reasoning: nil
      )

      # Create votes for selected projects only
      selected_projects.each do |project|
        @ballot.votes.create!(
          week: week,
          project: project,
          voted: false,
          star_count: 1
        )
      end
    end

    @votes = @ballot.votes.includes(project: { user: :meeple })

            # Serialize the votes data for JavaScript with explicit includes
            @votes_json = @votes.map do |vote|
              vote_data = {
                id: vote.id,
                week: vote.week,
                voted: vote.voted,
                star_count: vote.star_count,
                project: vote.project.safe_attributes_for_voting.merge(
                  user: vote.project.user.safe_attributes_for_voting
                )
              }
              vote_data
            end.to_json

    true # Indicate successful ballot creation
  rescue => e
    Rails.logger.error "Error creating ballot: #{e.message}"
    @fallback_message = "Error creating ballot. Please try again."
    false # Indicate failure to create ballot
  end

  def check_access_permissions
    # Allow trick-or-treating even when hall is closed
    if Flipper.enabled?(:trick_or_treating, current_user)
      return # Skip all access checks if trick-or-treating is enabled
    end

    # Check if great hall is forced closed
    if Flipper.enabled?(:great_hall_closed, current_user)
      @voting_state = :closed
      @meeple_message = "The castle is currently closed to visitors..."
      @votes_json = "[]"
      @ballot = OpenStruct.new(id: 0)
      render :voting_summary
      return
    end

    # Check if it's Monday through Friday (unless voting_any_day flag is enabled)
    unless Flipper.enabled?(:voting_any_day, current_user) || helpers.voting_day?
      @voting_state = :closed
      @meeple_message = "The castle is only open for visitors between Monday and Friday..."
      @votes_json = "[]"
      @ballot = OpenStruct.new(id: 0)
      render :voting_summary
      nil
    end
  end

  def preload_current_user_cosmetics
    if current_user&.meeple
      current_user.meeple.equipped_cosmetics.includes(cosmetic: :image_attachment).load
    end
  end

  def check_recent_trick_or_treat_interaction
    return false unless current_user.audit_logs.present?

    ten_minutes_ago = 10.minutes.ago

    current_user.audit_logs.any? do |log|
      timestamp = Time.parse(log["timestamp"]) rescue nil
      next false unless timestamp

      timestamp > ten_minutes_ago &&
        (log["action"] == "trick_or_treat_dismissed" || log["action"] == "trick_or_treat_gave_candy")
    end
  end

  def determine_trick_or_treat_outcome
    rand_value = rand(100)

    if rand_value < 10
      { type: "nothing", message: "Thank you!", coins_change: 0 }
    elsif rand_value < 45
      current_user.update!(coins: current_user.coins + 10)
      { type: "coins", message: "Here's your treat :D (+10 <img src=\"#{view_context.asset_path('coin.png')}\" style=\"width: 24px; height: 24px; vertical-align: middle; display: inline-block;\" alt=\"coin\" />)", coins_change: 10 }
    elsif rand_value < 75
      current_user.update!(coins: current_user.coins - 5)
      { type: "trick", message: "Haha tricked you! I just stole 5 <img src=\"#{view_context.asset_path('coin.png')}\" style=\"width: 24px; height: 24px; vertical-align: middle; display: inline-block;\" alt=\"coin\" /> :P", coins_change: -5 }
    elsif rand_value < 90
      cosmetic = select_random_cosmetic_from_pool
      if cosmetic
        current_user.meeple.unlock_cosmetic(cosmetic)
        { type: "cosmetic", message: "Thanks! Here's a cosmetic I had lying around!", cosmetic_name: cosmetic.name }
      else
        determine_trick_or_treat_outcome
      end
    else
      if current_user.meeple.color_unlocked?("yellow")
        determine_trick_or_treat_outcome
      else
        current_user.meeple.unlock_color("yellow")
        { type: "yellow_meeple", message: "Thanks! Here's a random yellow meeple I had lying around :D" }
      end
    end
  end

  def select_random_cosmetic_from_pool
    pool_cosmetics = Cosmetic.where(in_trick_or_treat_pool: true)
    return nil if pool_cosmetics.empty?

    unlocked_cosmetic_ids = current_user.meeple.unlocked_cosmetics.pluck(:cosmetic_id)
    available_cosmetics = pool_cosmetics.where.not(id: unlocked_cosmetic_ids)

    return nil if available_cosmetics.empty?

    available_cosmetics.sample
  end
end
