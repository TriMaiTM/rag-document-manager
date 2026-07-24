require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "is valid with an email and password" do
    user = User.new(
      email_address: "new-user@example.com",
      password: "password",
      password_confirmation: "password"
    )

    assert user.valid?
  end

  test "requires a valid email" do
    user = User.new(
      email_address: "invalid-email",
      password: "password",
      password_confirmation: "password"
    )

    assert_not user.valid?
    assert_includes user.errors[:email_address], "is invalid"
  end

  test "requires a unique email regardless of case" do
    user = User.new(
      email_address: " ONE@EXAMPLE.COM ",
      password: "password",
      password_confirmation: "password"
    )

    assert_not user.valid?
    assert_includes user.errors[:email_address], "has already been taken"
  end

  test "requires a password with at least eight characters" do
    user = User.new(
      email_address: "short-password@example.com",
      password: "short",
      password_confirmation: "short"
    )

    assert_not user.valid?
    assert_includes user.errors[:password],
      "is too short (minimum is 8 characters)"
  end

  test "requires password confirmation when setting a password" do
    user = User.new(
      email_address: "missing-confirmation@example.com",
      password: "password"
    )

    assert_not user.valid?
    assert_includes user.errors[:password_confirmation], "can't be blank"
  end
end
