require "test_helper"

class Api::V1::StudyTest < ActionDispatch::IntegrationTest
  setup { sign_in }

  test "topics, resources with progress, and study time per resource" do
    post api_v1_topics_path, as: :json, params: { topic: { name: "Postgres", color: "blue" } }
    topic_id = json["id"]
    post api_v1_resources_path, as: :json, params: { resource: { title: "The Art of PostgreSQL", kind: "book", topic_id:, url: "https://theartofpostgresql.com" } }
    assert_response :created
    resource_id = json["id"]

    patch api_v1_resource_path(resource_id), as: :json, params: { resource: { progress: 40 } }
    assert_equal [ "in_progress", 40 ], json.values_at("status", "progress")
    patch api_v1_resource_path(resource_id), as: :json, params: { resource: { status: "done", rating: 5 } }
    assert_equal [ 100, Time.find_zone("Asia/Kolkata").today.iso8601 ], json.values_at("progress", "finished_on")

    post api_v1_study_sessions_path, as: :json, params: { study_session: { resource_id:, duration_minutes: 45 } }
    assert_equal topic_id, json["topic_id"]
    get api_v1_study_sessions_path, as: :json
    assert_equal [ { "topic_id" => topic_id, "minutes" => 45 } ], json["by_topic"]

    get api_v1_resources_path, as: :json
    assert_equal 45, json["resources"].first["minutes_studied"]
  end

  test "resource URLs must be http(s)" do
    post api_v1_resources_path, as: :json, params: { resource: { title: "x", url: "javascript:alert(1)" } }
    assert_response :unprocessable_entity
  end

  test "review queue and grading" do
    card = Flashcard.create!(front: "Q", back: "A")
    get due_api_v1_flashcards_path, as: :json
    assert_equal 1, json["due_count"]
    assert_equal({ "1" => 1, "3" => 1, "4" => 1, "5" => 1 }, json["flashcards"].first["preview"])

    post review_api_v1_flashcard_path(card), as: :json, params: { grade: 4 }
    assert_response :success
    get due_api_v1_flashcards_path, as: :json
    assert_equal 0, json["due_count"]

    post review_api_v1_flashcard_path(card), as: :json, params: { grade: 9 }
    assert_response :unprocessable_entity
  end

  test "cards from note syntax can't be edited directly" do
    card = Flashcard.create!(note: notes(:planner), front: "Q", back: "A", from_note_syntax: true)
    patch api_v1_flashcard_path(card), as: :json, params: { flashcard: { back: "B" } }
    assert_response :conflict
  end
end
