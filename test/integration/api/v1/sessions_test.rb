require "test_helper"

class Api::V1::SessionsTest < ActionDispatch::IntegrationTest
  test "show reports a signed-out visitor without an error status" do
    get api_v1_session_path, as: :json
    assert_response :success
    assert_nil json["user"]
    assert_equal false, json["needs_setup"]
  end

  test "show reports when first-run setup is needed" do
    User.delete_all
    get api_v1_session_path, as: :json
    assert_equal true, json["needs_setup"]
  end

  test "signs in with valid credentials, case-insensitive email" do
    post api_v1_session_path, as: :json, params: { email_address: "OWNER@example.com", password: ApiTestHelper::PASSWORD }
    assert_response :created
    assert_equal users(:owner).id, json.dig("user", "id")

    get api_v1_session_path, as: :json
    assert_equal users(:owner).id, json.dig("user", "id")
  end

  test "rejects a wrong password" do
    post api_v1_session_path, as: :json, params: { email_address: "owner@example.com", password: "wrong-password" }
    assert_response :unauthorized
    assert_equal "invalid_credentials", json.dig("error", "code")
  end

  test "sign out ends the session" do
    sign_in
    assert_difference -> { Session.count }, -1 do
      delete api_v1_session_path, as: :json
    end
    assert_response :no_content

    get api_v1_session_path, as: :json
    assert_nil json["user"]
  end

  test "protected endpoints return 401 when signed out" do
    delete api_v1_session_path, as: :json
    assert_response :unauthorized
    assert_equal "unauthenticated", json.dig("error", "code")
  end

  test "sessions expire after being idle" do
    sign_in
    Session.last.update_column(:updated_at, (Authentication::IDLE_TIMEOUT + 1.minute).ago)

    get api_v1_session_path, as: :json
    assert_nil json["user"]
    assert_equal 0, Session.count
  end

  test "rejects requests without a CSRF token" do
    ActionController::Base.allow_forgery_protection = true
    post api_v1_session_path, as: :json, params: { email_address: "owner@example.com", password: ApiTestHelper::PASSWORD }

    assert_response :unprocessable_entity
    assert_equal "invalid_csrf_token", json.dig("error", "code")
  ensure
    ActionController::Base.allow_forgery_protection = false
  end
end
