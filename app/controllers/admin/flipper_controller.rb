class Admin::FlipperController < ApplicationController
  before_action :require_super_admin_access

  def index
    @features = Flipper.features.map do |feature|
      {
        key: feature.key,
        enabled: feature.enabled?,
        gates: feature.gates.map { |gate| gate_info(gate) },
        description: feature_description(feature.key)
      }
    end

    # Get all flags that are used in the codebase but not yet added to the UI
    @available_flags = get_available_flags
  end

  private

  def require_super_admin_access
    unless current_user&.super_admin?
      redirect_to keep_path, alert: "Access denied. Super admin privileges required."
    end
  end

  def gate_info(gate)
    # Extract useful information from different gate types
    case gate.class.name
    when "Flipper::Gates::Boolean"
      { type: "boolean", enabled: gate.enabled?(nil) }
    when "Flipper::Gates::Group"
      { type: "group", groups: gate.enabled_groups }
    when "Flipper::Gates::Actor"
      { type: "actor", actors: gate.enabled_actors }
    when "Flipper::Gates::PercentageOfTime"
      { type: "percentage_of_time", percentage: gate.percentage }
    when "Flipper::Gates::PercentageOfActors"
      { type: "percentage_of_actors", percentage: gate.percentage }
    else
      { type: "unknown", class: gate.class.name }
    end
  rescue => e
    { type: "error", message: e.message }
  end

  def feature_description(key)
    # You can add descriptions for your features here
    descriptions = {
      "extra_week" => "Allow users to submit hours from the previous week along with the current week for a project",
      "ballot_verification_required" => "Require users to be identity verified before they can create a ballot for voting",
      "voting_any_day" => "Allow voting to happen on any day of the week, not just Monday-Wednesday",
      "bypass_10_hour_requirement" => "Allow users to submit projects without reaching 10 hours of coding time",
      "preparation_phase" => "Enable preparation phase mode - removes siege requirements and shows coins around castle instead of meeple track",
      "great_hall_closed" => "Close the great hall to all users, preventing voting and showing a closed message",
      "market_enabled" => "Enable the market feature - allows users to access the market page and make purchases"
    }
    descriptions[key] || "No description available"
  end

  def get_available_flags
    # All flags that are used in the codebase
    code_flags = [
      "extra_week",
      "bypass_10_hour_requirement",
      "ballot_verification_required",
      "voting_any_day",
      "preparation_phase",
      "great_hall_closed",
      "market_enabled"
    ]

    # Get flags that are currently in the UI
    ui_flags = Flipper.features.map(&:key)

    # Return flags that are in code but not in UI
    available_flags = code_flags - ui_flags

    available_flags.map do |flag|
      {
        key: flag,
        description: feature_description(flag)
      }
    end
  end
end
