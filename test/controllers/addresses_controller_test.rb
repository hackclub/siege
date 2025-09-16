require "test_helper"

class AddressesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get address_url
    assert_response :success
  end

  test "should get new" do
    get new_address_url
    assert_response :success
  end

  test "should get edit" do
    get edit_address_url
    assert_response :success
  end
end
