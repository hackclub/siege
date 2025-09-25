class BallotsController < ApplicationController
  before_action :check_not_banned
  before_action :require_authentication
  before_action :set_ballot, only: [ :submit ]

  def submit
    reasoning = params[:reasoning]&.strip

    if reasoning.blank?
      render json: { success: false, errors: [ "Reasoning is required" ] }
      return
    end

    # Check if ballot has already been submitted
    if @ballot.voted?
      render json: { success: false, errors: [ "This ballot has already been submitted" ] }
      return
    end

    ActiveRecord::Base.transaction do
      # Double-check ballot hasn't been submitted during the request
      @ballot.reload
      if @ballot.voted?
        render json: { success: false, errors: [ "This ballot has already been submitted" ] }
        return
      end

      # Update the ballot
      if @ballot.update(voted: true, reasoning: reasoning)
        # Mark all associated votes as voted
        @ballot.votes.update_all(voted: true)

        # Check if coins have already been awarded for this ballot
        existing_audit = current_user.audit_logs.find do |log|
          log["action"] == "Ballot submitted" && 
          log.dig("details", "ballot_id") == @ballot.id
        end

        if existing_audit
          render json: { success: false, errors: [ "Coins have already been awarded for this ballot" ] }
          return
        end

        # Add 3 coins to user's balance for casting the ballot
        old_balance = current_user.coins || 0
        current_user.increment!(:coins, 3)

        # Log ballot submission and coin reward
        current_user.add_audit_log(
          action: "Ballot submitted",
          actor: current_user,
          details: {
            "ballot_id" => @ballot.id,
            "ballot_week" => @ballot.week,
            "vote_count" => @ballot.votes.count,
            "coins_earned" => 3,
            "previous_balance" => old_balance,
            "new_balance" => current_user.coins
          }
        )

        render json: { success: true, redirect_url: great_hall_path }
      else
        render json: { success: false, errors: @ballot.errors.full_messages }
      end
    end
  end

  private

  def set_ballot
    @ballot = current_user.ballots.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, error: "Ballot not found" }, status: :not_found
  end
end
