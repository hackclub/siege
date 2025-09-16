class UserDecorator < Draper::Decorator
  delegate_all

  def today_readable_time
    helpers.today_user_readable_time
  end

  def today_seconds_time
    helpers.today_user_seconds_time
  end

  def week_readable_time
    helpers.week_user_readable_time
  end

  def week_seconds_time
    helpers.week_user_seconds_time
  end

  def seconds_for_week(week_number)
    helpers.user_seconds_for_week(week_number)
  end

  def human_readable_for_week(week_number)
    helpers.user_human_readable_for_week(week_number)
  end

  def coins
    object.coins || 0
  end

  def week_seconds(week_number)
    range = helpers.week_date_range(week_number)
    return 0 unless range

    # Get the projects for this specific week and user
    week_start_date = Date.parse(range[0])
    week_end_date = Date.parse(range[1])
    projects = object.projects.where(created_at: week_start_date.beginning_of_day..week_end_date.end_of_day)

    # Use the new helper method to calculate total hackatime time
    helpers.user_hackatime_time_for_projects(object, projects, range)
  end

  def effective_time_range_for_new_project
    return [ nil, nil ] unless object

    # Create a temporary project and let it determine its own time override
    temp_project = object.projects.build(created_at: Time.current)
    temp_project.set_time_override_from_flipper

    # Get the effective range based on the calculated override
    temp_project.effective_time_range
  end
end
