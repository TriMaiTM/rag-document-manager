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

  test "renders new workspace form" do
    get new_workspace_url

    assert_response :success
    assert_select "h1", "Tạo Workspace"
    assert_select "form"
  end 

  test "creates workspace with valid parameters" do
    assert_difference("Workspace.count", 1) do
      post workspaces_url, params: {
        workspace: {
          name: "New Workspace",
          description: "Workspace được tạo trong test."
        }
      }
    end

    created_workspace = Workspace.order(:created_at).last
    assert_redirected_to workspace_url(created_workspace)
    follow_redirect!

    assert_response :success
    assert_select "h1", "New Workspace"
    assert_select "[role='status']",
      text: "Workspace đã được tạo thành công."
  end

  test "does not create workspace with invalid parameters" do
    assert_no_difference("Workspace.count") do
      post workspaces_url, params: {
        workspace: {
          name: "",
          description: "Thiếu tên Workspace."
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "[role='alert']"
  end
end






