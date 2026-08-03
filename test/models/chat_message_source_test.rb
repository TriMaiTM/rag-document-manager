require "test_helper"

class ChatMessageSourceTest < ActiveSupport::TestCase
  setup do
    chat_session = ChatSession.create!(
      workspace: workspaces(:one),
      user: users(:one),
      title: "Rails security"
    )

    @message = chat_session.chat_messages.create!(
      role: :assistant,
      content: "Answer"
    )
  end

  test "requires a valid snapshot and distance" do
    source = @message.chat_message_sources.new(
      rank: 0,
      document_title: "",
      page_number: 0,
      content: "",
      cosine_distance: 3
    )

    assert_not source.valid?
    assert source.errors.added?(:document_title, :blank)
    assert source.errors.added?(:content, :blank)
    assert source.errors.added?(:rank, :greater_than, value: 0, count: 0)
    assert source.errors.added?(
      :page_number,
      :greater_than,
      value: 0,
      count: 0
    )
    assert source.errors.added?(
      :cosine_distance,
      :less_than_or_equal_to,
      value: 3,
      count: 2
    )
  end
end
