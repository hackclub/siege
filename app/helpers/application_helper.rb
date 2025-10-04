require "ostruct"

module ApplicationHelper
  # Get the display hour goal (9 if flag enabled, 10 otherwise)
  def hour_goal_display
    Flipper.enabled?(:nine_hour_display, current_user) ? 9 : 10
  end
  
  # Get effective hour goal for a user in a specific week (accounting for mercenaries)
  def effective_hour_goal(user, week_number)
    base_goal = 10
    
    # Get week range
    week_range = week_date_range(week_number)
    return base_goal unless week_range
    
    week_start = Date.parse(week_range[0]).beginning_of_day
    week_end = Date.parse(week_range[1]).end_of_day
    
    # Count mercenaries purchased this week
    mercenary_count = user.shop_purchases
      .where(item_name: "Mercenary")
      .where(purchased_at: week_start..week_end)
      .count
    
    # Each mercenary reduces the goal by 1 hour, minimum 0
    [base_goal - mercenary_count, 0].max
  end
  
  # Get effective hour goal for current week
  def current_week_effective_hour_goal
    return 10 unless current_user
    effective_hour_goal(current_user, current_week_number)
  end
  
  # Get effective hour goal in seconds
  def effective_hour_goal_seconds(user, week_number)
    effective_hour_goal(user, week_number) * 3600
  end
  
  # Get mercenary count for a specific week
  def mercenary_count_for_week(user, week_number)
    week_range = week_date_range(week_number)
    return 0 unless week_range
    
    week_start = Date.parse(week_range[0]).beginning_of_day
    week_end = Date.parse(week_range[1]).end_of_day
    
    user.shop_purchases
      .where(item_name: "Mercenary")
      .where(purchased_at: week_start..week_end)
      .count
  end
  
  # Fetch Hackatime projects list for a range; returns an array of hashes with name, total_seconds, percent, etc.
  def hackatime_projects_for(start_date_str, end_date_str)
    hackatime_projects_for_user(current_user, start_date_str, end_date_str)
  end

  def today_user_readable_time
    @todays_user_readable_time ||= begin
      seconds = today_user_seconds_time
      format_time_from_seconds(seconds)
    end
  end

  def today_user_seconds_time
    @today_user_seconds_time ||= begin
      if current_user&.slack_id
        # Special case: If it's Monday, use the same data as weekly siege time
        range = week_date_range(current_week_number)
        if range && Date.current == Date.parse(range[0])
          # It's Monday (start of siege week), so today = this week so far
          return user_seconds_for_week(current_week_number)
        end

        today = Date.current.strftime("%Y-%m-%d")
        tomorrow = (Date.current + 1).strftime("%Y-%m-%d")

        # Use the same project logic as user_seconds_for_week for consistency
        project = current_week_project
        if project&.hackatime_projects&.any?
          # Make a separate API call for today's data to get precise daily hours
          projs = hackatime_projects_for(today, tomorrow)
          total_seconds = 0
          project.hackatime_projects.each do |project_name|
            match = projs.find { |p| p["name"].to_s == project_name.to_s }
            total_seconds += match&.dig("total_seconds") || 0
          end
          total_seconds
        else
          # No fallback - return 0 if no project or no selected projects
          0
        end
      else
        0
      end
    end
  end

  def week_user_readable_time
    @week_user_readable_time ||= begin
      seconds = week_user_seconds_time
      format_time_from_seconds(seconds)
    end
  end
  def week_user_seconds_time
    @week_user_seconds_time ||= begin
      # Use the same logic as user_seconds_for_week for consistency
      user_seconds_for_week(current_week_number)
    end
  end

  # Weeks helpers
  def weeks_so_far
    # Returns an array of week numbers (1..current_week_number)
    (1..current_week_number).to_a
  end

  def week_date_range(week_number)
    return nil unless start_date

    start_date_parsed = Date.parse(start_date.to_s)
    week_start = start_date_parsed + (week_number.to_i - 1).weeks
    week_end   = week_start + 6.days
    [ week_start.strftime("%Y-%m-%d"), week_end.strftime("%Y-%m-%d") ]
  end

  def user_seconds_for_week(week_number)
    return 0 unless current_user

    # Use the original week_date_range for the specific week number
    range = week_date_range(week_number)
    return 0 unless range

    # Get the project for this specific week
    week_start_date = Date.parse(range[0])
    week_end_date = Date.parse(range[1])
    project = current_user.projects.where(created_at: week_start_date.beginning_of_day..week_end_date.end_of_day).order(created_at: :asc).first

    # If there's a project with selected Hackatime projects, use its effective time range for tracking
    if project&.hackatime_projects&.any?
      range = project.effective_time_range
      return 0 unless range && range[0] && range[1]

      projs = hackatime_projects_for(*range)
      total_seconds = 0
      project.hackatime_projects.each do |project_name|
        match = projs.find { |p| p["name"].to_s == project_name.to_s }
        total_seconds += match&.dig("total_seconds") || 0
      end
      return total_seconds
    end

    # No fallback - return 0 if no project or no selected projects
    0
  end



  def user_human_readable_for_week(week_number)
    seconds = user_seconds_for_week(week_number)
    format_time_from_seconds(seconds)
  end



  # Determine this week's project record, if any, and return its selected Hackatime project names
  def current_week_selected_project_names
    return nil unless current_user
    range = week_date_range(current_week_number)
    return nil unless range
    week_start_date = Date.parse(range[0])
    week_end_date = Date.parse(range[1])
    prj = current_user.projects.where(created_at: week_start_date.beginning_of_day..week_end_date.end_of_day).order(created_at: :asc).first
    return nil unless prj
    arr = prj[:hackatime_projects]
    return nil unless arr.is_a?(Array) && arr.any?
    arr
  end

  def start_date
    Rails.application.credentials.event[:start_date]
  end

  def current_week_number
    return 0 unless start_date

    start_date_parsed = Date.parse(start_date.to_s)
    current_date = Date.current

    # calculate the number of weeks between start date and today
    # add 1 to include the current week
    ((current_date - start_date_parsed).to_i / 7) + 1
  end

  def week_number_for_date(date)
    return 0 unless start_date

    start_date_parsed = Date.parse(start_date.to_s)
    project_date = date.to_date

    # calculate the number of weeks between start date and project date
    # add 1 to include the current week
    ((project_date - start_date_parsed).to_i / 7) + 1
  end



  def current_week_text
    "Week #{current_week_number}"
  end

  def voting_day?
    # If voting_any_day flag is enabled for the current user, any day is a voting day
    return true if current_user && Flipper.enabled?(:voting_any_day, current_user)

    today = Date.current
    allowed_days = [ 1, 2, 3 ] # Monday = 1, Tuesday = 2, Wednesday = 3
    allowed_days.include?(today.wday)
  end

  # Project creation helpers for UI


  def project_creation_message_now
    return "Sign in to create a project" unless current_user
    current_user.project_creation_error || "You can create a project!"
  end



  def today_coding_message
    return "Sign in to track your coding time" unless current_user

    # Check if there's a project for this week
    project = current_week_project
    if project.nil?
      "Create a project to start tracking your coding time"
    elsif project.hackatime_projects.blank?
      "Add a Hackatime project to your project to track coding time"
    else
      seconds = today_user_seconds_time
      if seconds == 0
        "you haven't coded yet today!"
      else
        "today you coded #{today_user_readable_time}"
      end
    end
  end

  def current_week_project
    return nil unless current_user
    range = week_date_range(current_week_number)
    return nil unless range
    week_start_date = Date.parse(range[0])
    week_end_date = Date.parse(range[1])
    current_user.projects.where(created_at: week_start_date.beginning_of_day..week_end_date.end_of_day).order(created_at: :asc).first
  end



  # Consistent time formatting function
  def format_time_from_seconds(seconds)
    return "0h" if seconds.to_i == 0

    hours = (seconds / 3600).floor
    minutes = ((seconds % 3600) / 60).round

    # Handle edge case where rounding minutes gives us 60
    if minutes == 60
      hours += 1
      minutes = 0
    end

    hours > 0 ? "#{hours}h #{minutes}m" : "#{minutes}m"
  end



  def get_leaderboard_users
    # Get all users with their current week hours using the same logic as Siege time
    range = week_date_range(current_week_number)
    return [] unless range

    week_start_date = Date.parse(range[0])
    week_end_date = Date.parse(range[1])

    # Get all users and preload their projects to avoid N+1 queries
    users = User.includes(:projects)

    users_with_hours = users.map do |user|
      # Get projects for this user in the current week
      projects = user.projects.select { |p| p.created_at.between?(week_start_date.beginning_of_day, week_end_date.end_of_day) }

      # Calculate week seconds using the new helper method
      week_seconds = 0
      if projects.any?
        week_seconds = user_hackatime_time_for_projects(user, projects, range)
      end

      # Create a simple object with the data we need
      OpenStruct.new(
        name: user.name,
        current_week_seconds: week_seconds,
        current_week_readable_time: format_time_from_seconds(week_seconds)
      )
    end

    # Sort by hours (descending) and take top 5
    users_with_hours.sort_by { |u| -u.current_week_seconds }.first(5)
  end



  # Format a date range for human display
  def format_date_range(start_date, end_date)
    return nil unless start_date && end_date

    start_parsed = Date.parse(start_date.to_s)
    end_parsed = Date.parse(end_date.to_s)

    # Same month and year
    if start_parsed.year == end_parsed.year && start_parsed.month == end_parsed.month
      "#{start_parsed.strftime('%b %-d')} - #{end_parsed.strftime('%-d, %Y')}"
    # Same year
    elsif start_parsed.year == end_parsed.year
      "#{start_parsed.strftime('%b %-d')} - #{end_parsed.strftime('%b %-d, %Y')}"
    # Different years
    else
      "#{start_parsed.strftime('%b %-d, %Y')} - #{end_parsed.strftime('%b %-d, %Y')}"
    end
  end

  def user_hackatime_time_for_projects(user, projects, time_range = nil)
    return 0 unless projects&.any?

    # If no time range provided, use the first project's effective time range
    unless time_range
      first_project = projects.first
      time_range = first_project.effective_time_range
      return 0 unless time_range
    end

    # Get hackatime data for the user in that time range
    projs = hackatime_projects_for_user(user, *time_range)
    return 0 if projs.empty?

    # Sum up the total seconds for all selected hackatime projects across all projects
    total_seconds = 0
    projects.each do |project|
      next unless project.hackatime_projects&.any?

      project.hackatime_projects.each do |project_name|
        match = projs.find { |p| p["name"].to_s == project_name.to_s }
        total_seconds += match&.dig("total_seconds") || 0
      end
    end

    total_seconds
  end

  def project_total_hackatime_time(project)
    return 0 unless project.hackatime_projects&.any?

    # Get the project's effective time range
    range = project.effective_time_range
    return 0 unless range

    # Get hackatime data for the user in that time range
    projs = hackatime_projects_for_user(project.user, *range)
    return 0 if projs.empty?

    # Sum up the total seconds for all selected hackatime projects
    total_seconds = 0
    project.hackatime_projects.each do |project_name|
      match = projs.find { |p| p["name"].to_s == project_name.to_s }
      total_seconds += match&.dig("total_seconds") || 0
    end

    total_seconds
  end

  def hackatime_projects_for_user(user, start_date_str, end_date_str)
    Rails.logger.info "[Hackatime] Called for user: #{user&.name} (#{user&.slack_id}), dates: #{start_date_str} to #{end_date_str}"

    return [] unless user&.slack_id

    clean_id = user.slack_id.sub(/^T0266FRGM-/, "")
    cache_key = [ "hackatime", "stats", "features:projects", clean_id, start_date_str, end_date_str ].join(":")

    # Add one day to the end date for the API request
    adjusted_end_date = (Date.parse(end_date_str) + 1.day).strftime("%Y-%m-%d")

    # Calculate proper Eastern Time offset (handles DST automatically)
    # Use Time.zone or fallback to Eastern Time detection
    begin
      eastern_time = Time.zone.parse("#{start_date_str} 00:00:00")
      timezone_offset = eastern_time.strftime("%z")
    rescue
      # Fallback: Determine if we're in DST or EST
      start_date_time = Date.parse(start_date_str).to_time
      # Simple DST detection for US Eastern Time (second Sunday in March to first Sunday in November)
      year = start_date_time.year
      dst_start = Date.new(year, 3, 8 + (7 - Date.new(year, 3, 8).wday) % 7) # Second Sunday in March
      dst_end = Date.new(year, 11, 1 + (7 - Date.new(year, 11, 1).wday) % 7) # First Sunday in November

      if start_date_time.to_date.between?(dst_start, dst_end)
        timezone_offset = "-0400" # EDT (Daylight Saving Time)
      else
        timezone_offset = "-0500" # EST (Standard Time)
      end
    end

    Rails.logger.info "[Hackatime] Cache key: #{cache_key}"

    # For debugging, check if we have cached data
    cached_data = Rails.cache.read(cache_key)
    if cached_data
      Rails.logger.info "[Hackatime] Found cached data with #{cached_data.dig('data', 'projects')&.length || 0} projects"
    else
      Rails.logger.info "[Hackatime] No cached data found, making API call"
    end

    data = Rails.cache.fetch(cache_key, expires_in: hackatime_cache_ttl(start_date_str, end_date_str)) do
      url = "https://hackatime.hackclub.com/api/v1/users/#{clean_id}/stats?start_date=#{start_date_str}T00:00:00#{timezone_offset}&end_date=#{adjusted_end_date}T00:00:00#{timezone_offset}&features=projects"

      begin
        uri = URI(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true if uri.scheme == "https"
        http.open_timeout = 10
        http.read_timeout = 30

        request = Net::HTTP::Get.new(uri)
        request["RACK_ATTACK_BYPASS"] = Rails.application.credentials.hackatime_key
        response = http.request(request)

        Rails.logger.info "[Hackatime] Request URL: #{url}"
        Rails.logger.info "[Hackatime] Response: #{response.code} (#{response.body.length} chars)"

        unless response.is_a?(Net::HTTPSuccess)
          Rails.logger.error "[Hackatime] API returned non-success status: #{response.code} #{response.message}"
          Rails.logger.error "[Hackatime] Response body: #{response.body}"
          return {}
        end

        parsed_result = JSON.parse(response.body)
        projects_count = parsed_result.dig("data", "projects")&.length || 0
        Rails.logger.info "[Hackatime] Projects found: #{projects_count}"

        # Log project names for debugging
        if projects_count > 0
          project_names = parsed_result.dig("data", "projects").map { |p| p["name"] }.join(", ")
          Rails.logger.info "[Hackatime] Project names: #{project_names}"
        else
          Rails.logger.warn "[Hackatime] No projects found for user #{clean_id} between #{start_date_str} and #{end_date_str}"
        end

        parsed_result
      rescue JSON::ParserError => e
        Rails.logger.error "[Hackatime] JSON parse error: #{e.message}"
        Rails.logger.error "[Hackatime] Response body that failed to parse: #{response&.body}"
        {}
      rescue => e
        Rails.logger.error "[Hackatime] Error fetching projects: #{e.class}: #{e.message}"
        Rails.logger.error "[Hackatime] Backtrace: #{e.backtrace.first(5).join(', ')}"
        {}
      end
    end

    # Return the full data for other uses, but also provide a projects method
    if block_given?
      yield(data)
    else
      projects = data.dig("data", "projects")
      projects.is_a?(Array) ? projects : []
    end
  end

  private

  # Short TTL for current ranges, longer for historical ranges.
  def hackatime_cache_ttl(start_date_str, end_date_str)
    begin
      start_date = Date.parse(start_date_str.to_s)
      end_date   = Date.parse(end_date_str.to_s)
      today = Date.current
      # If the requested range overlaps today (active data), cache briefly.
      if (start_date..end_date).cover?(today)
        5.minutes
      else
        24.hours
      end
    rescue
      10.minutes
    end
  end

  # Unified helper function for getting a user's meeple with color and cosmetics
  def user_meeple_data(user = nil)
    user ||= current_user
    return nil unless user&.meeple

    meeple = user.meeple

    # Get equipped cosmetics grouped by type (with proper eager loading)
    equipped_cosmetics = meeple.equipped_cosmetics.includes(cosmetic: { image_attachment: :blob }).group_by { |mc| mc.cosmetic.type }

    # Build the data structure
    {
      user: user,
      meeple: meeple,
      color: meeple.color,
      unlocked_colors: meeple.unlocked_colors,
      image_path: asset_path("meeple/meeple-#{meeple.color}.png"),
      equipped_cosmetics: equipped_cosmetics,
      unlocked_cosmetics: meeple.unlocked_cosmetics.includes(cosmetic: { image_attachment: :blob }),
      all_cosmetics: meeple.meeple_cosmetics.includes(cosmetic: { image_attachment: :blob })
    }
  end

  def safe_url(url)
    return nil if url.blank?

    begin
      uri = URI.parse(url.to_s.strip)
      return uri.to_s if uri.scheme&.match?(/\A(https?)\z/)
    rescue URI::InvalidURIError
      # Invalid URL format
    end

    nil
  end

  def safe_project_link(text, url, options = {})
    safe_url_value = safe_url(url)
    if safe_url_value
      link_to(text, safe_url_value, options)
    else
      content_tag(:span, "Invalid #{text}", class: options[:class] ? "#{options[:class]} disabled" : "disabled")
    end
  end
end
