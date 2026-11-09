require "test_helper"

class TrackerTest < ActiveSupport::TestCase
  setup { Time.zone = "Asia/Kolkata" }
  teardown { Time.zone = "UTC" }

  test "frequency must be a known shape" do
    assert Tracker.new(name: "x", frequency: { type: "weekdays", days: [ 1, "3", 3 ] }).tap(&:validate).frequency == { "type" => "weekdays", "days" => [ 1, 3 ] }
    assert_not Tracker.new(name: "x", frequency: { type: "weekdays", days: [ 8 ] }).valid?
    assert_not Tracker.new(name: "x", frequency: { type: "weekly", times: 0 }).valid?
    assert_not Tracker.new(name: "x", frequency: { type: "hourly" }).valid?
  end

  test "yes/no trackers have no unit or target" do
    tracker = Tracker.create!(name: "Floss", kind: "boolean", unit: "times", target: 3)
    assert_nil tracker.unit
    assert_nil tracker.target
  end

  test "entries must fit the tracker's kind" do
    assert_not trackers(:meditate).entries.new(logged_on: Date.current, value: 2).valid?
    assert_not trackers(:water).entries.new(logged_on: Date.current, value: 2.5).valid?
    assert_not Tracker.create!(name: "Energy", kind: "scale").entries.new(logged_on: Date.current, value: 6).valid?
    assert_not trackers(:water).entries.new(logged_on: Date.current + 1, value: 1).valid?
  end

  test "one entry per tracker per day, enforced by the database" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      TrackerEntry.insert_all!([ { tracker_id: trackers(:meditate).id, logged_on: Date.current, value: 1, created_at: Time.current, updated_at: Time.current } ])
    end
  end

  test "streaks and completion come from gaps and islands" do
    stats = TrackerStatsQuery.new([ trackers(:meditate), trackers(:water) ]).call

    meditate = stats[trackers(:meditate).id]
    assert_equal [ 3, 3 ], [ meditate.current_streak, meditate.longest_streak ]
    assert_equal 4, meditate.periods_met

    # Today isn't logged yet, so the streak still counts from yesterday; 3 glasses missed the target.
    water = stats[trackers(:water).id]
    assert_equal [ 1, 1 ], [ water.current_streak, water.longest_streak ]
    assert_equal 0.2, water.completion_rate
  end

  test "weekly trackers count weeks that hit N check-ins" do
    tracker = Tracker.create!(name: "Run", kind: "boolean", frequency: { type: "weekly", times: 2 }, created_at: 21.days.ago)
    monday = Date.current.beginning_of_week
    [ monday - 14, monday - 13, monday - 7, monday - 6 ].each { |d| tracker.entries.create!(logged_on: d, value: 1) }
    stats = TrackerStatsQuery.new(tracker).call[tracker.id]
    assert_equal 2, stats.current_streak
  end

  test "a gap breaks the current streak" do
    tracker = Tracker.create!(name: "Read", kind: "boolean", created_at: 5.days.ago)
    tracker.entries.create!(logged_on: Date.current - 3, value: 1)
    assert_equal 0, TrackerStatsQuery.new(tracker).call[tracker.id].current_streak
  end
end
