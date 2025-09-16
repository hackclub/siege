class MeepleController < ApplicationController
  def current_color
    if current_user&.meeple
      color = current_user.meeple.color
      asset_path = ActionController::Base.helpers.asset_path("meeple/meeple-#{color}.png")
      render json: { color: color, asset_path: asset_path }
    else
      render json: { error: "No meeple found" }, status: :not_found
    end
  end

  def asset_paths
    colors = %w[blue red pink green orange purple cyan yellow]
    paths = {}

    colors.each do |color|
      paths[color] = ActionController::Base.helpers.asset_path("meeple/meeple-#{color}.png")
    end

    render json: { asset_paths: paths }
  end
end
