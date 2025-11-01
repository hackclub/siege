class WatchPartiesController < ApplicationController
  before_action :require_admin_access, only: [:new, :create, :update_state, :destroy]
  before_action :set_watch_party, only: [:show, :update_state, :destroy]

  def index
    @watch_parties = WatchParty.order(created_at: :desc)
  end

  def show
  end

  def new
    @watch_party = WatchParty.new
  end

  def create
    @watch_party = WatchParty.new(watch_party_params)
    
    if @watch_party.save
      redirect_to watch_party_path(@watch_party), notice: "Watch party created! Video is being processed..."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update_state
    @watch_party.update(
      current_time: params[:current_time].to_f,
      is_playing: params[:is_playing] == "true",
      last_updated_at: Time.current
    )
    
    @watch_party.broadcast_state
    
    head :ok
  end

  def destroy
    @watch_party.destroy
    redirect_to watch_parties_path, notice: "Watch party deleted successfully!"
  end

  private

  def set_watch_party
    @watch_party = WatchParty.find(params[:id])
  end

  def watch_party_params
    params.require(:watch_party).permit(:title, :video)
  end

  def require_admin_access
    unless can_access_admin?
      redirect_to root_path, alert: "You don't have permission to access this page."
    end
  end
end
