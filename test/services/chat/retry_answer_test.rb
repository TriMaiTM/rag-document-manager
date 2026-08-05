require "test_helper"

class Chat::RetryAnswerTest < ActiveSupport::TestCase
  class FakeAnswerer
    attr_reader :called

    def initialize(result: nil, error: nil)
      @result = result
      @error = error
      @called = false
    end

    def call
      @called = true
      raise error if error

      result
    end

    private

    attr_reader :result, :error
  end

  setup do
    @workspace = workspaces(:one)
    @user = users(:one)

    @chat_session = ChatSession.create!(
      workspace: @workspace,
      user: @user,
      title: "Retry test"
    )

    @question_message = @chat_session.chat_messages.create!(
      role: :user,
      content: "What is semantic search?"
    )

    @assistant_message = @chat_session.chat_messages.create!(
      role: :assistant,
      status: :failed,
      question_message: @question_message,
      content: Chat::Ask::FAILURE_ANSWER,
      error_code: "network_error"
    )
  end

  test "retries by updating the existing assistant message" do
    answerer = FakeAnswerer.new(result: rag_result)

    assert_no_difference("ChatMessage.count") do
      @result = Chat::RetryAnswer.new(
        workspace: @workspace,
        user: @user,
        assistant_message: @assistant_message,
        answerer: answerer
      ).call
    end

    assert answerer.called
    assert_not @result.failed?
    assert_equal @assistant_message, @result.assistant_message

    @assistant_message.reload

    assert_predicate @assistant_message, :completed?
    assert_equal "Retried grounded answer",
      @assistant_message.content
    assert_equal "gemini-test", @assistant_message.model
    assert_equal 120, @assistant_message.total_tokens
    assert_nil @assistant_message.error_code
  end

  test "returns the message to failed when retry generation fails" do
    network_error = Ai::GeminiClient::NetworkError.new(
      Net::ReadTimeout.new("secret provider details")
    )
    generation_error = Rag::AnswerQuestion::GenerationError.new(
      query: @question_message.content,
      chunks: [],
      original_error: network_error
    )
    answerer = FakeAnswerer.new(error: generation_error)

    result = Chat::RetryAnswer.new(
      workspace: @workspace,
      user: @user,
      assistant_message: @assistant_message,
      answerer: answerer
    ).call

    assert result.failed?

    @assistant_message.reload

    assert_predicate @assistant_message, :failed?
    assert_predicate @assistant_message, :retryable?
    assert_equal "network_error",
      @assistant_message.error_code
    assert_equal Chat::Ask::FAILURE_ANSWER,
      @assistant_message.content
    assert_not_includes @assistant_message.content,
      "secret provider details"
  end

  test "does not retry a completed message" do
    @assistant_message.claim_retry!
    @assistant_message.update!(
      status: :completed,
      content: "Completed answer"
    )

    answerer = FakeAnswerer.new(result: rag_result)

    assert_raises(Chat::RetryAnswer::InvalidMessageError) do
      Chat::RetryAnswer.new(
        workspace: @workspace,
        user: @user,
        assistant_message: @assistant_message,
        answerer: answerer
      ).call
    end

    assert_not answerer.called
  end

  test "does not retry another user's message" do
    answerer = FakeAnswerer.new(result: rag_result)

    assert_raises(Chat::RetryAnswer::InvalidMessageError) do
      Chat::RetryAnswer.new(
        workspace: @workspace,
        user: users(:two),
        assistant_message: @assistant_message,
        answerer: answerer
      ).call
    end

    assert_not answerer.called
  end

  private

  def rag_result
    Rag::AnswerQuestion::Result.new(
      query: @question_message.content,
      answer: "Retried grounded answer",
      chunks: [],
      model: "gemini-test",
      prompt_tokens: 100,
      candidate_tokens: 20,
      total_tokens: 120
    )
  end
end
