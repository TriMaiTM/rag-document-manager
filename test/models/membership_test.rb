require "test_helper"

class MembershipTest < ActiveSupport::TestCase
  test "accepts owner admin and member roles" do
    assert memberships(:one_owner).owner?
    assert memberships(:one_admin).admin?
    assert memberships(:one_member).member?
  end

  test "rejects an unknown role" do
    membership = Membership.new(
      user: users(:one),
      workspace: workspaces(:two),
      role: "viewer"
    )

    assert_not membership.valid?
    assert_includes membership.errors[:role], "is not included in the list"
  end

  test "a user can only join a workspace once" do
    duplicate = Membership.new(
      user: users(:one),
      workspace: workspaces(:one),
      role: :member
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already been taken"
  end

  test "a workspace cannot have a second owner" do
    second_owner = Membership.new(
      user: users(:three),
      workspace: workspaces(:one),
      role: :owner
    )

    assert_not second_owner.valid?
    assert_includes second_owner.errors[:role], "has already been taken"
  end
end
