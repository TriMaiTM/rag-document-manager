require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "renders registration form without authentication" do
    get new_registration_url

    assert_response :success
    assert_select "h1", "Đăng ký tài khoản"
    assert_select "form"
  end

  test "creates user and starts a session" do
    assert_difference("User.count", 1) do
      assert_difference("Session.count", 1) do
        post registration_url, params: {
          user: {
            email_address: "new-user@example.com",
            password: "password",
            password_confirmation: "password"
          }
        }
      end
    end

    created_user = User.find_by!(email_address: "new-user@example.com")

    assert created_user.authenticate("password")
    assert cookies[:session_id]
    assert_redirected_to workspaces_url
  end

  test "does not create user with invalid parameters" do
    assert_no_difference([ "User.count", "Session.count" ]) do
      post registration_url, params: {
        user: {
          email_address: "invalid-email",
          password: "short",
          password_confirmation: "different"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "[role='alert']"
    assert_select "input[name='user[email_address]'][value='invalid-email']"
  end

  test "does not create user with a duplicate email" do
    assert_no_difference("User.count") do
      post registration_url, params: {
        user: {
          email_address: " ONE@EXAMPLE.COM ",
          password: "password",
          password_confirmation: "password"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "[role='alert']"
  end

  test "redirects authenticated user away from registration" do
    sign_in_as users(:one)

    get new_registration_url

    assert_redirected_to root_url
  end
end
