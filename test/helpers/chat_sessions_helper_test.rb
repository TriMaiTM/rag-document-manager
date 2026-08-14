require "test_helper"

class ChatSessionsHelperTest < ActionView::TestCase
  include ChatSessionsHelper

  test "normalize_plain_numbers_in_math unwraps plain numbers and units" do
    input = "Gói linh hoạt có giá $189\\,000$ đồng/tháng, chạy tối đa $400\\text{ km}$."
    expected = "Gói linh hoạt có giá 189 000 đồng/tháng, chạy tối đa 400 km."

    assert_equal expected, normalize_plain_numbers_in_math(input)
  end

  test "normalize_plain_numbers_in_math preserves actual math equations" do
    input = "Công thức $V = \\frac{4}{3}\\pi R^3$ và $3x^2 - 4x - 2 = 0$."

    assert_equal input, normalize_plain_numbers_in_math(input)
  end
end
