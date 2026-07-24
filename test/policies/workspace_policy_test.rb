require "test_helper"

class WorkspacePolicyTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:one)
  end

  test "owner can show update and destroy workspace" do
    policy = WorkspacePolicy.new(users(:one), @workspace)

    assert policy.show?
    assert policy.update?
    assert policy.destroy?
  end

  test "admin can show and update but cannot destroy workspace" do
    policy = WorkspacePolicy.new(users(:three), @workspace)

    assert policy.show?
    assert policy.update?
    assert_not policy.destroy?
  end

  test "member can only show workspace" do
    policy = WorkspacePolicy.new(users(:two), @workspace)

    assert policy.show?
    assert_not policy.update?
    assert_not policy.destroy?
  end

  test "outsider cannot access workspace" do
    policy = WorkspacePolicy.new(users(:one), workspaces(:two))

    assert_not policy.show?
    assert_not policy.update?
    assert_not policy.destroy?
  end

  test "scope only returns workspaces joined by user" do
    scope = WorkspacePolicy::Scope.new(users(:one), Workspace.all).resolve

    assert_includes scope, workspaces(:one)
    assert_not_includes scope, workspaces(:two)
  end
end
