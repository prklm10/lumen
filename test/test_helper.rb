ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all
  end
end

module ApiTestHelper
  PASSWORD = "correct-horse-battery".freeze

  def sign_in(user = users(:owner), password: PASSWORD)
    post api_v1_session_path, params: { email_address: user.email_address, password: }, as: :json
    assert_response :created
  end

  def json
    response.parsed_body
  end
end

class ActionDispatch::IntegrationTest
  include ApiTestHelper
end
