require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email" do
    user = User.new(email: " DOWNCASED@EXAMPLE.COM ")
    user.valid?

    assert_equal("downcased@example.com", user.email)
  end

  test "is valid with an email and password" do
    user = User.new(
      email: "new-user@example.com",
      password: "password",
      password_confirmation: "password"
    )

    assert user.valid?
  end

  test "requires a valid email" do
    user = User.new(
      email: "invalid-email",
      password: "password",
      password_confirmation: "password"
    )

    assert_not user.valid?
    assert_includes user.errors[:email], "is invalid"
  end

  test "requires a unique email regardless of case" do
    user = User.new(
      email: " ONE@EXAMPLE.COM ",
      password: "password",
      password_confirmation: "password"
    )

    assert_not user.valid?
    assert_includes user.errors[:email], "has already been taken"
  end

  test "requires a password with at least eight characters" do
    user = User.new(
      email: "short-password@example.com",
      password: "short",
      password_confirmation: "short"
    )

    assert_not user.valid?
    assert_includes user.errors[:password],
      "is too short (minimum is 8 characters)"
  end

  test "requires matching password confirmation" do
    user = User.new(
      email: "mismatched-confirmation@example.com",
      password: "password",
      password_confirmation: "different-password"
    )

    assert_not user.valid?
    assert_includes user.errors[:password_confirmation], "doesn't match Password"
  end

  test "defaults to regular user system role" do
    user = User.new

    assert_predicate user, :user?
  end

  test "accepts system admin role" do
    user = users(:one)
    user.system_role = :system_admin

    assert user.valid?
    assert_predicate user, :system_admin?
  end

  test "rejects an invalid system role" do
    user = users(:one)
    user.system_role = "invalid_role"

    assert_not user.valid?
    assert_includes user.errors[:system_role], "is not included in the list"
  end
end
