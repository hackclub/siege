class ProjectDecorator < Draper::Decorator
  delegate_all

  def week_badge_text
    "Week #{helpers.week_number_for_date(object.created_at)}"
  end

  def week_time
    return "0h" unless object.hackatime_projects&.any?

    # Use the project's effective time range (supports time overrides)
    range = object.effective_time_range
    return "0h" unless range && range[0] && range[1]

    # Use the new helper method to calculate total hackatime time for this specific project
    total_seconds = helpers.project_total_hackatime_time(object)

    # Convert to readable format using consistent formatting
    helpers.format_time_from_seconds(total_seconds)
  end

  def week_hours_numeric
    return 0 unless object.hackatime_projects&.any?

    # Use the new helper method to calculate total hackatime time for this specific project
    total_seconds = helpers.project_total_hackatime_time(object)

    # Convert to hours (decimal)
    (total_seconds / 3600.0).round(1)
  end

  def can_submit?
    return false unless helpers.current_user
    object.can_submit?
  end

  def submission_error
    return nil unless helpers.current_user

    if object.can_submit?
      return nil
    end

    if object.repo_url.blank? || object.demo_url.blank? || object.hackatime_projects.blank?
      return "Please ensure you have added a repository URL, demo URL, and at least one Hackatime project."
    end

    # Check if it's the time requirement (unless preparation phase is enabled)
    unless helpers.current_user && helpers.feature_enabled?(:preparation_phase)
      total_seconds = helpers.project_total_hackatime_time(object)
      if total_seconds > 0
        hours = total_seconds / 3600.0
        week_number = helpers.week_number_for_date(object.created_at)
        effective_goal = helpers.effective_hour_goal(object.user, week_number)
      return "You need at least #{effective_goal} hours of coding time. You currently have #{hours.round(1)} hours."
      end

      "Unable to calculate coding time."
    end
  end

  def can_delete?
    return false unless helpers.current_user

    # Admins can always delete
    return true if helpers.can_access_admin?

    # Project owner can only delete if it's from the current week
    if object.user == helpers.current_user
      current_week = helpers.current_week_number
      project_week = helpers.week_number_for_date(object.created_at)

      # Can only delete if from current week
      return project_week == current_week
    end

    false
  end
end
