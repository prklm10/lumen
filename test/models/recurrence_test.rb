require "test_helper"

class RecurrenceTest < ActiveSupport::TestCase
  test "parses, normalizes and rejects bad rules" do
    assert_equal "FREQ=WEEKLY;INTERVAL=1;BYDAY=MO,WE", Recurrence.parse("FREQ=WEEKLY;BYDAY=WE,MO").to_s
    assert_raises(Recurrence::Invalid) { Recurrence.parse("FREQ=HOURLY") }
    assert_raises(Recurrence::Invalid) { Recurrence.parse("FREQ=DAILY;BYDAY=MO") }
    assert_raises(Recurrence::Invalid) { Recurrence.parse("FREQ=DAILY;INTERVAL=0") }
  end

  test "next occurrence for each frequency" do
    monday = Date.new(2026, 11, 2)
    assert_equal monday + 2, Recurrence.parse("FREQ=DAILY;INTERVAL=2").next_after(monday)
    assert_equal monday + 2, Recurrence.parse("FREQ=WEEKLY;BYDAY=MO,WE").next_after(monday)
    assert_equal monday + 7, Recurrence.parse("FREQ=WEEKLY;BYDAY=MO,WE").next_after(monday + 2)
    assert_equal monday + 14, Recurrence.parse("FREQ=WEEKLY;INTERVAL=2;BYDAY=MO").next_after(monday)
    assert_equal Date.new(2027, 2, 28), Recurrence.parse("FREQ=MONTHLY").next_after(Date.new(2027, 1, 31))
    assert_equal Date.new(2027, 11, 2), Recurrence.parse("FREQ=YEARLY").next_after(monday)
  end

  test "skips occurrences that are already in the past" do
    assert_equal Date.new(2026, 11, 11), Recurrence.parse("FREQ=DAILY").next_occurrence(Date.new(2026, 11, 1), today: Date.new(2026, 11, 10))
  end
end
