require "test_helper"

class MarketControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    sign_in @user
  end

  test "should redirect to keep when market is disabled" do
    # Disable the market flag
    Flipper.disable(:market_enabled)

    get market_path
    assert_redirected_to keep_path
    assert_equal "The market is currently disabled.", flash[:alert]
  end

  test "should allow access when market is enabled" do
    # Enable the market flag
    Flipper.enable(:market_enabled)

    get market_path
    assert_response :success
  end

  test "should redirect purchase requests when market is disabled" do
    # Disable the market flag
    Flipper.disable(:market_enabled)

    post market_purchase_path, params: { item_name: "Mercenary", coins_spent: 100 }
    assert_redirected_to keep_path
    assert_equal "The market is currently disabled.", flash[:alert]
  end

  test "should redirect mercenary price requests when market is disabled" do
    # Disable the market flag
    Flipper.disable(:market_enabled)

    get market_mercenary_price_path
    assert_redirected_to keep_path
    assert_equal "The market is currently disabled.", flash[:alert]
  end

  test "should redirect user coins requests when market is disabled" do
    # Disable the market flag
    Flipper.disable(:market_enabled)

    get market_user_coins_path
    assert_redirected_to keep_path
    assert_equal "The market is currently disabled.", flash[:alert]
  end

  test "should allow access for individual user when flag is enabled for them" do
    # Enable the market flag for the specific user
    Flipper.enable(:market_enabled, @user)

    get market_path
    assert_response :success
  end

  test "should deny access for individual user when flag is disabled for them but enabled globally" do
    # Enable globally but disable for specific user
    Flipper.enable(:market_enabled)
    Flipper.disable(:market_enabled, @user)

    get market_path
    assert_redirected_to keep_path
    assert_equal "The market is currently disabled.", flash[:alert]
  end
end
