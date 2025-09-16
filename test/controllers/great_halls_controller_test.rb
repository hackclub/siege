require "test_helper"

class GreatHallsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get great_halls_index_url
    assert_response :success
  end
end
