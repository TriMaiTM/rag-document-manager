require "test_helper"

module Admin
  class SettingsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = users(:two)
      @admin.update!(system_role: :system_admin)
    end

    test "allows system admin to access system settings page" do
      sign_in @admin
      get admin_settings_url

      assert_response :success
      assert_select "h1", "Cài đặt & Trạng thái Hệ thống"
    end

    test "allows system admin to update system settings" do
      sign_in @admin
      patch admin_settings_url, params: {
        settings: {
          chat_model: "gemini-2.5-pro",
          max_contexts: "12"
        }
      }

      assert_redirected_to admin_settings_url
      assert_equal "gemini-2.5-pro", SystemSetting.get("chat_model")
      assert_equal "12", SystemSetting.get("max_contexts")
    end
  end
end
