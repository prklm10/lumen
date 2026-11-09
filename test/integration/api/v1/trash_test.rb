require "test_helper"

class Api::V1::TrashTest < ActionDispatch::IntegrationTest
  setup { sign_in }

  test "lists deleted tasks and notes, restores and deletes forever" do
    delete api_v1_task_path(tasks(:inbox_task)), as: :json
    delete api_v1_note_path(notes(:planner)), as: :json

    get api_v1_trash_path, as: :json
    titles = json["items"].map { |i| i["title"] }
    assert_includes titles, "Buy groceries"
    assert_includes titles, "Query planner"
    assert_includes titles, "Old idea"
    assert_equal 30, json["retention_days"]

    post api_v1_trash_restore_path("task", tasks(:inbox_task).id), as: :json
    assert_response :no_content
    assert_not tasks(:inbox_task).reload.discarded?

    delete api_v1_trash_item_path("note", notes(:planner).id), as: :json
    assert_response :no_content
    assert_not Note.exists?(notes(:planner).id)
  end

  test "kept items can't be purged through the trash" do
    delete api_v1_trash_item_path("task", tasks(:inbox_task).id), as: :json
    assert_response :not_found
  end

  test "the purge job removes only items older than the retention period" do
    tasks(:inbox_task).update_column(:discarded_at, 31.days.ago)
    TrashPurgeJob.perform_now
    assert_not Task.exists?(tasks(:inbox_task).id)
    assert Task.exists?(tasks(:discarded).id)
  end
end
