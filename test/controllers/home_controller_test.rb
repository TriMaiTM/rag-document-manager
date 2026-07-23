require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "renders the Codexys homepage" do
    get root_url

    assert_response :success
    assert_select "h1", "Codexys"
    assert_select "h2", "Trạng thái dự án"
  end
end