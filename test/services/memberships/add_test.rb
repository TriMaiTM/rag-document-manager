require "test_helper"

class Memberships::AddTest < ActiveSupport::TestCase
  test "adds an existing user using normalized email" do
    assert_difference("Membership.count", 1) do
      membership = Memberships::Add.new(
        workspace: workspaces(:one),
        email_address: " FOUR@EXAMPLE.COM ",
        role: "member"
      ).call

      assert membership.persisted?
      assert_equal users(:four), membership.user
      assert membership.member?
    end
  end

  test "returns an error when email does not belong to a user" do
    assert_no_difference("Membership.count") do
      membership = Memberships::Add.new(
        workspace: workspaces(:one),
        email_address: "missing@example.com",
        role: "member"
      ).call

      assert_not membership.persisted?
      assert_includes membership.errors[:user],
        "was not found for that email address"
    end
  end

  test "does not add the same user twice" do
    assert_no_difference("Membership.count") do
      membership = Memberships::Add.new(
        workspace: workspaces(:one),
        email_address: users(:two).email_address,
        role: "admin"
      ).call

      assert_not membership.persisted?
      assert_includes membership.errors[:user_id],
        "has already been taken"
    end
  end
end
