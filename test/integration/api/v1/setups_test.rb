require "test_helper"

class Api::V1::SetupsTest < ActionDispatch::IntegrationTest
  test "creates the first user and signs them in" do
    User.delete_all
    post api_v1_setup_path, as: :json,
      params: { email_address: "me@example.com", password: "correct-horse-battery", time_zone: "Asia/Kolkata" }

    assert_response :created
    assert_equal "me@example.com", json.dig("user", "email_address")
    assert_not json["user"].key?("password_digest")

    get api_v1_session_path, as: :json
    assert_equal "me@example.com", json.dig("user", "email_address")
  end

  test "returns validation errors" do
    User.delete_all
    post api_v1_setup_path, as: :json, params: { email_address: "nope", password: "short", time_zone: "UTC" }

    assert_response :unprocessable_entity
    assert_equal "validation_failed", json.dig("error", "code")
    assert json.dig("error", "details", "password").present?
  end

  test "refuses once a user exists" do
    post api_v1_setup_path, as: :json,
      params: { email_address: "intruder@example.com", password: "correct-horse-battery", time_zone: "UTC" }

    assert_response :forbidden
    assert_equal 1, User.count
  end
end
