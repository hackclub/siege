class Project < ApplicationRecord
  belongs_to :user
  has_many :votes, dependent: :destroy
  has_one_attached :screenshot

  before_create :set_time_override_from_flipper
  after_initialize :set_time_override_from_flipper, if: :new_record?

  validates :name, presence: true
  validates :status, presence: true, inclusion: { in: %w[building submitted pending_voting finished] }
  validates :fraud_status, presence: true, inclusion: { in: %w[unchecked sus fraud good] }
  validates :repo_url, url: { allow_blank: true, no_local: true, schemes: [ "https" ] }
  validates :demo_url, url: { allow_blank: true, no_local: true, schemes: [ "http", "https" ] }
  validates :time_override_days, numericality: { greater_than: 0, allow_nil: true }
  validate :hackatime_projects_is_array_of_strings
  validate :user_can_create_project, on: :create
  validate :user_can_submit_project
  validate :logs_is_array
  validate :repo_url_must_be_github
  validate :screenshot_must_be_image
  validate :screenshot_file_exists, if: -> { screenshot.attached? && !@skip_screenshot_validation && persisted? }

  # Scopes for handling hidden projects
  scope :visible, -> { where(hidden: false) }
  scope :hidden, -> { where(hidden: true) }
  scope :visible_to_user, ->(user) { user&.super_admin? ? all : visible }

  # Ensure logs is always an array
  def logs
    super || []
  end

  # Status helper methods
  def building?
    status == "building"
  end

  def pending_voting?
    status == "pending_voting"
  end

  def finished?
    status == "finished"
  end

  def submitted?
    status == "submitted"
  end

  # Fraud status helper methods
  def fraud_unchecked?
    fraud_status == "unchecked"
  end

  def fraud_sus?
    fraud_status == "sus"
  end

  def fraud_confirmed?
    fraud_status == "fraud"
  end

  def fraud_good?
    fraud_status == "good"
  end

  # Check if project is eligible for fraud review (submitted or above)
  def fraud_reviewable?
    status.in?([ "submitted", "pending_voting", "finished" ])
  end

  # Check if project can be edited by regular users
  def editable_by_user?
    !status.in?([ "pending_voting", "finished" ])
  end

  # Calculate the effective date range for Hackatime tracking
  def effective_time_range
    return standard_week_range unless time_override_days

    # Get the standard week range first
    week_start, week_end = standard_week_range
    return [ week_start, week_end ] unless week_start && week_end

    week_start_date = Date.parse(week_start)
    week_end_date = Date.parse(week_end)

    if time_override_days <= 7
      # Override under 7 days: count from beginning of week
      override_start = week_start_date
      override_end = week_start_date + (time_override_days - 1).days
      [ override_start.strftime("%Y-%m-%d"), override_end.strftime("%Y-%m-%d") ]
    else
      # Override over 7 days: count days before the start of the week + full week
      extra_days = time_override_days - 7
      override_start = week_start_date - extra_days.days
      override_end = week_end_date
      [ override_start.strftime("%Y-%m-%d"), override_end.strftime("%Y-%m-%d") ]
    end
  end

  # Check if screenshot is properly attached and file exists
  def screenshot_valid?
    screenshot.attached? && screenshot.blob.service.exist?(screenshot.blob.key)
  rescue => e
    Rails.logger.error "Error checking screenshot validity for project #{id}: #{e.message}"
    false
  end

  def can_submit?
    return false unless repo_url.present? && demo_url.present? && screenshot_valid? && hackatime_projects.present? && hackatime_projects.any?

    # Check if user is out
    return false if user&.banned?

    # Check if user has bypass flag enabled
    return true if user && Flipper.enabled?(:bypass_10_hour_requirement, user)

    # Check if preparation phase is enabled (removes 10-hour requirement)
    return true if user && Flipper.enabled?(:preparation_phase, user)

    # Check if project has at least 10 hours (36000 seconds)
    range = effective_time_range
    return false unless range && range[0] && range[1]

    projs = ApplicationController.helpers.hackatime_projects_for_user(user, *range)
    total_seconds = 0

    hackatime_projects.each do |project_name|
      match = projs.find { |p| p["name"].to_s == project_name.to_s }
      total_seconds += match&.dig("total_seconds") || 0
    end

    total_seconds >= 36000
  end



  def submit!
    unless can_submit?
      if user&.banned?
        errors.add(:base, "You have been banned from Siege.")
      elsif repo_url.blank? || demo_url.blank? || !screenshot.attached? || hackatime_projects.blank?
        if !screenshot_valid?
          errors.add(:base, "Cannot submit project. Screenshot is missing or corrupted. Please re-upload your screenshot.")
        else
          errors.add(:base, "Cannot submit project. Please ensure you have added a repository URL, demo URL, screenshot, and at least one Hackatime project.")
        end
      else
        # Check if it's the time requirement (unless preparation phase is enabled)
        unless user && Flipper.enabled?(:preparation_phase, user)
          range = effective_time_range
          if range && range[0] && range[1]
            projs = ApplicationController.helpers.hackatime_projects_for_user(user, *range)
            total_seconds = 0

            hackatime_projects.each do |project_name|
              match = projs.find { |p| p["name"].to_s == project_name.to_s }
              total_seconds += match&.dig("total_seconds") || 0
            end

            hours = total_seconds / 3600.0
            errors.add(:base, "Cannot submit project. You need at least 10 hours of coding time. You currently have #{hours.round(1)} hours.")
          else
            errors.add(:base, "Cannot submit project. Unable to calculate coding time.")
          end
        end
      end
      return false
    end

    update!(status: "submitted")

    # Log project submission
    user.add_audit_log(
      action: "Project submitted",
      actor: user,
      details: {
        "project_name" => name,
        "project_id" => id,
        "previous_status" => "building",
        "is_update" => is_update
      }
    )
  end

  # Update status with logging for review purposes
  def update_status!(new_status, reviewer, message = nil)
    old_status = status
    return false if old_status == new_status

    # Create log entry
    log_entry = {
      timestamp: Time.current.iso8601,
      old_status: old_status,
      new_status: new_status,
      reviewer_id: reviewer.id,
      reviewer_name: reviewer.name,
      message: message.presence
    }

    # Skip screenshot validation when updating status to handle corrupted/missing screenshots
    skip_screenshot_validation!

    # Update logs and status
    new_logs = logs + [ log_entry ]
    update!(status: new_status, logs: new_logs)

    # Send Slack notification for pending_voting status
    if new_status == "pending_voting"
      SlackNotificationService.new.send_pending_voting_notification(self)
    end
  end

  # Update fraud status with logging
  def update_fraud_status!(new_fraud_status, new_reasoning, reviewer)
    old_fraud_status = fraud_status
    old_reasoning = fraud_reasoning

    # Skip screenshot validation
    skip_screenshot_validation!

    # Update fraud status and reasoning
    update!(fraud_status: new_fraud_status, fraud_reasoning: new_reasoning)

    # Log to user's audit logs
    user.add_audit_log(
      action: "Project fraud status updated",
      actor: reviewer,
      details: {
        "project_name" => name,
        "project_id" => id,
        "old_fraud_status" => old_fraud_status,
        "new_fraud_status" => new_fraud_status,
        "old_reasoning" => old_reasoning,
        "new_reasoning" => new_reasoning
      }
    )
  end

  # Set time override based on Flipper flags for the user (public for helper access)
  def set_time_override_from_flipper
    return unless user
    return if time_override_days.present? # Don't override manually set values

    # Check if user has the extra_week feature flag enabled
    if Flipper.enabled?(:extra_week, user)
      self.time_override_days = 14
    end
  end

  # Skip screenshot file validation (useful when uploading new screenshot)
  def skip_screenshot_validation!
    @skip_screenshot_validation = true
  end

  # Safe serialization for voting - only expose minimal necessary data
  def safe_attributes_for_voting
    {
      id: id,
      name: name,
      description: description,
      status: status,
      repo_url: repo_url,
      demo_url: demo_url,
      created_at: created_at,
      week_badge_text: week_badge_text
      # Don't include sensitive fields like:
      # - user_id (exposed through user association)
      # - hackatime_projects (personal project names)
      # - logs (admin-only information)
      # - coin_value (financial information)
      # - time_override_days (internal configuration)
    }
  end

  private

  def repo_url_must_be_github
    return if repo_url.blank?

    begin
      uri = URI.parse(repo_url)
      allowed_hosts = [
        'github.com', 'www.github.com',
        'gitlab.com', 'www.gitlab.com',
        'bitbucket.org', 'www.bitbucket.org',
        'codeberg.org', 'www.codeberg.org',
        'sourceforge.net', 'www.sourceforge.net',
        'dev.azure.com',
        'git.hackclub.app'
      ]

      unless allowed_hosts.include?(uri.host)
        errors.add(:repo_url, "must be a repository URL from a supported Git hosting service (GitHub, GitLab, Bitbucket, Codeberg, SourceForge, Azure DevOps, or Hack Club Git)")
      end
    rescue URI::InvalidURIError
      errors.add(:repo_url, "must be a valid repository URL")
    end
  end

  def user_can_create_project
    return unless user && (created_at || Time.current)

    date = created_at || Time.current
    error_message = user.project_creation_error(date, id)

    if error_message
      errors.add(:base, error_message)
    end
  end

  def user_can_submit_project
    return unless user && status_changed? && status == "submitted" && (created_at || Time.current)

    date = created_at || Time.current
    unless user.can_submit_project_this_week?(date, id)
      errors.add(:base, "You can only submit one project per week. You already have a project created this week.")
    end
  end

  def hackatime_projects_is_array_of_strings
    return if self[:hackatime_projects].nil?

    # Allow empty arrays
    return if self[:hackatime_projects].is_a?(Array) && self[:hackatime_projects].empty?

    # For non-empty arrays, ensure all elements are non-empty strings
    unless self[:hackatime_projects].is_a?(Array) && self[:hackatime_projects].all? { |p| p.is_a?(String) && p.present? }
      errors.add(:hackatime_projects, "must be an array of project names")
    end
  end

  def logs_is_array
    return if self[:logs].nil?

    unless self[:logs].is_a?(Array)
      errors.add(:logs, "must be an array")
    end
  end

  def screenshot_must_be_image
    return unless screenshot.attached?

    unless screenshot.content_type.start_with?("image/")
      errors.add(:screenshot, "must be an image file")
    end
  end

  def screenshot_file_exists
    return unless screenshot.attached?

    unless screenshot.blob.service.exist?(screenshot.blob.key)
      Rails.logger.error "Screenshot file missing for project #{id}: #{screenshot.blob.key} - Blob created: #{screenshot.blob.created_at}, Attachment created: #{screenshot.attachment.created_at}"
      Rails.logger.error "Storage service: #{screenshot.blob.service.class.name}, Root: #{screenshot.blob.service.root if screenshot.blob.service.respond_to?(:root)}"
      errors.add(:screenshot, "file is missing from storage")
    end
  end

  # Get the standard week range for this project (public for testing)
  def standard_week_range
    return [ nil, nil ] unless created_at

    # Use the same logic as the helper but return the range directly
    event_start_date = Rails.application.credentials.event&.dig(:start_date)
    return [ nil, nil ] unless event_start_date

    start_date_parsed = Date.parse(event_start_date.to_s)
    project_date = created_at.to_date

    days_since_start = (project_date - start_date_parsed).to_i
    week_number = (days_since_start / 7) + 1

    week_start = start_date_parsed + (week_number - 1).weeks
    week_end = week_start + 6.days

    [ week_start.strftime("%Y-%m-%d"), week_end.strftime("%Y-%m-%d") ]
  end

  # Update time override based on current Flipper flags (for existing projects)
  def update_time_override_from_flipper!
    return unless user

    if Flipper.enabled?(:extra_week, user)
      # Set to 14 days if flag is enabled and not already set
      update!(time_override_days: 14) if time_override_days != 14
    else
      # Remove override if flag is disabled
      update!(time_override_days: nil) if time_override_days.present?
    end
  end

  # Force apply time override from Flipper (ignores existing values)
  def force_apply_time_override_from_flipper!
    return unless user

    if Flipper.enabled?(:extra_week, user)
      self.time_override_days = 14
    else
      self.time_override_days = nil
    end

    save! if persisted?
  end

  # Get week badge text for display
  def week_badge_text
    week_num = ApplicationController.helpers.week_number_for_date(created_at)
    "Week #{week_num}"
  end

end
