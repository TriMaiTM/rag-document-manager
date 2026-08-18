require "test_helper"

class OnboardingControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "newuser_onboarding@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  test "redirects existing user with workspace away from onboarding" do
    user_with_workspace = users(:one)
    sign_in user_with_workspace
    get onboarding_url

    assert_redirected_to workspaces_url
  end

  test "renders onboarding wizard for user without workspace" do
    sign_in @user
    get onboarding_url

    assert_response :success
    assert_select "h1", "Chào mừng bạn đến với Codexys!"
  end

  test "completes onboarding by updating user name and creating first workspace" do
    sign_in @user

    assert_difference -> { @user.workspaces.reload.count } => 1 do
      patch onboarding_url, params: {
        onboarding: {
          name: "Trần Văn B",
          workspace_name: "Dự án Nghiên cứu",
          workspace_description: "Mô tả dự án"
        }
      }
    end

    assert_equal "Trần Văn B", @user.reload.name
    workspace = @user.workspaces.first
    assert_equal "Dự án Nghiên cứu", workspace.name
    assert_redirected_to workspace_chat_sessions_url(workspace)
  end
end
