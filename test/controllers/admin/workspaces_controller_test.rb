require "test_helper"

module Admin
  class WorkspacesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = users(:two)
      @admin.update!(system_role: :system_admin)
      @workspace = workspaces(:one)
    end

    test "allows system admin to list workspaces" do
      sign_in @admin
      get admin_workspaces_url

      assert_response :success
      assert_select "h1", "Quản lý Workspace"
    end

    test "allows system admin to view workspace details" do
      sign_in @admin
      get admin_workspace_url(@workspace)

      assert_response :success
      assert_select "h1", "Workspace: #{@workspace.name}"
    end
  end
end
