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
end
