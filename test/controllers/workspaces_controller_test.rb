require "test_helper"

class WorkspacesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:one)
  end

  test "renders workspace index" do
    get workspaces_url

    assert_response :success
    assert_select "h1", "Danh sách Workspace"
    assert_select "a", text: @workspace.name
  end

  test "renders workspace details" do
    get workspace_url(@workspace)

    assert_response :success
    assert_select "h1", @workspace.name
    assert_select "a", text: "Danh sách Workspace"
  end
end