require "test_helper"

class SystemSettingTest < ActiveSupport::TestCase
  test "sets and gets system settings by key" do
    SystemSetting.set("custom_key", "custom_value")

    assert_equal "custom_value", SystemSetting.get("custom_key")
  end

  test "returns default value when key does not exist" do
    assert_equal "default_val", SystemSetting.get("non_existent_key", "default_val")
  end
end
