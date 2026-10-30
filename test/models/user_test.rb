require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup { User.delete_all }

  test "normalizes email address" do
    user = User.create!(email_address: "  Me@Example.COM ", password: "long-enough-pw")
    assert_equal "me@example.com", user.email_address
  end

  test "requires a password of at least 10 characters" do
    user = User.new(email_address: "me@example.com", password: "short")
    assert_not user.valid?
    assert_includes user.errors[:password], "is too short (minimum is 10 characters)"
  end

  test "stores the canonical name for time zone aliases" do
    user = User.create!(email_address: "me@example.com", password: "long-enough-pw", time_zone: "Asia/Calcutta")
    assert_equal "Asia/Kolkata", user.time_zone
  end

  test "rejects unknown time zones" do
    user = User.new(email_address: "me@example.com", password: "long-enough-pw", time_zone: "Mars/Base")
    assert_not user.valid?
    assert user.errors.added?(:time_zone, "is not a known time zone")
  end

  test "allows only one user" do
    User.create!(email_address: "me@example.com", password: "long-enough-pw")
    second = User.new(email_address: "other@example.com", password: "long-enough-pw")
    assert_not second.valid?
    assert_includes second.errors[:base], "An account already exists"
  end

  test "email is unique case-insensitively at the database level" do
    User.create!(email_address: "me@example.com", password: "long-enough-pw")
    assert_raises(ActiveRecord::RecordNotUnique) do
      User.insert!({ email_address: "ME@example.com", password_digest: "x" })
    end
  end
end
