require "test_helper"

class Rag::EvaluateRetrievalTest < ActiveSupport::TestCase
  FakeDocument = Data.define(:id, :title)
  FakeChunk = Data.define(
    :document_id,
    :document,
    :page_number,
    :neighbor_distance
  )

  class FakeSearcher
    def initialize(chunks: [], error: nil)
      @chunks = chunks
      @error = error
    end

    def call
      raise error if error

      SemanticSearch::Search::Result.new(
        query: "evaluation query",
        chunks: chunks
      )
    end

    private

    attr_reader :chunks, :error
  end

  test "calculates retrieval, no-answer, error, and latency metrics" do
    cases = evaluation_cases
    calls = []
    results_by_query = {
      cases.first.question => [
        fake_chunk("Other Guide", 1, 0.1, 10),
        fake_chunk("Rails Security Guide", 3, 0.2, 11)
      ],
      cases.second.question => [
        fake_chunk("Unrelated Guide", 4, 0.3, 12)
      ],
      cases.third.question => []
    }
    factory = lambda do |**arguments|
      calls << arguments
      FakeSearcher.new(
        chunks: results_by_query.fetch(arguments[:query])
      )
    end
    clock_values = [ 0.0, 0.1, 1.0, 1.3, 2.0, 2.2 ]

    report = Rag::EvaluateRetrieval.new(
      workspace: workspaces(:one),
      cases: cases,
      searcher_factory: factory,
      clock: -> { clock_values.shift }
    ).call

    assert_equal 3, report.case_count
    assert_in_delta 0.40, report.max_cosine_distance
    assert_equal "google", report.embedding_provider
    assert_equal "gemini-embedding-001", report.embedding_model
    assert_equal 1_536, report.embedding_dimensions
    assert_equal 1_200, report.chunk_max_chars
    assert_equal 200, report.chunk_overlap_chars
    assert_equal 2, report.answerable_count
    assert_equal 1, report.unanswerable_count
    assert_equal 1, report.hit_count
    assert_in_delta 0.5, report.hit_rate
    assert_in_delta 0.25, report.mean_reciprocal_rank
    assert_equal 1, report.no_answer_correct_count
    assert_in_delta 1.0, report.no_answer_accuracy
    assert_equal 2, report.correct_count
    assert_in_delta 2.0 / 3, report.overall_accuracy
    assert_equal 0, report.error_count
    assert_in_delta 0.0, report.error_rate
    assert_in_delta 200.0, report.average_milliseconds
    assert_in_delta 300.0, report.p95_milliseconds
    assert_in_delta 0.0, report.average_embedding_milliseconds
    assert_in_delta 0.0, report.p95_embedding_milliseconds
    assert_in_delta 0.0, report.average_vector_search_milliseconds
    assert_in_delta 0.0, report.p95_vector_search_milliseconds
    assert_equal 2, report.results.first.hit_rank
    assert_not report.results.second.hit
    assert report.results.third.correct
    assert_not report.recommended_case_count_met
    assert_not report.target_hit_rate_met
    assert report.target_p95_met
    assert calls.all? { |arguments|
      arguments[:workspace] == workspaces(:one) &&
        arguments[:limit] == 5 &&
        arguments[:max_cosine_distance] == 0.40
    }
  end

  test "records an error and continues evaluating later cases" do
    cases = evaluation_cases.first(2)
    call_count = 0
    factory = lambda do |**_arguments|
      call_count += 1

      if call_count == 1
        FakeSearcher.new(error: Net::ReadTimeout.new("timeout"))
      else
        FakeSearcher.new(
          chunks: [ fake_chunk("Active Record Guide", 9, 0.2, 13) ]
        )
      end
    end
    clock_values = [ 0.0, 0.1, 1.0, 1.1 ]

    report = Rag::EvaluateRetrieval.new(
      workspace: workspaces(:one),
      cases: cases,
      searcher_factory: factory,
      clock: -> { clock_values.shift }
    ).call

    assert_equal "Net::ReadTimeout",
      report.results.first.error_class
    assert_not report.results.first.hit
    assert report.results.second.hit
    assert_equal 1, report.error_count
    assert_in_delta 0.5, report.error_rate
    assert_equal 2, call_count
  end

  test "marks an unanswerable case incorrect when retrieval returns context" do
    evaluation_case = evaluation_cases.third
    factory = lambda do |**_arguments|
      FakeSearcher.new(
        chunks: [ fake_chunk("Unrelated Guide", 1, 0.2, 14) ]
      )
    end
    clock_values = [ 0.0, 0.1 ]

    report = Rag::EvaluateRetrieval.new(
      workspace: workspaces(:one),
      cases: [ evaluation_case ],
      searcher_factory: factory,
      clock: -> { clock_values.shift }
    ).call

    assert_not report.results.sole.correct
    assert_nil report.hit_rate
    assert_nil report.mean_reciprocal_rank
    assert_in_delta 0.0, report.no_answer_accuracy
  end

  test "serializes metadata without chunk content" do
    evaluation_case = evaluation_cases.first
    factory = lambda do |**_arguments|
      FakeSearcher.new(
        chunks: [ fake_chunk("Rails Security Guide", 3, 0.2, 11) ]
      )
    end
    clock_values = [ 0.0, 0.1 ]

    report = Rag::EvaluateRetrieval.new(
      workspace: workspaces(:one),
      cases: [ evaluation_case ],
      searcher_factory: factory,
      clock: -> { clock_values.shift }
    ).call.to_h

    source = report.fetch(:results).sole
      .fetch(:retrieved_sources).sole

    assert_equal "Rails Security Guide",
      source.fetch(:document_title)
    assert_not source.key?(:content)
  end

  private

  def evaluation_cases
    Rag::EvaluationDataset.new(
      path: file_fixture("rag_evaluation.yml")
    ).call
  end

  def fake_chunk(title, page_number, distance, id)
    document = FakeDocument.new(id: id, title: title)

    FakeChunk.new(
      document_id: id,
      document: document,
      page_number: page_number,
      neighbor_distance: distance
    )
  end
end
