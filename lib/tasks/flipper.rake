namespace :flipper do
  desc "Sync all users to Flipper for feature flag management"
  task sync_users: :environment do
    puts "Syncing users to Flipper..."

    total_users = User.count
    synced_count = 0

    User.find_each do |user|
      # Add user as an actor (this registers them with Flipper)
      Flipper::Actor.new(user)
      synced_count += 1

      print "\rSynced #{synced_count}/#{total_users} users..."
    end

    puts "\n✅ Successfully synced #{synced_count} users to Flipper!"
    puts "\nAvailable groups:"
    puts "  - users (rank: user)"
    puts "  - viewers (rank: viewer)"
    puts "  - admins (rank: admin)"
    puts "  - super_admins (rank: super_admin)"
    puts "  - staff (viewers, admins, super_admins)"
    puts "  - admin_staff (admins, super_admins)"
    puts "\nYou can now enable features for these groups in the Flipper UI!"
    puts "\nTo test individual user targeting:"
    puts "  - Use user ID (e.g., '123') in the 'Enable for individual actors' section"
    puts "  - Or use group names (e.g., 'admins') in the 'Enable for groups' section"
  end

  desc "Show Flipper groups and their current membership"
  task show_groups: :environment do
    groups = [ :users, :viewers, :admins, :super_admins, :staff, :admin_staff ]

    puts "Flipper Groups Overview:"
    puts "=" * 50

    groups.each do |group_name|
      matching_users = User.all.select { |user| Flipper[group_name].match?(user) }
      puts "\n#{group_name.to_s.humanize}:"
      puts "  Count: #{matching_users.count}"

      if matching_users.any?
        puts "  Users: #{matching_users.map(&:name).join(', ')}"
      end
    end
  end

  desc "Create example feature flags for testing"
  task create_examples: :environment do
    puts "Creating example feature flags..."

    examples = [
      {
        name: "extra_week",
        description: "Projects get 14-day time override (7 days before + regular week)",
        enabled_for: []
      },
      {
        name: "bypass_10_hour_requirement",
        description: "Allow users to submit projects without reaching 10 hours of coding time",
        enabled_for: []
      },
      {
        name: "great_hall_closed",
        description: "Force the great hall to be closed with a castle closed message",
        enabled_for: []
      },
      {
        name: "voting_any_day",
        description: "Allow voting on any day of the week, not just Monday-Wednesday",
        enabled_for: []
      },
      {
        name: "ballot_verification_required",
        description: "Require users to have ID verification before they can vote",
        enabled_for: []
      },
      {
        name: "preparation_phase",
        description: "Enable preparation phase mode - removes siege requirements and shows coins around castle instead of meeple track",
        enabled_for: []
      },
      {
        name: "market_enabled",
        description: "Enable the market feature - allows users to access the market page and make purchases",
        enabled_for: []
      }
    ]

    examples.each do |example|
      feature = Flipper[example[:name]]

      # Add description if supported
      begin
        feature.add_metadata(description: example[:description])
      rescue
        # Ignore if metadata not supported
      end

      # Enable for specified groups
      example[:enabled_for].each do |group|
        feature.enable_group(group)
        puts "✅ Enabled '#{example[:name]}' for group '#{group}'"
      end
    end

    puts "\n🎉 Example feature flags created! Check them out in the Flipper UI."
  end

  desc "Apply time overrides to existing projects based on current Flipper flags"
  task apply_time_overrides: :environment do
    puts "Applying time overrides to existing projects..."

    updated_count = 0
    total_projects = Project.count

    Project.includes(:user).find_each do |project|
      if project.user
        old_override = project.time_override_days
        project.update_time_override_from_flipper!
        new_override = project.reload.time_override_days

        if old_override != new_override
          updated_count += 1
          puts "✓ Updated project '#{project.name}' (User: #{project.user.name}): #{old_override || 'none'} → #{new_override || 'none'}"
        end
      end
    end

    puts "\n📊 Summary:"
    puts "  Total projects: #{total_projects}"
    puts "  Projects updated: #{updated_count}"
    puts "  Projects unchanged: #{total_projects - updated_count}"

    if updated_count > 0
      puts "\n✅ Time overrides applied successfully!"
    else
      puts "\n💡 No projects needed updating (all were already correct)."
    end
  end

  desc "Test Flipper functionality for a specific user"
  task :test_user, [ :user_id ] => :environment do |t, args|
    user_id = args[:user_id]

    if user_id.blank?
      puts "Usage: rails flipper:test_user[USER_ID]"
      puts "Example: rails flipper:test_user[123]"
      exit 1
    end

    user = User.find_by(id: user_id)
    unless user
      puts "❌ User with ID #{user_id} not found"
      exit 1
    end

    puts "Testing Flipper functionality for user:"
    puts "  ID: #{user.id}"
    puts "  Name: #{user.name}"
    puts "  Rank: #{user.rank}"
    puts ""

    # Test individual actor
    actor = Flipper::Actor.new(user)
    puts "Actor Info:"
    puts "  Flipper ID: #{actor.flipper_id}"
    puts "  Flipper Properties: #{actor.flipper_properties}"
    puts ""

    # Test feature flags
    puts "Feature Flags:"
    puts "  extra_week: #{Flipper.enabled?(:extra_week, user)}"
    puts "  bypass_10_hour_requirement: #{Flipper.enabled?(:bypass_10_hour_requirement, user)}"
    puts "  great_hall_closed: #{Flipper.enabled?(:great_hall_closed, user)}"
    puts "  voting_any_day: #{Flipper.enabled?(:voting_any_day, user)}"
    puts "  ballot_verification_required: #{Flipper.enabled?(:ballot_verification_required, user)}"
    puts "  preparation_phase: #{Flipper.enabled?(:preparation_phase, user)}"
    puts "  market_enabled: #{Flipper.enabled?(:market_enabled, user)}"
    puts ""

    # Test groups
    puts "Group Membership:"
    groups = [ :users, :viewers, :admins, :super_admins, :staff, :admin_staff ]
    groups.each do |group|
      is_member = Flipper[group].enabled?(user)
      puts "  #{group}: #{is_member ? '✅' : '❌'}"
    end
  end
end
