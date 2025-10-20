class Api::PublicBetaController < ApplicationController
  # Skip CSRF protection for API endpoints
  skip_before_action :verify_authenticity_token
  # Skip authentication for public API
  skip_before_action :require_authentication

  # GET /api/public-beta
  def index
    render json: {
      endpoints: {
        projects: "/api/public-beta/projects",
        project: "/api/public-beta/project/:id",
        user: "/api/public-beta/user/:id_or_slack_id",
        shop: "/api/public-beta/shop",
        leaderboard: "/api/public-beta/leaderboard"
      }
    }
  end

  # GET /api/public-beta/projects
  def projects
    projects = Project.visible.order(created_at: :desc).map do |project|
      {
        id: project.id,
        name: project.name,
        description: project.description,
        status: project.status,
        repo_url: project.repo_url,
        demo_url: project.demo_url,
        created_at: project.created_at,
        updated_at: project.updated_at,
        user: {
          id: project.user.id,
          name: project.user.name,
          display_name: project.user.display_name
        },
        week_badge_text: project.week_badge_text,
        coin_value: project.coin_value,
        is_update: project.is_update
      }
    end

    render json: { projects: projects }
  end

  # GET /api/public-beta/project/:id
  def project
    project = Project.find_by(id: params[:id])

    if project.nil?
      render json: { error: "Project not found" }, status: :not_found
      return
    end

    # Only return visible projects
    unless project.visible?
      render json: { error: "Project not found" }, status: :not_found
      return
    end

    render json: {
      id: project.id,
      name: project.name,
      description: project.description,
      status: project.status,
      repo_url: project.repo_url,
      demo_url: project.demo_url,
      created_at: project.created_at,
      updated_at: project.updated_at,
      user: {
        id: project.user.id,
        name: project.user.name,
        display_name: project.user.display_name
      },
      week_badge_text: project.week_badge_text,
      coin_value: project.coin_value,
      is_update: project.is_update
    }
  end

  # GET /api/public-beta/user/:id_or_slack_id
  def user
    user = find_user(params[:id_or_slack_id])

    if user.nil?
      render json: { error: "User not found" }, status: :not_found
      return
    end

    projects = user.projects.visible.order(created_at: :desc).map do |project|
      {
        id: project.id,
        name: project.name,
        status: project.status,
        created_at: project.created_at,
        week_badge_text: project.week_badge_text
      }
    end

    render json: {
      id: user.id,
      slack_id: user.slack_id,
      name: user.name,
      display_name: user.display_name,
      coins: user.coins,
      rank: user.rank,
      status: user.status,
      created_at: user.created_at,
      projects: projects
    }
  end

  # GET /api/public-beta/shop
  def shop
    cosmetics = Cosmetic.where(purchasable: true).order(:cost).map do |cosmetic|
      {
        id: cosmetic.id,
        name: cosmetic.name,
        description: cosmetic.description,
        type: cosmetic.type,
        cost: cosmetic.cost
      }
    end

    physical_items = PhysicalItem.where(purchasable: true).order(:cost).map do |item|
      {
        id: item.id,
        name: item.name,
        description: item.description,
        cost: item.cost,
        digital: item.digital
      }
    end

    render json: {
      cosmetics: cosmetics,
      physical_items: physical_items
    }
  end

  # GET /api/public-beta/leaderboard
  def leaderboard
    users = User.where.not(status: "banned").order(coins: :desc).limit(50).map do |user|
      {
        id: user.id,
        slack_id: user.slack_id,
        name: user.name,
        display_name: user.display_name,
        coins: user.coins,
        rank: user.rank
      }
    end

    render json: { leaderboard: users }
  end

  private

  def find_user(id_or_slack_id)
    # Try to find by ID first, then by slack_id
    user = User.find_by(id: id_or_slack_id)
    user ||= User.find_by(slack_id: id_or_slack_id)
    user
  end

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end
end