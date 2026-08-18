require "test_helper"

module Admin
  class UsersControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      @admin = users(:two)
      @admin.update!(system_role: :system_admin)
    end

    test "allows system admin to list users" do
      sign_in @admin
      get admin_users_url

      assert_response :success
      assert_select "h1", "Quản lý Người dùng"
    end

    test "allows system admin to view user detail page" do
      sign_in @admin
      get admin_user_url(@user)

      assert_response :success
      assert_select "h1", "Chi tiết Người dùng: #{@user.display_name}"
    end

    test "allows system admin to promote a user to system admin" do
      sign_in @admin
      patch admin_user_url(@user), params: { user: { system_role: "system_admin" } }

      assert_redirected_to admin_users_url
      assert_equal "system_admin", @user.reload.system_role
    end

    test "prevents system admin from demoting self" do
      sign_in @admin
      patch admin_user_url(@admin), params: { user: { system_role: "user" } }

      assert_redirected_to admin_users_url
      assert_equal "system_admin", @admin.reload.system_role
      assert_equal "Bạn không thể tự hạ quyền System Admin của chính mình.", flash[:alert]
    end
  end
end
