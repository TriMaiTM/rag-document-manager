require "test_helper"

class Rag::AnswerQuestionTest < ActiveSupport::TestCase
  Message = Data.define(:role, :content)

  class FakeService
    attr_reader :arguments, :called

    def initialize(result)
      @result = result
      @called = false
    end

    def call(**arguments)
      @called = true
      @arguments = arguments
      @result
    end
  end

  test "retrieves chunks and generates a grounded answer" do
    chunks = [ Object.new, Object.new ]
    searcher = FakeService.new(
      SemanticSearch::Search::Result.new(
        query: "Rails security",
        chunks: chunks
      )
    )
    generator = FakeService.new(generation_result)

    result = Rag::AnswerQuestion.new(
      workspace: workspaces(:one),
      question: " Rails security ",
      searcher: searcher,
      answer_generator: generator
    ).call

    assert searcher.called
    assert_equal "Rails security", generator.arguments[:question]
    assert_same chunks, generator.arguments[:chunks]
    assert_equal "Grounded answer [1]", result.answer
    assert_same chunks, result.chunks
    assert_equal 120, result.total_tokens
  end

  test "does not call the answer model without search results" do
    searcher = FakeService.new(
      SemanticSearch::Search::Result.new(
        query: "Unknown topic",
        chunks: []
      )
    )
    generator = FakeService.new(generation_result)

    result = Rag::AnswerQuestion.new(
      workspace: workspaces(:one),
      question: "Unknown topic",
      searcher: searcher,
      answer_generator: generator
    ).call

    assert_not generator.called
    assert_equal Rag::AnswerQuestion::NO_CONTEXT_ANSWER, result.answer
    assert_empty result.chunks
    assert_equal 0, result.total_tokens
  end

  test "preserves retrieved chunks when answer generation fails" do
    chunks = [ Object.new ]
    searcher = FakeService.new(
      SemanticSearch::Search::Result.new(
        query: "Rails security",
        chunks: chunks
      )
    )
    generator = Object.new
    generator.define_singleton_method(:call) do |**_arguments|
      raise Ai::GeminiClient::NetworkError.new(
        Net::ReadTimeout.new("execution expired")
      )
    end

    error = assert_raises(Rag::AnswerQuestion::GenerationError) do
      Rag::AnswerQuestion.new(
        workspace: workspaces(:one),
        question: "Rails security",
        searcher: searcher,
        answer_generator: generator
      ).call
    end

    assert_equal "Rails security", error.query
    assert_same chunks, error.chunks
    assert_instance_of Ai::GeminiClient::NetworkError,
      error.original_error
  end

  test "uses recent history for retrieval and answer generation" do
    history = [
      Message.new(
        role: "user",
        content: "Devise lưu mật khẩu thế nào?"
      ),
      Message.new(
        role: "assistant",
        content: "Devise hashes passwords [1]."
      )
    ]
    chunks = [ Object.new ]
    searcher = FakeService.new(
      SemanticSearch::Search::Result.new(
        query: "contextual retrieval query",
        chunks: chunks
      )
    )
    generator = FakeService.new(generation_result)
    search_arguments = nil
    search_factory = lambda do |**arguments|
      search_arguments = arguments
      searcher
    end

    result = SemanticSearch::Search.stub(:new, search_factory) do
      Rag::AnswerQuestion.new(
        workspace: workspaces(:one),
        question: "  Còn đăng nhập thì sao?  ",
        history: history,
        answer_generator: generator
      ).call
    end

    assert_equal "Còn đăng nhập thì sao?", result.query
    assert_includes search_arguments[:query],
      "Còn đăng nhập thì sao?"
    assert_includes search_arguments[:query],
      "Devise lưu mật khẩu thế nào?"
    assert_equal "Còn đăng nhập thì sao?",
      generator.arguments[:question]
    assert_includes generator.arguments[:conversation_history],
      "Người dùng: Devise lưu mật khẩu thế nào?"
    assert_includes generator.arguments[:conversation_history],
      "Trợ lý: Devise hashes passwords [1]."
  end

  private

  def generation_result
    Ai::GenerateGroundedAnswer::Result.new(
      answer: "Grounded answer [1]",
      model: "gemini-test-model",
      prompt_tokens: 100,
      candidate_tokens: 20,
      total_tokens: 120
    )
  end
end
