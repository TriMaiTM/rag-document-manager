require "test_helper"

module Documents
  class GeminiOcrTest < ActiveSupport::TestCase
    test "returns empty string if file does not exist" do
      result = GeminiOcr.new(file_path: "nonexistent.pdf").call
      assert_equal "", result
    end
  end
end
