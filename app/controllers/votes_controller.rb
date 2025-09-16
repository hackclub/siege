class VotesController < ApplicationController
  before_action :check_not_banned
  before_action :require_authentication
  before_action :set_vote, only: [ :update_stars, :toggle_vote ]

  def update_stars
    star_count = params[:star_count].to_i
    if star_count < 1 || star_count > 5
      render json: { success: false, errors: [ "Star count must be between 1 and 5" ] }
      return
    end

    if @vote.update(star_count: star_count)
      render json: { success: true, star_count: @vote.star_count }
    else
      render json: { success: false, errors: @vote.errors.full_messages }
    end
  end

  def toggle_vote
    new_voted_state = !@vote.voted
    if @vote.update(voted: new_voted_state)
      render json: { success: true, voted: @vote.voted }
    else
      render json: { success: false, errors: @vote.errors.full_messages }
    end
  end

  private

  def set_vote
    @vote = Vote.joins(:ballot).where(ballots: { user: current_user }).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, error: "Vote not found" }, status: :not_found
  end
end
