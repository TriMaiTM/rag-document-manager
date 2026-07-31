require "test_helper"

class MembershipPolicyTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:one)
    @member = memberships(:one_member)
    @owner = memberships(:one_owner)
  end

  test "owner and admin can manage non owner memberships" do
    owner_policy = MembershipPolicy.new(users(:one), @member)
    admin_policy = MembershipPolicy.new(users(:three), @member)

    assert owner_policy.index?
    assert owner_policy.update?
    assert owner_policy.destroy?
    assert admin_policy.index?
    assert admin_policy.update?
    assert admin_policy.destroy?
  end

  test "member cannot manage memberships" do
    policy = MembershipPolicy.new(users(:two), memberships(:one_admin))

    assert_not policy.index?
    assert_not policy.update?
    assert_not policy.destroy?
  end

  test "owner membership cannot be updated or destroyed" do
    owner_policy = MembershipPolicy.new(users(:one), @owner)
    admin_policy = MembershipPolicy.new(users(:three), @owner)

    assert_not owner_policy.update?
    assert_not owner_policy.destroy?
    assert_not admin_policy.update?
    assert_not admin_policy.destroy?
  end

  test "only admin and member roles can be assigned" do
    admin_candidate = @workspace.memberships.new(role: :admin)
    member_candidate = @workspace.memberships.new(role: :member)
    owner_candidate = @workspace.memberships.new(role: :owner)

    assert MembershipPolicy.new(users(:one), admin_candidate).create?
    assert MembershipPolicy.new(users(:one), member_candidate).create?
    assert_not MembershipPolicy.new(users(:one), owner_candidate).create?
  end
end
