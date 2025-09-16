# Define the Flipper ActiveRecord models if they don't exist
unless defined?(Flipper::Adapters::ActiveRecord::Feature)
  # Define the classes at the top level first
  class FlipperFeature < ::ActiveRecord::Base
    self.table_name = "flipper_features"
    has_many :flipper_gates, foreign_key: :feature_key, primary_key: :key, dependent: :delete_all
  end

  class FlipperGate < ::ActiveRecord::Base
    self.table_name = "flipper_gates"
    belongs_to :flipper_feature, foreign_key: :feature_key, primary_key: :key
  end

  # Then assign them to the Flipper namespace
  Flipper::Adapters::ActiveRecord::Feature = FlipperFeature
  Flipper::Adapters::ActiveRecord::Gate = FlipperGate
end

Flipper.configure do |config|
  # Use a resilient adapter that can handle missing database connections
  # during asset precompilation
  config.adapter do
    begin
      # Try to connect to the database
      ActiveRecord::Base.connection
      Flipper::Adapters::ActiveRecord.new
    rescue ActiveRecord::NoDatabaseError, PG::ConnectionBad, ActiveRecord::ConnectionNotEstablished => e
      # If database is not available (e.g., during asset precompilation),
      # fall back to a memory adapter
      Rails.logger.warn "Database not available for Flipper, using memory adapter: #{e.message}" if defined?(Rails.logger)
      Flipper::Adapters::Memory.new
    end
  end
end

# Configure Flipper UI with safe options
if defined?(Flipper::UI)
  Flipper::UI.configure do |config|
    config.banner_text = "Siege Feature Flags"
    config.banner_class = "info"
    config.feature_creation_enabled = true
    config.feature_removal_enabled = true
  end
end

# Define Flipper groups for user ranks
Flipper.register(:users) do |actor|
  actor.respond_to?(:rank) && actor.rank == "user"
end

Flipper.register(:viewers) do |actor|
  actor.respond_to?(:rank) && actor.rank == "viewer"
end

Flipper.register(:admins) do |actor|
  actor.respond_to?(:rank) && actor.rank == "admin"
end

Flipper.register(:super_admins) do |actor|
  actor.respond_to?(:rank) && actor.rank == "super_admin"
end

# Convenience groups for broader access levels
Flipper.register(:staff) do |actor|
  actor.respond_to?(:rank) && %w[viewer admin super_admin].include?(actor.rank)
end

Flipper.register(:admin_staff) do |actor|
  actor.respond_to?(:rank) && %w[admin super_admin].include?(actor.rank)
end

# Initialize feature flags (only if adapter is available)
begin
  Flipper.add(:ballot_verification_required)
  Flipper.add(:voting_any_day)
  Flipper.add(:preparation_phase)
  Flipper.add(:great_hall_closed)
  Flipper.add(:market_enabled)
rescue => e
  # If we can't add flags (e.g., using memory adapter), just log and continue
  Rails.logger.warn "Could not initialize Flipper feature flags: #{e.message}" if defined?(Rails.logger)
end
