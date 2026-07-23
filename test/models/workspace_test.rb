require "test_helper"

class WorkspaceTest < ActiveSupport::TestCase
  test "is valid with a name" do
    workspace = Workspace.new(
      name: "Software Engineering",
      description: "Không gian quản lý tài liệu kỹ thuật"
    )

    assert workspace.valid?
  end

  test "requires a name" do
    workspace = Workspace.new(name: nil)

    assert_not workspace.valid?
    assert_includes workspace.errors[:name], "can't be blank"
  end

  test "name cannot exceed 100 characters" do
    workspace = Workspace.new(name: "a" * 101)

    assert_not workspace.valid?
    assert_includes workspace.errors[:name],
      "is too long (maximum is 100 characters)"
  end

  test "description can be blank" do
    workspace = Workspace.new(
      name: "Personal Workspace",
      description: nil
    )

    assert workspace.valid?
  end
end