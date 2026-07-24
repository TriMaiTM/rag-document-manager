require "test_helper"

class Workspaces::CreateTest < ActiveSupport::TestCase
  test "creates a workspace and its owner together" do
    workspace = Workspace.new(
      name: "Owned Workspace",
      description: "Created through the workspace service."
    )

    assert_difference("Workspace.count", 1) do
      assert_difference("Membership.count", 1) do
        Workspaces::Create.new(
          user: users(:one),
          workspace: workspace
        ).call
      end
    end

    assert workspace.persisted?
    assert workspace.membership_for(users(:one)).owner?
  end

  test "does not create membership when workspace is invalid" do
    workspace = Workspace.new(name: "")

    assert_no_difference([ "Workspace.count", "Membership.count" ]) do
      Workspaces::Create.new(
        user: users(:one),
        workspace: workspace
      ).call
    end

    assert_not workspace.persisted?
    assert workspace.errors[:name].present?
  end
end
