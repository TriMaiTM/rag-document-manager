require "test_helper"

class AccountSettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
  end

  test "renders account settings inside the application shell" do
    get edit_user_registration_url

    assert_response :success
    assert_select "aside.sidebar"
    assert_select "section.account-settings-page"
    assert_select "nav.account-settings-nav"
    assert_select ".workspace-nav-item--active", count: 1
    assert_select "h2", "Hồ sơ & bảo mật"
    assert_select ".auth-shell", count: 0
  end
end
