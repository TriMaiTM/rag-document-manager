require "test_helper"

class Rag::SelectCitationsTest < ActiveSupport::TestCase
  test "keeps only cited chunks and normalizes ranks by first use" do
    first = Object.new
    second = Object.new
    third = Object.new

    result = Rag::SelectCitations.new(
      answer: "Second [2], first [1], second again [2].",
      chunks: [ first, second, third ]
    ).call

    assert_equal "Second [1], first [2], second again [1].",
      result.answer
    assert_equal [ second, first ], result.chunks
  end

  test "returns no chunks when the answer contains no citations" do
    result = Rag::SelectCitations.new(
      answer: "Tài liệu hiện có không cung cấp đủ thông tin.",
      chunks: [ Object.new ]
    ).call

    assert_equal "Tài liệu hiện có không cung cấp đủ thông tin.",
      result.answer
    assert_empty result.chunks
  end

  test "removes citation markers that do not map to a context" do
    chunk = Object.new

    result = Rag::SelectCitations.new(
      answer: "Valid [1]. Invalid [9].",
      chunks: [ chunk ]
    ).call

    assert_equal "Valid [1]. Invalid .", result.answer
    assert_equal [ chunk ], result.chunks
  end
end
