module Rag
  class AnswerQuestion
    class GenerationError < StandardError
      attr_reader :query, :chunks, :original_error

      def initialize(query:, chunks:, original_error:)
        @query = query
        @chunks = chunks
        @original_error = original_error

        super("Answer generation failed: #{original_error.message}")
      end
    end

    Result = Data.define(
      :query,
      :answer,
      :chunks,
      :model,
      :prompt_tokens,
      :candidate_tokens,
      :total_tokens
    )

    NO_CONTEXT_ANSWER =
      "Không tìm thấy nội dung phù hợp trong các tài liệu của Workspace."

    def initialize(
      workspace:,
      question:,
      searcher: nil,
      answer_generator: Ai::GenerateGroundedAnswer.new
    )
      @question = question
      @searcher = searcher || SemanticSearch::Search.new(
        workspace: workspace,
        query: question,
        limit: Ai::GenerateGroundedAnswer::MAX_CONTEXTS
      )
      @answer_generator = answer_generator
    end

    def call
      search_result = searcher.call

      if search_result.chunks.empty?
        return empty_result(search_result.query)
      end

      generation = generate_answer(search_result)

      Result.new(
        query: search_result.query,
        answer: generation.answer,
        chunks: search_result.chunks,
        model: generation.model,
        prompt_tokens: generation.prompt_tokens,
        candidate_tokens: generation.candidate_tokens,
        total_tokens: generation.total_tokens
      )
    end

    private

    attr_reader :question, :searcher, :answer_generator

    def generate_answer(search_result)
      answer_generator.call(
        question: search_result.query,
        chunks: search_result.chunks
      )
    rescue Ai::GeminiClient::Error,
      Ai::GenerateGroundedAnswer::Error,
      Codexys::GeminiConfiguration::MissingApiKeyError => error
      raise GenerationError.new(
        query: search_result.query,
        chunks: search_result.chunks,
        original_error: error
      )
    end

    def empty_result(query)
      Result.new(
        query: query,
        answer: NO_CONTEXT_ANSWER,
        chunks: [],
        model: nil,
        prompt_tokens: 0,
        candidate_tokens: 0,
        total_tokens: 0
      )
    end
  end
end
