require "test_helper"

class ChatSessionTest < ActiveSupport::TestCase
  test "requires a title, workspace, and user" do
    chat_session = ChatSession.new

    assert_not chat_session.valid?
    assert chat_session.errors.added?(:title, :blank)
    assert chat_session.errors.added?(:workspace, :blank)
    assert chat_session.errors.added?(:user, :blank)
  end

  test "orders messages chronologically" do
    chat_session = create_chat_session
    later = chat_session.chat_messages.create!(
      role: :assistant,
      content: "Later",
      created_at: 2.minutes.from_now
    )
    earlier = chat_session.chat_messages.create!(
      role: :user,
      content: "Earlier",
      created_at: 1.minute.from_now
    )

    assert_equal [ earlier, later ], chat_session.chat_messages.to_a
  end

  test "orders sessions by most recently updated first" do
    older = create_chat_session
    newer = create_chat_session

    older.touch(time: 2.days.ago)
    newer.touch(time: 1.day.ago)

    sessions = ChatSession
      .where(id: [ older.id, newer.id ])
      .recent_first

    assert_equal [ newer, older ], sessions.to_a
  end

  test "deletes associated messages with the session" do
    chat_session = create_chat_session
    message = chat_session.chat_messages.create!(
      role: :user,
      content: "What is semantic search?"
    )

    assert_difference("ChatSession.count", -1) do
      assert_difference("ChatMessage.count", -1) do
        chat_session.destroy!
      end
    end

    assert_not ChatMessage.exists?(message.id)
  end

  private

  def create_chat_session
    ChatSession.create!(
      workspace: workspaces(:one),
      user: users(:one),
      title: "Rails security"
    )
  end
end
