require "test_helper"

class SpaTest < ActionDispatch::IntegrationTest
  test "serves the app shell for client-side routes" do
    get "/tasks/some/deep/link"
    assert_response :success
    assert_select "div#app"
  end

  test "sends a strict content security policy" do
    get "/"
    csp = response.headers["Content-Security-Policy"]
    assert_match "script-src 'self'", csp
    assert_match "object-src 'none'", csp
    assert_match "frame-ancestors 'none'", csp
  end

  test "unknown API paths are not swallowed by the SPA" do
    get "/api/v1/nope", as: :json
    assert_response :not_found
  end
end
