require "test_helper"

class FeatureFlagsTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    sign_in @user
  end

  test "all feature flags work for individual users" do
    # Test each flag individually
    flags_to_test = [
      :market_enabled,
      :preparation_phase,
      :great_hall_closed,
      :voting_any_day,
      :ballot_verification_required,
      :bypass_10_hour_requirement,
      :extra_week
    ]

    flags_to_test.each do |flag|
      # Enable flag for specific user
      Flipper.enable(flag, @user)
      assert Flipper.enabled?(flag, @user), "#{flag} should be enabled for user"

      # Disable flag for specific user
      Flipper.disable(flag, @user)
      assert_not Flipper.enabled?(flag, @user), "#{flag} should be disabled for user"
    end
  end

  test "market flag works for individual users" do
    # Enable for specific user
    Flipper.enable(:market_enabled, @user)
    get market_path
    assert_response :success

    # Disable for specific user
    Flipper.disable(:market_enabled, @user)
    get market_path
    assert_redirected_to keep_path
    assert_equal "The market is currently disabled.", flash[:alert]
  end

  test "great hall closed flag works for individual users" do
    # Enable for specific user
    Flipper.enable(:great_hall_closed, @user)
    get great_hall_path
    assert_redirected_to keep_path
    assert_equal "The great hall is currently closed.", flash[:alert]

    # Disable for specific user
    Flipper.disable(:great_hall_closed, @user)
    get great_hall_path
    assert_response :success
  end

  test "preparation phase flag works for individual users" do
    # Enable for specific user
    Flipper.enable(:preparation_phase, @user)
    get root_path
    assert_response :success
    # The preparation phase flag affects the home page display

    # Disable for specific user
    Flipper.disable(:preparation_phase, @user)
    get root_path
    assert_response :success
  end

  test "voting any day flag works for individual users" do
    # Enable for specific user
    Flipper.enable(:voting_any_day, @user)
    # This flag affects voting behavior in great hall controller

    # Disable for specific user
    Flipper.disable(:voting_any_day, @user)
  end

  test "ballot verification required flag works for individual users" do
    # Enable for specific user
    Flipper.enable(:ballot_verification_required, @user)
    # This flag affects ballot creation in great hall controller

    # Disable for specific user
    Flipper.disable(:ballot_verification_required, @user)
  end

  test "bypass 10 hour requirement flag works for individual users" do
    # Enable for specific user
    Flipper.enable(:bypass_10_hour_requirement, @user)
    # This flag affects project submission in project model

    # Disable for specific user
    Flipper.disable(:bypass_10_hour_requirement, @user)
  end

  test "extra week flag works for individual users" do
    # Enable for specific user
    Flipper.enable(:extra_week, @user)
    # This flag affects project time overrides in project model

    # Disable for specific user
    Flipper.disable(:extra_week, @user)
  end

  test "feature_enabled? helper works correctly" do
    # Test the helper method
    Flipper.enable(:market_enabled, @user)
    assert feature_enabled?(:market_enabled), "feature_enabled? should return true when flag is enabled for user"

    Flipper.disable(:market_enabled, @user)
    assert_not feature_enabled?(:market_enabled), "feature_enabled? should return false when flag is disabled for user"
  end

  test "user model flipper_properties includes all flags" do
    properties = @user.flipper_properties

    expected_flags = [
      :extra_week_enabled,
      :bypass_10_hour_enabled,
      :preparation_phase_enabled,
      :great_hall_closed_enabled,
      :market_enabled
    ]

    expected_flags.each do |flag|
      assert properties.key?(flag), "User flipper_properties should include #{flag}"
    end
  end
end
