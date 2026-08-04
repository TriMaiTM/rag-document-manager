require "test_helper"

class Rag::EvaluationDatasetTest < ActiveSupport::TestCase
  test "loads normalized cases and optional page numbers" do
    cases = Rag::EvaluationDataset.new(
      path: file_fixture("rag_evaluation.yml")
    ).call

    assert_equal 3, cases.size
    assert_equal "rails-security", cases.first.id
    assert_equal "Rails bảo vệ request như thế nào?",
      cases.first.question
    assert_equal "Rails Security Guide",
      cases.first.expected_sources.sole.document_title
    assert_equal 3,
      cases.first.expected_sources.sole.page_number
    assert_nil cases.second.expected_sources.sole.page_number
    assert cases.first.answerable
    assert_not cases.third.answerable
    assert_empty cases.third.expected_sources
  end

  test "rejects sources on an unanswerable case" do
    path = Tempfile.new([ "invalid-evaluation", ".yml" ])
    path.write(<<~YAML)
      cases:
        - id: invalid-no-answer
          question: "Câu hỏi không có đáp án"
          answerable: false
          expected_sources:
            - document_title: "Unexpected Guide"
              page_number: 1
    YAML
    path.flush

    error = assert_raises(
      Rag::EvaluationDataset::InvalidDatasetError
    ) do
      Rag::EvaluationDataset.new(path: path.path).call
    end

    assert_includes error.message,
      "không có đáp án phải để expected_sources rỗng"
  ensure
    path&.close!
  end

  test "rejects duplicate case ids" do
    error = assert_raises(
      Rag::EvaluationDataset::InvalidDatasetError
    ) do
      Rag::EvaluationDataset.new(
        path: file_fixture("rag_evaluation_duplicate.yml")
      ).call
    end

    assert_includes error.message, "Case id bị trùng"
  end

  test "reports a missing dataset clearly" do
    error = assert_raises(
      Rag::EvaluationDataset::InvalidDatasetError
    ) do
      Rag::EvaluationDataset.new(
        path: Rails.root.join("missing-evaluation.yml")
      ).call
    end

    assert_includes error.message, "Không tìm thấy evaluation dataset"
  end
end
