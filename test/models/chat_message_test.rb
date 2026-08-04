require "test_helper"

class ChatMessageTest < ActiveSupport::TestCase
  setup do
    @chat_session = ChatSession.create!(
      workspace: workspaces(:one),
      user: users(:one),
      title: "Rails security"
    )
  end

  test "supports user and assistant roles" do
    user_message = @chat_session.chat_messages.create!(
      role: :user,
      content: "What is CSRF?"
    )
    assistant_message = @chat_session.chat_messages.create!(
      role: :assistant,
      content: "CSRF is a request forgery attack.",
      model: "gemini-test",
      prompt_tokens: 10,
      candidate_tokens: 5,
      total_tokens: 15
    )

    assert user_message.user?
    assert assistant_message.assistant?
    assert user_message.completed?
    assert assistant_message.completed?
  end

  test "rejects generation metadata on a user message" do
    message = @chat_session.chat_messages.new(
      role: :user,
      content: "Question",
      model: "gemini-test",
      total_tokens: 10
    )

    assert_not message.valid?
    assert_includes message.errors[:base],
      "Tin nhắn người dùng không được có metadata sinh nội dung"
  end

  test "requires non-negative token counts" do
    message = @chat_session.chat_messages.new(
      role: :assistant,
      content: "Answer",
      total_tokens: -1
    )

    assert_not message.valid?
    assert message.errors.added?(
      :total_tokens,
      :greater_than_or_equal_to,
      value: -1,
      count: 0
    )
  end

  test "allows a failed assistant message with a safe error code" do
    message = @chat_session.chat_messages.new(
      role: :assistant,
      status: :failed,
      content: Chat::Ask::FAILURE_ANSWER,
      error_code: "network_error"
    )

    assert_predicate message, :valid?
  end

  test "requires failure metadata to match the status" do
    failed_message = @chat_session.chat_messages.new(
      role: :assistant,
      status: :failed,
      content: Chat::Ask::FAILURE_ANSWER
    )
    completed_message = @chat_session.chat_messages.new(
      role: :assistant,
      content: "Completed answer",
      error_code: "network_error"
    )

    assert_not failed_message.valid?
    assert_includes failed_message.errors[:error_code],
      "phải có khi tin nhắn thất bại"
    assert_not completed_message.valid?
    assert_includes completed_message.errors[:error_code],
      "phải để trống khi tin nhắn hoàn thành"
  end

  test "does not allow a failed user message" do
    message = @chat_session.chat_messages.new(
      role: :user,
      status: :failed,
      content: "Question",
      error_code: "network_error"
    )

    assert_not message.valid?
    assert_includes message.errors[:status],
      "của câu hỏi người dùng phải là completed"
  end
end
