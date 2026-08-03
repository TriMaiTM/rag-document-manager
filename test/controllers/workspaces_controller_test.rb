require "test_helper"

class WorkspacesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @workspace = workspaces(:one)

    sign_in_as @user
  end

  test "requires authentication" do
    sign_out

    get workspaces_url

    assert_redirected_to new_user_session_url
  end

  test "renders workspace index" do
    get workspaces_url

    assert_response :success
    assert_select "h1", "Danh sách Workspace"
    assert_select "a", text: @workspace.name
    assert_select "a", text: workspaces(:two).name, count: 0
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
      assert_difference("Membership.count", 1) do
        post workspaces_url, params: {
          workspace: {
            name: "New Workspace",
            description: "Workspace được tạo trong test."
          }
        }
      end
    end

    created_workspace = Workspace.order(:created_at).last
    assert created_workspace.membership_for(@user).owner?
    assert_redirected_to workspace_url(created_workspace)
    follow_redirect!

    assert_response :success
    assert_select "h1", "New Workspace"
    assert_select "[role='status']",
      text: "Workspace đã được tạo thành công."
  end

  test "does not create workspace with invalid parameters" do
    assert_no_difference([ "Workspace.count", "Membership.count" ]) do
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

  test "renders edit workspace form" do
    get edit_workspace_url(@workspace)

    assert_response :success
    assert_select "h1", "Chỉnh sửa Workspace"
    assert_select "form"
    assert_select "input[name='workspace[name]'][value=?]", @workspace.name
  end

  test "updates workspace with valid parameters" do
    patch workspace_url(@workspace), params: {
      workspace: {
        name: "Updated Workspace",
        description: "Mô tả đã được cập nhật."
      }
    }

    assert_redirected_to workspace_url(@workspace)

    @workspace.reload
    assert_equal "Updated Workspace", @workspace.name
    assert_equal "Mô tả đã được cập nhật.", @workspace.description

    follow_redirect!

    assert_response :success
    assert_select "h1", "Updated Workspace"
    assert_select "[role='status']",
      text: "Workspace đã được cập nhật thành công."
  end

  test "does not update workspace with invalid parameters" do
    original_name = @workspace.name

    patch workspace_url(@workspace), params: {
      workspace: {
        name: "",
        description: "Tên không hợp lệ."
      }
    }

    assert_response :unprocessable_entity
    assert_select "[role='alert']"
    assert_equal original_name, @workspace.reload.name
  end

  test "destroys workspace" do
    membership_count = @workspace.memberships.count

    assert_difference("Workspace.count", -1) do
      assert_difference("Membership.count", -membership_count) do
        delete workspace_url(@workspace)
      end
    end

    assert_redirected_to workspaces_url
    follow_redirect!
    assert_response :success
    assert_select "[role='status']",
      text: "Workspace đã được xóa thành công."
    assert_select "h1", "Danh sách Workspace"
  end

  test "returns not found for a workspace outside current user scope" do
    get workspace_url(workspaces(:two))

    assert_response :not_found
  end

  test "member can view but cannot change workspace" do
    sign_out
    sign_in_as users(:two)

    get workspace_url(@workspace)
    assert_response :success
    assert_select "a", text: "Chỉnh sửa Workspace", count: 0
    assert_select "a", text: "Quản lý thành viên", count: 0
    assert_select "button", text: "Xóa Workspace", count: 0

    get edit_workspace_url(@workspace)
    assert_response :forbidden

    assert_no_changes -> { @workspace.reload.name } do
      patch workspace_url(@workspace),
        params: { workspace: { name: "Forbidden change" } }
    end
    assert_response :forbidden

    assert_no_difference("Workspace.count") do
      delete workspace_url(@workspace)
    end
    assert_response :forbidden
  end

  test "admin can update but cannot destroy workspace" do
    sign_out
    sign_in_as users(:three)

    patch workspace_url(@workspace),
      params: { workspace: { name: "Admin updated workspace" } }

    assert_redirected_to workspace_url(@workspace)
    assert_equal "Admin updated workspace", @workspace.reload.name

    assert_no_difference("Workspace.count") do
      delete workspace_url(@workspace)
    end
    assert_response :forbidden
  end
end
