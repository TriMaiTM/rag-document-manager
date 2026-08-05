require "test_helper"

class ChatMessagePolicyTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:one)
    @owner = users(:one)

    @chat_session = ChatSession.create!(
      workspace: @workspace,
      user: @owner,
      title: "Private chat"
    )

    @failed_message = @chat_session.chat_messages.create!(
      role: :assistant,
      status: :failed,
      content: Chat::Ask::FAILURE_ANSWER,
      error_code: "network_error"
    )
  end

  test "session owner can access and retry a failed message" do
    policy = ChatMessagePolicy.new(@owner, @failed_message)

    assert policy.show?
    assert policy.retry?
  end

  test "session owner can create a message" do
    message = @chat_session.chat_messages.new(
      role: :user,
      content: "What is semantic search?"
    )

    assert ChatMessagePolicy.new(@owner, message).create?
  end

  test "another workspace member cannot access the message" do
    policy = ChatMessagePolicy.new(users(:two), @failed_message)

    assert_not policy.show?
    assert_not policy.retry?
  end

  test "an outsider cannot access the message" do
    policy = ChatMessagePolicy.new(users(:four), @failed_message)

    assert_not policy.show?
    assert_not policy.create?
    assert_not policy.retry?
  end

  test "a completed assistant message cannot be retried" do
    message = @chat_session.chat_messages.create!(
      role: :assistant,
      content: "Grounded answer"
    )

    policy = ChatMessagePolicy.new(@owner, message)

    assert policy.show?
    assert_not policy.retry?
  end

  test "scope only returns messages from owned sessions" do
    other_session = ChatSession.create!(
      workspace: @workspace,
      user: users(:two),
      title: "Other member chat"
    )
    other_message = other_session.chat_messages.create!(
      role: :user,
      content: "Private question"
    )

    scope = ChatMessagePolicy::Scope.new(
      @owner,
      ChatMessage.all
    ).resolve

    assert_includes scope, @failed_message
    assert_not_includes scope, other_message
  end
end