require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "renders the Codexys homepage without authentication" do
    get root_url

    assert_response :success
    assert_select "h1", text: /Làm chủ toàn bộ tri thức tài liệu của bạn/
    assert_select "h2", text: "Khởi tạo nhanh. Xử lý triệt để trong bốn bước."
    assert_select "a", text: "Đăng nhập"
  end

  test "redirects authenticated user to workspaces" do
    sign_in users(:one)
    get root_url

    assert_redirected_to workspaces_url
  end
end
