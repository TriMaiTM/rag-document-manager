require "test_helper"

class ChatSessionPolicyTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:one)
    @chat_session = ChatSession.create!(
      workspace: @workspace,
      user: users(:one),
      title: "Private chat"
    )
  end

  test "owner can manage their own chat session" do
    policy = ChatSessionPolicy.new(users(:one), @chat_session)

    assert policy.index?
    assert policy.show?
    assert policy.create?
    assert policy.ask?
    assert policy.destroy?
  end

  test "workspace member cannot access another user's chat" do
    policy = ChatSessionPolicy.new(users(:two), @chat_session)

    assert policy.index?
    assert_not policy.show?
    assert_not policy.create?
    assert_not policy.ask?
    assert_not policy.destroy?
  end

  test "outsider cannot access chat sessions" do
    policy = ChatSessionPolicy.new(users(:four), @chat_session)

    assert_not policy.index?
    assert_not policy.show?
    assert_not policy.create?
  end

  test "scope only returns the user's sessions in joined workspaces" do
    member_session = ChatSession.create!(
      workspace: @workspace,
      user: users(:two),
      title: "Member chat"
    )

    scope = ChatSessionPolicy::Scope.new(
      users(:one),
      ChatSession.all
    ).resolve

    assert_includes scope, @chat_session
    assert_not_includes scope, member_session
  end
end
