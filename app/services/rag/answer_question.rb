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
      history: [],
      searcher: nil,
      answer_generator: Ai::GenerateGroundedAnswer.new
    )
      @workspace = workspace
      @question = question
      @history = history
      @searcher = searcher
      @answer_generator = answer_generator
    end

    def call
      normalized_question =
        SemanticSearch::Search.normalize_query!(question)
      context = Rag::ConversationContext.new(messages: history)
      search_result = search(
        context.retrieval_query(normalized_question)
      )

      if search_result.chunks.empty?
        return empty_result(normalized_question)
      end

      generation = generate_answer(
        search_result,
        normalized_question,
        context.transcript
      )
      citations = Rag::SelectCitations.new(
        answer: generation.answer,
        chunks: search_result.chunks
      ).call

      Result.new(
        query: normalized_question,
        answer: citations.answer,
        chunks: citations.chunks,
        model: generation.model,
        prompt_tokens: generation.prompt_tokens,
        candidate_tokens: generation.candidate_tokens,
        total_tokens: generation.total_tokens
      )
    end

    private

    attr_reader :workspace,
      :question,
      :history,
      :searcher,
      :answer_generator

    def search(retrieval_query)
      service = searcher || SemanticSearch::HybridSearch.new(
        workspace: workspace,
        query: retrieval_query,
        limit: Ai::GenerateGroundedAnswer::MAX_CONTEXTS
      )

      service.call
    end

    def generate_answer(
      search_result,
      normalized_question,
      conversation_history
    )
      answer_generator.call(
        question: normalized_question,
        chunks: search_result.chunks,
        conversation_history: conversation_history
      )
    rescue Ai::GeminiClient::Error,
      Ai::GenerateGroundedAnswer::Error,
      Codexys::GeminiConfiguration::MissingApiKeyError => error
      raise GenerationError.new(
        query: normalized_question,
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
