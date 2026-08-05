require "test_helper"

class Rag::ProjectEvaluationDatasetTest <
    ActiveSupport::TestCase
  setup do
    @cases = Rag::EvaluationDataset.new(
      path: Rails.root.join(
        "config/rag_evaluation.yml"
      )
    ).call
  end

  test "contains fifteen evaluation cases" do
    assert_equal 15, @cases.size
  end

  test "contains twelve answerable and three unrelated cases" do
    answerable, unrelated =
      @cases.partition(&:answerable)

    assert_equal 12, answerable.size
    assert_equal 3, unrelated.size
    assert unrelated.all? do |evaluation_case|
      evaluation_case.expected_sources.empty?
    end
  end

  test "uses exactly three source documents" do
    document_titles = @cases
      .select(&:answerable)
      .flat_map(&:expected_sources)
      .map(&:document_title)
      .uniq
      .sort

    assert_equal(
      [ "CSDL", "SRS", "TTTN" ],
      document_titles
    )
  end
end
