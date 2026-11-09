require "test_helper"

class Api::V1::TrackersTest < ActionDispatch::IntegrationTest
  setup { sign_in }

  test "lists active trackers with stats and recent entries" do
    get api_v1_trackers_path, as: :json
    assert_response :success
    assert_equal %w[Meditate Water], json["trackers"].map { |t| t["name"] }

    water = json["trackers"].last
    assert_equal 8.0, water["target"]
    assert_equal 1, water.dig("stats", "current_streak")
    assert_includes water["recent_entries"], { "logged_on" => (Time.find_zone("Asia/Kolkata").today - 1).iso8601, "note" => "Hot day", "value" => 9.0 }

    get api_v1_trackers_path(include_archived: true), as: :json
    assert_equal 3, json["trackers"].size
  end

  test "create, archive, delete" do
    post api_v1_trackers_path, as: :json, params: { tracker: { name: "Sleep", kind: "numeric", unit: "hours", target: 7.5, frequency: { type: "weekdays", days: [ 1, 2, 3, 4, 5 ] } } }
    assert_response :created
    assert_equal({ "type" => "weekdays", "days" => [ 1, 2, 3, 4, 5 ] }, json["frequency"])
    id = json["id"]

    patch api_v1_tracker_path(id), as: :json, params: { tracker: { archived: true } }
    assert json["archived"]

    delete api_v1_tracker_path(id), as: :json
    assert_response :no_content
  end

  test "check-ins are idempotent upserts by date" do
    today = Time.find_zone("Asia/Kolkata").today.iso8601
    path = api_v1_tracker_entry_path(trackers(:water), today)

    put path, as: :json, params: { entry: { value: 3 } }
    assert_response :success
    put path, as: :json, params: { entry: { value: 8, note: "Done!" } }
    assert_equal({ "logged_on" => today, "note" => "Done!", "value" => 8.0 }, json)
    assert_equal 1, trackers(:water).entries.where(logged_on: today).count

    delete path, as: :json
    assert_response :no_content
    assert_not trackers(:water).entries.exists?(logged_on: today)
  end

  test "rejects bad check-ins" do
    put api_v1_tracker_entry_path(trackers(:meditate), Time.find_zone("Asia/Kolkata").today.iso8601), as: :json, params: { entry: { value: 5 } }
    assert_response :unprocessable_entity

    put api_v1_tracker_entry_path(trackers(:meditate), "2026-02-30"), as: :json, params: { entry: { value: 1 } }
    assert_response :unprocessable_entity
    assert_equal "invalid_parameter", json.dig("error", "code")
  end

  test "entries for a date range (heatmap)" do
    get api_v1_tracker_entries_path(trackers(:meditate)), as: :json
    assert_equal 4, json["entries"].size

    get api_v1_tracker_entries_path(trackers(:meditate), from: "2020-01-01", to: "2026-01-01"), as: :json
    assert_response :unprocessable_entity
  end
end
