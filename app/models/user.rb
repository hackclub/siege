class User < ApplicationRecord
  # Validations
  validates :slack_id, presence: true, uniqueness: true
  validates :rank, presence: true, inclusion: { in: %w[user viewer reviewer admin super_admin] }
  validates :status, presence: true, inclusion: { in: %w[new working out banned] }
  validates :referrer_id, presence: false, allow_nil: true
  validates :main_device, inclusion: { in: %w[framework_12 framework_13 ipad_mini oneplus_pad_2 galaxy_tab_s10_fe laptop_grant_base], allow_nil: true }
  validates :on_fraud_team, inclusion: { in: [ true, false ] }
  validate :referrer_validation

  # Flipper integration
  def flipper_id
    "User;#{id}"
  end

  # Automatically register user with Flipper after creation/update
  after_create :register_with_flipper
  after_create :create_default_meeple
  after_create :create_user_weeks
  after_update :register_with_flipper, if: :saved_change_to_rank?

  # Associations
  has_many :projects, dependent: :destroy
  has_one :address, dependent: :destroy
  has_one :meeple, dependent: :destroy
  has_many :ballots, dependent: :destroy
  belongs_to :referrer, class_name: "User", optional: true
  has_many :referrals, class_name: "User", foreign_key: "referrer_id", dependent: :nullify
  has_many :shop_purchases, class_name: "::ShopPurchase"
  has_many :user_weeks, dependent: :destroy

  after_create :ensure_flipper_registration
  after_update :ensure_flipper_registration, if: :saved_change_to_rank?
  accepts_nested_attributes_for :address

  # Ensure audit_logs is always an array
  def audit_logs
    super || []
  end

  # Add audit log entry
  def add_audit_log(action:, actor:, details: {})
    # Prevent recursion by checking if we're already in an audit log update
    return if @updating_audit_logs

    @updating_audit_logs = true

    log_entry = {
      timestamp: Time.current.iso8601,
      action: action,
      actor_id: actor&.id,
      actor_name: actor&.name,
      target_user_id: id,
      target_user_name: name,
      details: details
    }

    current_logs = audit_logs
    new_logs = current_logs + [ log_entry ]

    # Keep only the last 1000 audit log entries to prevent unbounded growth
    new_logs = new_logs.last(1000) if new_logs.length > 1000

    update_column(:audit_logs, new_logs)
  ensure
    @updating_audit_logs = false
  end

  # Class methods
  def self.from_omniauth(auth, referrer_id = nil)
    Rails.logger.info "from_omniauth called with auth.uid: #{auth.uid}"
    Rails.logger.info "Referrer ID from cookie: #{referrer_id}"

    slack_id = auth.uid.split("-").second
    user_info = auth.info
    extra_info = auth.extra

    Rails.logger.info "Extracted slack_id: #{slack_id}"
    Rails.logger.info "User info: #{user_info.inspect}"
    Rails.logger.info "Extra info: #{extra_info.inspect}"

    # Check if user already exists
    existing_user = find_by(slack_id: slack_id)
    Rails.logger.info "Existing user found: #{existing_user.present?}"
    Rails.logger.info "Existing user ID: #{existing_user&.id}"
    Rails.logger.info "Existing user referrer_id: #{existing_user&.referrer_id}"

    if existing_user
      # User exists - just update basic info, don't change referrer_id
      user = existing_user
      user.update(
        email: user_info.email,
        name: user_info.name,
        team_id: extra_info&.dig("raw_info", "https://slack.com/team_id"),
        team_name: extra_info&.dig("raw_info", "https://slack.com/team_name")
      )

      # Log user sign in
      user.add_audit_log(
        action: "User signed in",
        actor: user,
        details: {
          "slack_id" => slack_id,
          "name" => user.name
        }
      )
    else
      # New user - create with referrer_id if provided
      user = create!(
        slack_id: slack_id,
        email: user_info.email,
        name: user_info.name,
        team_id: extra_info&.dig("raw_info", "https://slack.com/team_id"),
        team_name: extra_info&.dig("raw_info", "https://slack.com/team_name"),
        referrer_id: referrer_id,
        rank: "user",
        status: "new"
      )

      # Log user registration
      user.add_audit_log(
        action: "User registered",
        actor: user,
        details: {
          "slack_id" => slack_id,
          "name" => user.name,
          "referrer_id" => referrer_id
        }
      )
    end

    Rails.logger.info "User created/found: #{user.inspect}"
    Rails.logger.info "User persisted: #{user.persisted?}"
    Rails.logger.info "User errors: #{user.errors.full_messages}" unless user.persisted?

    # Try to update display name from Slack, but don't fail if it doesn't work
    begin
      user.update_display_name_from_slack
    rescue => e
      Rails.logger.warn "Could not fetch Slack display name for user #{user.id}: #{e.message}"
      # Continue with authentication even if Slack API call fails
    end

    user
  end

  def self.refresh_all_display_names
    find_each(&:update_display_name_from_slack)
  end

  # Project creation methods
  def project_creation_error(date = Date.current, exclude_project_id = nil)
    return "You have been banned from Siege." if banned?
    return nil if !has_project_this_week?(date, exclude_project_id)
    "You can only create one project per week"
  end

  # Check if user can submit a project (allows submission in the week after creation)
  def can_submit_project_this_week?(date = Date.current, exclude_project_id = nil)
    # Banned users cannot submit projects
    return false if banned?

    # Users can submit projects created in the current week or the previous week
    # as long as they don't have any projects created in the current week (other than the one being submitted)

    # Get the event-based week for this date to match the app's week calculation
    week_number = ApplicationController.helpers.week_number_for_date(date)
    week_range = ApplicationController.helpers.week_date_range(week_number)

    return false unless week_range

    week_start = Date.parse(week_range[0])
    week_end = Date.parse(week_range[1])

    # Check for projects created this week (excluding the current project being submitted)
    scope = projects.where(created_at: week_start.beginning_of_day..week_end.end_of_day)
    scope = scope.where.not(id: exclude_project_id) if exclude_project_id
    return false if scope.exists?

    # Allow submission of projects created last week that are still building
    true
  end

  # Slack integration
  def update_display_name_from_slack
    return unless slack_id.present?

    slack_data = fetch_slack_user_data
    if slack_data
      update(
        name: slack_data[:real_name],
        display_name: slack_data[:display_name]
      )
    end
  rescue => e
    Rails.logger.error "Failed to fetch Slack user data for user #{id}: #{e.message}"
  end

  # Rank helper methods
  def user?
    rank == "user"
  end

  def viewer?
    rank == "viewer"
  end

  def reviewer?
    rank == "reviewer"
  end

  def admin?
    rank == "admin"
  end

  def super_admin?
    rank == "super_admin"
  end

  def can_manage_users?
    admin? || super_admin?
  end
  
  def can_review?
    reviewer? || admin? || super_admin?
  end

  # Get the current Slack display name, updating it if needed
  def current_slack_display_name
    # Try to get fresh data from Slack
    slack_data = fetch_slack_user_data
    if slack_data
      if slack_data[:display_name].present? && slack_data[:display_name] != display_name
        update(
          name: slack_data[:real_name],
          display_name: slack_data[:display_name]
        )
        slack_data[:display_name]
      else
        display_name.presence || name
      end
    else
      display_name.presence || name
    end
  rescue => e
    Rails.logger.error "Failed to fetch current Slack display name for user #{id}: #{e.message}"
    display_name.presence || name
  end

  def can_manage_admins?
    super_admin?
  end

  def on_fraud_team?
    on_fraud_team
  end

  def can_access_fraud_dashboard?
    on_fraud_team? || super_admin?
  end

  # Debug method to test Flipper functionality
  def flipper_debug_info
    {
      id: id,
      name: name,
      rank: rank,
      extra_week_enabled: Flipper.enabled?(:extra_week, self),
      bypass_10_hour_enabled: Flipper.enabled?(:bypass_10_hour_requirement, self),
      preparation_phase_enabled: Flipper.enabled?(:preparation_phase, self),
      great_hall_closed_enabled: Flipper.enabled?(:great_hall_closed, self),
      market_enabled: Flipper.enabled?(:market_enabled, self),
      actor_registered: Flipper::Actor.new(self).respond_to?(:flipper_id)
    }
  end

  # Flipper actor interface
  def flipper_id
    id.to_s
  end

  def flipper_properties
    {
      id: id.to_s,
      name: name,
      rank: rank
    }
  end

  # Status helper methods
  def new?
    status == "new"
  end

  def working?
    status == "working"
  end

  def out?
    status == "out"
  end

  def banned?
    status == "banned"
  end

  def active?
    %w[working out].include?(status)
  end

  # Safe serialization for voting - only expose minimal necessary data
  def safe_attributes_for_voting
    {
      id: id,
      name: name,
      meeple: meeple&.safe_attributes_for_voting
    }
  end

  def has_project_this_week?(date, exclude_project_id = nil)
    # Get the event-based week for this date to match the app's week calculation
    week_number = ApplicationController.helpers.week_number_for_date(date)
    week_range = ApplicationController.helpers.week_date_range(week_number)

    return false unless week_range

    week_start = Date.parse(week_range[0])
    week_end = Date.parse(week_range[1])

    # Check for projects created this week
    scope = projects.where(created_at: week_start.beginning_of_day..week_end.end_of_day)
    scope = scope.where.not(id: exclude_project_id) if exclude_project_id
    scope.exists?
  end

  def referral_count
    referrals.count
  end

  # Main device selection methods
  def set_main_device(device_id)
    # Validate that the device_id is one of the allowed main devices
    allowed_devices = %w[framework_12 framework_13 ipad_mini oneplus_pad_2 galaxy_tab_s10_fe laptop_grant_base]
    return false unless allowed_devices.include?(device_id)

    # Update the main device
    update(main_device: device_id)
  end

  def main_device_name
    case main_device
    when "framework_12"
      "Framework 12"
    when "framework_13"
      "Framework 13 Mainboard"
    when "ipad_mini"
      "iPad Mini"
    when "oneplus_pad_2"
      "OnePlus Pad 2"
    when "galaxy_tab_s10_fe"
      "Galaxy Tab S10 FE+"
    when "laptop_grant_base"
      "$650 Laptop Grant"
    else
      nil
    end
  end

  def has_main_device?
    main_device.present?
  end

  # Ensure meeple exists, create if needed
  def ensure_meeple
    meeple || create_meeple(color: "blue", cosmetics: [])
  end

  private

  def referrer_validation
    return unless referrer_id.present?

    # Check if referrer exists
    unless User.exists?(referrer_id)
      errors.add(:referrer_id, "Referrer does not exist")
      return
    end

    # Prevent self-referral (only if user has an ID)
    if id.present? && referrer_id == id
      errors.add(:referrer_id, "Cannot refer yourself")
      return
    end

    # Prevent circular referrals (A refers B, B refers A) - only if user has an ID
    if id.present?
      begin
        referrer = User.find(referrer_id)
        if referrer.referrer_id == id
          errors.add(:referrer_id, "Cannot create circular referral")
        end
      rescue ActiveRecord::RecordNotFound
        # Referrer was deleted between the exists? check and this find
        errors.add(:referrer_id, "Referrer does not exist")
      end
    end
  end

  def register_with_flipper
    # Register this user as a Flipper actor
    # This ensures they're available for individual targeting in Flipper UI
    Flipper::Actor.new(self)
  rescue => e
    Rails.logger.error "Failed to register user #{id} with Flipper: #{e.message}"
  end

  def ensure_flipper_registration
    register_with_flipper
  end

  def create_default_meeple
    create_meeple(color: "blue", cosmetics: []) unless meeple.present?
  end

  def create_user_weeks
    # Create UserWeek records for weeks 1-14 for this new user
    (1..14).each do |week|
      UserWeek.create!(
        user: self,
        week: week,
        project: nil,
        arbitrary_offset: 0,
        mercenary_offset: 0
      )
    end
  rescue => e
    Rails.logger.error "Failed to create UserWeeks for user #{id}: #{e.message}"
  end

  def fetch_slack_user_data
    return nil unless Rails.application.credentials.slack&.dig(:bot_token).present?

    slack_client = Slack::Web::Client.new(token: Rails.application.credentials.slack[:bot_token])
    response = slack_client.users_info(user: slack_id)

    if response.user
      {
        real_name: response.user.real_name,
        display_name: response.user.profile&.display_name&.presence || response.user.name
      }
    else
      nil
    end
  rescue Slack::Web::Api::Errors::MissingScope => e
    Rails.logger.warn "Slack API missing scope error for user #{id}: #{e.message}. Bot token may need 'users:read' scope."
    nil
  rescue => e
    Rails.logger.error "Slack API error for user #{id}: #{e.message}"
    nil
  end
end
