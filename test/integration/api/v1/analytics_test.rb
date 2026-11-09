require "test_helper"

class Api::V1::AnalyticsTest < ActionDispatch::IntegrationTest
  setup do
    sign_in
    Rails.cache.clear
  end

  test "tasks: KPIs, a bucket per day, and where the work went" do
    get api_v1_analytics_tasks_path(range: "7d"), as: :json
    assert_response :success
    assert_equal 7, json["series"].size
    assert_equal "day", json.dig("range", "unit")

    # Fixtures: done today + subtask done 1h ago + done yesterday (just before today's midnight).
    assert_equal 3, json.dig("kpis", "completed")
    assert_equal 3, json["series"].sum { |d| d["completed"] }
    assert_includes json["by_project"].map { |p| [ p["name"], p["completed"] ] }, [ "Learn Rails", 2 ]
    assert_equal 1, json.dig("kpis", "overdue_open")
    assert(json["hours"].all? { |dow, hour, n| (1..7).cover?(dow) && (0..23).cover?(hour) && n.positive? })
  end

  test "a year is bucketed by week and the backlog has a point per bucket" do
    get api_v1_analytics_tasks_path(range: "1y"), as: :json
    assert_equal "week", json.dig("range", "unit")
    assert_includes 53..54, json["series"].size
    assert_equal json["series"].size, json["backlog"].size
    assert_equal 1, json["backlog"].last["overdue"]
  end

  test "unknown ranges fall back to 30 days" do
    get api_v1_analytics_tasks_path(range: "forever"), as: :json
    assert_equal 30, json.dig("range", "days")
  end

  test "results are cached until the data changes" do
    get api_v1_analytics_tasks_path(range: "7d"), as: :json
    before = json.dig("kpis", "completed")
    Task.create!(title: "Another", status: "done")
    get api_v1_analytics_tasks_path(range: "7d"), as: :json
    assert_equal before + 1, json.dig("kpis", "completed")
  end

  test "trackers: consistency, streaks, weekday rates and a moving average" do
    get api_v1_analytics_trackers_path(range: "7d"), as: :json
    meditate = json["trackers"].find { |t| t["name"] == "Meditate" }
    assert_equal 3, meditate["current_streak"]
    assert_equal 7, meditate["weekdays"].size
    assert_nil meditate["values"]

    water = json["trackers"].find { |t| t["name"] == "Water" }
    assert_equal 7, water["values"].size
    yesterday = water["values"][-2]
    assert_equal [ 9.0, 6.0 ], [ yesterday["value"], yesterday["avg7"] ] # avg of 3 and 9, nulls ignored
  end

  test "learning counts notes and journal days, never journal content" do
    get api_v1_analytics_learning_path(range: "30d"), as: :json
    assert_equal 2, json.dig("totals", "notes")
    assert_equal 1, json.dig("totals", "links")
    assert_equal 30, json["series"].size
    assert_equal %w[date journal_days notes_created notes_edited], json["series"].first.keys.sort
  end
end
