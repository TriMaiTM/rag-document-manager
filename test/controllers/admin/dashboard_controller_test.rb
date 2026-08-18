require "test_helper"

module Admin
  class DashboardControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      @admin = users(:two)
      @admin.update!(system_role: :system_admin)
    end

    test "redirects normal user from admin dashboard" do
      sign_in @user
      get admin_dashboard_url

      assert_redirected_to root_url
      assert_equal "Bạn không có quyền truy cập trang quản trị hệ thống.", flash[:alert]
    end

    test "allows system admin to access admin dashboard" do
      sign_in @admin
      get admin_dashboard_url

      assert_response :success
      assert_select "h1", "Quản trị Hệ thống"
    end
  end
end
