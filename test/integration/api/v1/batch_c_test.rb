require "test_helper"
require "rubygems/package"

class Api::V1::BatchCTest < ActionDispatch::IntegrationTest
  setup { sign_in }

  test "settings: only known keys, typed" do
    patch api_v1_me_path, as: :json, params: { user: { time_zone: "Europe/Berlin", settings: { journal_mood_mirror: "1", sneaky: "x" } } }
    assert_response :success
    assert_equal "Europe/Berlin", json.dig("user", "time_zone")
    assert_equal({ "journal_mood_mirror" => true }, json.dig("user", "settings"))
  end

  test "the mood tracker is created once" do
    post mood_api_v1_trackers_path, as: :json
    first = json["id"]
    post mood_api_v1_trackers_path, as: :json
    assert_equal first, json["id"]
    assert_equal [ "scale", "mood" ], json.values_at("kind", "system_key")
  end

  test "weekly review summarises the week across modules" do
    get api_v1_weekly_review_path, as: :json
    assert_response :success
    titles = json.dig("tasks", "completed").map { |t| t["title"] }
    assert_includes titles, "Set up Docker"
    assert(json["habits"].any? { |h| h["name"] == "Meditate" })
    assert_kind_of Array, json["journal_days"]
  end

  test "JSON export has every module; the journal stays ciphertext" do
    JournalEntry.create!(id: SecureRandom.uuid, entry_date: Date.current, iv: SecureRandom.random_bytes(12), ciphertext: SecureRandom.random_bytes(64))
    get api_v1_export_path
    assert_response :success
    assert_match "attachment", response.headers["Content-Disposition"]
    data = JSON.parse(response.body)
    assert_equal 2, data["notes"].size
    assert_includes data["notes"].first["markdown"] + data["notes"].last["markdown"], "[[Query planner]]"
    assert data["journal"]["entries"].first.key?("ciphertext")
    assert_not data["tasks"].first.key?("search_vector")
  end

  test "notes export is a tar.gz of Markdown files in their folders" do
    get notes_api_v1_export_path
    assert_equal "application/gzip", response.media_type
    files = {}
    Gem::Package::TarReader.new(Zlib::GzipReader.new(StringIO.new(response.body))) { |tar| tar.each { |e| files[e.full_name] = e.read } }
    assert_equal [ "lumen-notes/Tech/Databases/Postgres indexes.md", "lumen-notes/Tech/Databases/Query planner.md" ], files.keys.sort
    assert_match(/\A---\ntitle: "Postgres indexes"/, files["lumen-notes/Tech/Databases/Postgres indexes.md"])
  end
end
