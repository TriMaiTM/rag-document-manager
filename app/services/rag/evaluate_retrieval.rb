module Rag
  class EvaluateRetrieval
    DEFAULT_LIMIT = 5
    TARGET_HIT_RATE = 0.8
    TARGET_P95_MILLISECONDS = 1_000.0

    RetrievedSource = Data.define(
      :rank,
      :document_id,
      :document_title,
      :page_number,
      :cosine_distance
    )

    CaseResult = Data.define(
      :id,
      :question,
      :answerable,
      :correct,
      :hit,
      :hit_rank,
      :duration_milliseconds,
      :embedding_milliseconds,
      :vector_search_milliseconds,
      :expected_sources,
      :retrieved_sources,
      :error_class
    )

    Report = Data.define(
      :workspace_id,
      :limit,
      :max_cosine_distance,
      :embedding_provider,
      :embedding_model,
      :embedding_dimensions,
      :chunk_max_chars,
      :chunk_overlap_chars,
      :case_count,
      :answerable_count,
      :unanswerable_count,
      :hit_count,
      :hit_rate,
      :mean_reciprocal_rank,
      :no_answer_correct_count,
      :no_answer_accuracy,
      :correct_count,
      :overall_accuracy,
      :error_count,
      :error_rate,
      :average_milliseconds,
      :p95_milliseconds,
      :average_embedding_milliseconds,
      :p95_embedding_milliseconds,
      :average_vector_search_milliseconds,
      :p95_vector_search_milliseconds,
      :recommended_case_count_met,
      :target_hit_rate_met,
      :target_p95_met,
      :results
    ) do
      def to_h
        super.merge(
          results: results.map do |result|
            result.to_h.merge(
              expected_sources:
                result.expected_sources.map(&:to_h),
              retrieved_sources:
                result.retrieved_sources.map(&:to_h)
            )
          end
        )
      end
    end

    DEFAULT_SEARCHER_FACTORY = lambda do |**arguments|
      SemanticSearch::Search.new(**arguments)
    end

    DEFAULT_CLOCK = lambda do
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def initialize(
      workspace:,
      cases:,
      limit: DEFAULT_LIMIT,
      max_cosine_distance:
        Rails.application.config.x.semantic_search.max_cosine_distance,
      searcher_factory: DEFAULT_SEARCHER_FACTORY,
      clock: DEFAULT_CLOCK
    )
      @workspace = workspace
      @cases = Array(cases)
      @limit = Integer(limit)
      @max_cosine_distance = Float(max_cosine_distance)
      @searcher_factory = searcher_factory
      @clock = clock

      validate_options!
    end

    def call
      results = cases.map { |evaluation_case| evaluate(evaluation_case) }
      durations = results.map(&:duration_milliseconds)
      embedding_durations = results.filter_map(&:embedding_milliseconds)
      vector_search_durations = results.filter_map(
        &:vector_search_milliseconds
      )
      answerable_results = results.select(&:answerable)
      unanswerable_results = results.reject(&:answerable)
      hit_count = answerable_results.count(&:hit)
      hit_rate = ratio(hit_count, answerable_results.size)
      no_answer_correct_count = unanswerable_results.count(&:correct)
      no_answer_accuracy = ratio(
        no_answer_correct_count,
        unanswerable_results.size
      )
      correct_count = results.count(&:correct)
      error_count = results.count { |result| result.error_class.present? }
      p95 = percentile_95(durations)
      vector_search_p95 = percentile_95(vector_search_durations)

      Report.new(
        workspace_id: workspace.id,
        limit: limit,
        max_cosine_distance: max_cosine_distance,
        embedding_provider: Ai::EmbeddingConfig::PROVIDER,
        embedding_model: Ai::EmbeddingConfig::MODEL,
        embedding_dimensions: Ai::EmbeddingConfig::DIMENSIONS,
        chunk_max_chars: Documents::ChunkText::DEFAULT_MAX_CHARS,
        chunk_overlap_chars: Documents::ChunkText::DEFAULT_OVERLAP_CHARS,
        case_count: results.size,
        answerable_count: answerable_results.size,
        unanswerable_count: unanswerable_results.size,
        hit_count: hit_count,
        hit_rate: hit_rate,
        mean_reciprocal_rank: mean_reciprocal_rank(answerable_results),
        no_answer_correct_count: no_answer_correct_count,
        no_answer_accuracy: no_answer_accuracy,
        correct_count: correct_count,
        overall_accuracy: ratio(correct_count, results.size),
        error_count: error_count,
        error_rate: ratio(error_count, results.size),
        average_milliseconds: durations.sum.fdiv(durations.size),
        p95_milliseconds: p95,
        average_embedding_milliseconds: average(embedding_durations),
        p95_embedding_milliseconds: percentile_95(embedding_durations),
        average_vector_search_milliseconds: average(
          vector_search_durations
        ),
        p95_vector_search_milliseconds: vector_search_p95,
        recommended_case_count_met:
          results.size >= Rag::EvaluationDataset::MIN_RECOMMENDED_CASES,
        target_hit_rate_met:
          hit_rate.present? && hit_rate >= TARGET_HIT_RATE,
        target_p95_met:
          vector_search_p95.present? &&
            vector_search_p95 < TARGET_P95_MILLISECONDS,
        results: results
      )
    end

    private

    attr_reader :workspace,
      :cases,
      :limit,
      :max_cosine_distance,
      :searcher_factory,
      :clock

    def validate_options!
      if cases.empty?
        raise ArgumentError, "cases must not be empty"
      end

      validate_max_cosine_distance!

      return if limit.between?(1, SemanticSearch::Search::MAX_LIMIT)

      raise ArgumentError,
        "limit must be between 1 and #{SemanticSearch::Search::MAX_LIMIT}"
    end

    def validate_max_cosine_distance!
      return if max_cosine_distance.between?(0.0, 2.0)

      raise ArgumentError,
        "max_cosine_distance must be between 0 and 2"
    end

    def evaluate(evaluation_case)
      started_at = clock.call
      search_result = searcher_factory.call(
        workspace: workspace,
        query: evaluation_case.question,
        limit: limit,
        max_cosine_distance: max_cosine_distance
      ).call
      retrieved_sources = build_retrieved_sources(search_result.chunks)
      hit_rank = if evaluation_case.answerable
        find_hit_rank(
          evaluation_case.expected_sources,
          retrieved_sources
        )
      end
      correct = if evaluation_case.answerable
        hit_rank.present?
      else
        retrieved_sources.empty?
      end

      build_case_result(
        evaluation_case,
        started_at,
        retrieved_sources,
        hit_rank: hit_rank,
        correct: correct,
        embedding_milliseconds: search_result.embedding_milliseconds,
        vector_search_milliseconds:
          search_result.vector_search_milliseconds
      )
    rescue StandardError => error
      build_case_result(
        evaluation_case,
        started_at,
        [],
        hit_rank: nil,
        correct: false,
        embedding_milliseconds: nil,
        vector_search_milliseconds: nil,
        error_class: error.class.name
      )
    end

    def build_retrieved_sources(chunks)
      chunks.map.with_index(1) do |chunk, rank|
        RetrievedSource.new(
          rank: rank,
          document_id: chunk.document_id,
          document_title: chunk.document.title,
          page_number: chunk.page_number,
          cosine_distance: chunk.neighbor_distance
        )
      end
    end

    def find_hit_rank(expected_sources, retrieved_sources)
      retrieved_sources.find do |retrieved|
        expected_sources.any? do |expected|
          source_matches?(expected, retrieved)
        end
      end&.rank
    end

    def source_matches?(expected, retrieved)
      title_matches = expected.document_title.casecmp?(
        retrieved.document_title
      )
      page_matches = expected.page_number.nil? ||
        expected.page_number == retrieved.page_number

      title_matches && page_matches
    end

    def build_case_result(
      evaluation_case,
      started_at,
      retrieved_sources,
      hit_rank:,
      correct:,
      embedding_milliseconds:,
      vector_search_milliseconds:,
      error_class: nil
    )
      CaseResult.new(
        id: evaluation_case.id,
        question: evaluation_case.question,
        answerable: evaluation_case.answerable,
        correct: correct,
        hit: hit_rank.present?,
        hit_rank: hit_rank,
        duration_milliseconds: elapsed_milliseconds(started_at),
        embedding_milliseconds: embedding_milliseconds,
        vector_search_milliseconds: vector_search_milliseconds,
        expected_sources: evaluation_case.expected_sources,
        retrieved_sources: retrieved_sources,
        error_class: error_class
      )
    end

    def elapsed_milliseconds(started_at)
      ((clock.call - started_at) * 1_000).round(3)
    end

    def percentile_95(values)
      return nil if values.empty?

      sorted = values.sort
      index = (0.95 * sorted.size).ceil - 1

      sorted.fetch(index)
    end

    def average(values)
      return nil if values.empty?

      values.sum.fdiv(values.size)
    end

    def mean_reciprocal_rank(answerable_results)
      reciprocal_rank_sum = answerable_results.sum do |result|
        result.hit_rank ? 1.0 / result.hit_rank : 0.0
      end

      ratio(reciprocal_rank_sum, answerable_results.size)
    end

    def ratio(numerator, denominator)
      return nil if denominator.zero?

      numerator.fdiv(denominator)
    end
  end
end
