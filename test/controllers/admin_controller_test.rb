require "test_helper"

class AdminControllerTest < ActionDispatch::IntegrationTest
  def setup
    @admin_user = users(:one)
    @target_user = users(:two)
    @referrer_user = users(:three)

    # Make sure we have an admin user
    @admin_user.update!(rank: "admin")
    sign_in @admin_user
  end

  test "should set referrer for user" do
    post admin_set_referrer_path(@target_user), params: { referrer_id: @referrer_user.id }

    assert_redirected_to admin_user_details_path(@target_user)
    assert_equal "Set #{@referrer_user.name} as referrer for #{@target_user.name}", flash[:notice]

    @target_user.reload
    assert_equal @referrer_user.id, @target_user.referrer_id
  end

  test "should clear referrer when referrer_id is 0" do
    @target_user.update!(referrer_id: @referrer_user.id)

    post admin_set_referrer_path(@target_user), params: { referrer_id: 0 }

    assert_redirected_to admin_user_details_path(@target_user)
    assert_equal "Cleared referrer for #{@target_user.name}", flash[:notice]

    @target_user.reload
    assert_nil @target_user.referrer_id
  end

  test "should clear referrer with clear_referrer action" do
    @target_user.update!(referrer_id: @referrer_user.id)

    post admin_clear_referrer_path(@target_user)

    assert_redirected_to admin_user_details_path(@target_user)
    assert_equal "Cleared referrer for #{@target_user.name}", flash[:notice]

    @target_user.reload
    assert_nil @target_user.referrer_id
  end

  test "should not allow self-referral" do
    post admin_set_referrer_path(@target_user), params: { referrer_id: @target_user.id }

    assert_redirected_to admin_user_details_path(@target_user)
    assert_equal "User cannot refer themselves", flash[:alert]

    @target_user.reload
    assert_nil @target_user.referrer_id
  end

  test "should not allow circular referral" do
    @target_user.update!(referrer_id: @referrer_user.id)

    post admin_set_referrer_path(@referrer_user), params: { referrer_id: @target_user.id }

    assert_redirected_to admin_user_details_path(@referrer_user)
    assert_equal "Cannot create circular referral", flash[:alert]

    @referrer_user.reload
    assert_nil @referrer_user.referrer_id
  end

  test "should handle non-existent referrer" do
    post admin_set_referrer_path(@target_user), params: { referrer_id: 99999 }

    assert_redirected_to admin_user_details_path(@target_user)
    assert_equal "Referrer user with ID 99999 not found", flash[:alert]

    @target_user.reload
    assert_nil @target_user.referrer_id
  end
end
