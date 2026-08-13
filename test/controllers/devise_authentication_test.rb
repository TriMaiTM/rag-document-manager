require "test_helper"

class DeviseAuthenticationTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "renders the sign in form" do
    get new_user_session_path

    assert_response :success
    assert_select "form[action='#{user_session_path}']"
  end

  test "signs in with valid credentials" do
    post user_session_path, params: {
      user: {
        email: @user.email,
        password: "password"
      }
    }

    assert_redirected_to workspaces_path
  end

  test "does not sign in with invalid credentials" do
    post user_session_path, params: {
      user: {
        email: @user.email,
        password: "wrong-password"
      }
    }

    assert_response :unprocessable_content
  end

  test "signs out" do
    sign_in @user

    delete destroy_user_session_path

    assert_redirected_to root_path

    get workspaces_path
    assert_redirected_to new_user_session_path
  end

  test "registers a new user" do
    assert_difference("User.count", 1) do
      post user_registration_path, params: {
        user: {
          email: "new-user@example.com",
          password: "password",
          password_confirmation: "password"
        }
      }
    end

    user = User.find_by!(email: "new-user@example.com")

    assert user.valid_password?("password")
    assert_redirected_to workspaces_path
  end

  test "sends password reset instructions" do
    assert_emails 1 do
      post user_password_path, params: {
        user: { email: @user.email }
      }
    end

    assert_redirected_to new_user_session_path
  end
end
