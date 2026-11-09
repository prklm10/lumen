require "test_helper"

class TaskTest < ActiveSupport::TestCase
  setup { Time.zone = "Asia/Kolkata" }
  teardown { Time.zone = "UTC" }

  test "completing sets completed_at and reopening clears it" do
    task = tasks(:inbox_task)
    task.complete!
    assert task.done?
    assert_not_nil task.completed_at

    task.reopen!
    assert task.todo?
    assert_nil task.completed_at
  end

  test "the database itself rejects done without completed_at" do
    assert_raises(ActiveRecord::StatementInvalid) { tasks(:inbox_task).update_column(:status, "done") }
  end

  test "a subtask inherits its parent's project and section" do
    parent = tasks(:due_today)
    sub = Task.create!(title: "Take notes", parent:, project: projects(:archived))
    assert_equal [ parent.project_id, parent.section_id ], [ sub.project_id, sub.section_id ]
  end

  test "subtasks move with their parent" do
    parent = tasks(:parent)
    parent.update!(project: projects(:rails))
    assert_equal [ projects(:rails).id ] * 2, parent.subtasks.map(&:project_id)
  end

  test "only one level of nesting" do
    nested = Task.new(title: "Too deep", parent: tasks(:subtask_one))
    assert_not nested.valid?
    assert nested.errors[:parent_id].any?

    tasks(:parent).parent = tasks(:inbox_task)
    assert_not tasks(:parent).valid?
  end

  test "the section must belong to the task's project" do
    other = Project.create!(name: "Other")
    task = Task.new(title: "x", project: other, section: sections(:week_one))
    assert_not task.valid?
    assert task.errors[:section_id].any?
  end

  test "moving to another project drops the old section" do
    task = tasks(:due_today)
    task.update!(project_id: nil)
    assert_nil task.section_id
  end

  test "no new tasks in an archived project" do
    task = Task.new(title: "x", project: projects(:archived))
    assert_not task.valid?
    assert task.errors[:project_id].any?
  end

  test "due_at sets due_date in the user's zone, not UTC" do
    # 20:00 UTC on Nov 1 is already Nov 2 in Kolkata (UTC+5:30).
    task = Task.create!(title: "Late call", due_at: Time.utc(2026, 11, 1, 20, 0))
    assert_equal Date.new(2026, 11, 2), task.due_date
  end

  test "snoozing keeps the time of day; clearing the date clears the time" do
    task = Task.create!(title: "Call", due_at: Time.zone.local(2026, 11, 2, 18, 0))
    task.update!(due_date: Date.new(2026, 11, 5))
    assert_equal Time.zone.local(2026, 11, 5, 18, 0), task.due_at

    task.update!(due_date: nil)
    assert_nil task.due_at
  end

  test "new tasks go to the end of their container" do
    assert_equal 5, Task.create!(title: "Next", project: projects(:rails)).position
    assert_equal 1, Task.create!(title: "First in section", project: projects(:rails), section: Section.create!(project: projects(:rails), name: "Week 2")).position
  end

  test "history is recorded for create, status change, reschedule and discard" do
    task = Task.create!(title: "Track me", due_date: Date.new(2026, 11, 2))
    task.update!(due_date: Date.new(2026, 11, 4), status: "in_progress")
    task.discard!

    assert_equal %w[created status_changed rescheduled discarded], task.events.map(&:event)
    assert_equal [ "todo", "in_progress" ], task.events.status_changed.first.values_at(:from_status, :to_status)
    assert_equal [ Date.new(2026, 11, 2), Date.new(2026, 11, 4) ], task.events.rescheduled.first.values_at(:from_due_date, :to_due_date)
    assert task.events.first.readonly?
  end

  test "discarding a parent discards its subtasks" do
    tasks(:parent).discard!
    assert tasks(:subtask_one).reload.discarded?
  end

  test "overdue uses the due time when there is one" do
    assert tasks(:overdue).overdue?
    assert_not tasks(:due_today).overdue?
    assert Task.new(status: "todo", due_date: Date.current, due_at: 1.minute.ago).overdue?
  end

  test "tag names are normalized and matched case-insensitively" do
    task = tasks(:inbox_task)
    task.update!(tag_names: [ "#Postgres ", "POSTGRES", "new-tag" ])
    assert_equal %w[new-tag postgres], task.reload.tags.map(&:name)
    assert_equal tags(:postgres), task.tags.find_by(name: "postgres")
  end

  test "completing a recurring task schedules the next one with the same time and tags" do
    task = Task.create!(title: "Water plants", due_at: Time.zone.local(2026, 11, 2, 9, 0), recurrence_rule: "freq=weekly;byday=mo,th", tag_names: [ "home" ])
    travel_to Time.zone.local(2026, 11, 2, 10, 0) do
      assert_difference -> { Task.count }, 1 do
        task.complete!
      end
    end
    nxt = Task.order(:id).last
    assert_equal [ Date.new(2026, 11, 5), 9, "FREQ=WEEKLY;INTERVAL=1;BYDAY=MO,TH", [ "home" ] ],
      [ nxt.due_date, nxt.due_at.hour, nxt.recurrence_rule, nxt.tags.map(&:name) ]
    assert nxt.todo?
    assert task.reload.done?
  end

  test "invalid repeat rules are rejected" do
    assert_not Task.new(title: "x", recurrence_rule: "FREQ=SOMETIMES").valid?
  end

  test "restoring a parent restores the subtasks deleted with it" do
    tasks(:parent).discard!
    tasks(:parent).restore!
    assert_not tasks(:subtask_one).reload.discarded?
  end
end
