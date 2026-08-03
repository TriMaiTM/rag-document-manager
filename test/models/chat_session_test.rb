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

  private

  def create_chat_session
    ChatSession.create!(
      workspace: workspaces(:one),
      user: users(:one),
      title: "Rails security"
    )
  end
end
