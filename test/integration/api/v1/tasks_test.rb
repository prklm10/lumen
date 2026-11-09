require "test_helper"

class Api::V1::TasksTest < ActionDispatch::IntegrationTest
  setup { sign_in }

  def titles = json["tasks"].map { |t| t["title"] }

  test "requires sign in" do
    delete api_v1_session_path, as: :json
    get api_v1_tasks_path(view: "inbox"), as: :json
    assert_response :unauthorized
  end

  test "an unknown view is rejected" do
    get api_v1_tasks_path(view: "nope"), as: :json
    assert_response :unprocessable_entity
    assert_equal "invalid_parameter", json.dig("error", "code")
  end

  test "today: overdue first, then due today, then finished today" do
    get api_v1_tasks_path(view: "today"), as: :json
    assert_response :success
    assert_equal [ "Renew passport", "Read chapter 3 of PG internals", "Set up Docker" ], titles

    overdue = json["tasks"].first
    assert overdue["overdue"]
    assert_equal [ "errands" ], overdue["tags"].map { |t| t["name"] }
  end

  test "upcoming covers the next seven days" do
    get api_v1_tasks_path(view: "upcoming"), as: :json
    assert_equal [ "Read chapter 3 of PG internals", "Write a migration" ], titles
  end

  test "inbox holds top-level tasks without a project, with subtask progress" do
    get api_v1_tasks_path(view: "inbox"), as: :json
    assert_equal [ "Buy groceries", "Renew passport", "Plan the week" ], titles

    parent = json["tasks"].last
    assert_equal [ 2, 1 ], parent.values_at("subtask_count", "subtask_done_count")
  end

  test "project view, optionally with done tasks" do
    get api_v1_tasks_path(view: "project", project_id: projects(:rails).id), as: :json
    assert_equal [ "Write a migration", "Read chapter 3 of PG internals" ], titles

    get api_v1_tasks_path(view: "project", project_id: projects(:rails).id, include_done: true), as: :json
    assert_equal 4, titles.size
  end

  test "completed log pages with a cursor" do
    get api_v1_tasks_path(view: "completed", limit: 1), as: :json
    assert_equal [ "Set up Docker" ], titles
    assert json["next_cursor"]

    get api_v1_tasks_path(view: "completed", limit: 1, cursor: json["next_cursor"]), as: :json
    assert_equal [ "Install Ruby" ], titles
    assert_nil json["next_cursor"]
  end

  test "search matches word prefixes and includes subtasks" do
    get api_v1_tasks_path(view: "search", q: "goal"), as: :json
    assert_equal [ "Pick three goals" ], titles
  end

  test "filter by tag" do
    get api_v1_tasks_path(view: "today", tag: "postgres"), as: :json
    assert_equal [ "Read chapter 3 of PG internals" ], titles
  end

  test "discarded tasks are hidden and 404" do
    get api_v1_task_path(tasks(:discarded)), as: :json
    assert_response :not_found
  end

  test "show includes subtasks" do
    get api_v1_task_path(tasks(:parent)), as: :json
    assert_equal [ "Pick three goals", "Block focus time" ], json["subtasks"].map { |t| t["title"] }
  end

  test "create with tags" do
    post api_v1_tasks_path, as: :json, params: { task: { title: "Call mom", priority: "urgent", due_date: Date.current, tag_names: [ "family" ],
      description: { type: "doc", content: [ { type: "paragraph", content: [ { type: "text", text: "hi" } ] } ] } } }
    assert_response :created
    assert_equal "urgent", json["priority"]
    assert_equal [ "family" ], json["tags"].map { |t| t["name"] }
    assert_equal "hi", json.dig("description", "content", 0, "content", 0, "text")
    assert_equal %w[created], Task.find(json["id"]).events.map(&:event)
  end

  test "validation errors come back per field" do
    [ { title: "" }, { title: "x", priority: "extreme" }, { title: "x", parent_id: tasks(:subtask_one).id },
      { title: "x", project_id: projects(:archived).id } ].each do |attrs|
      post api_v1_tasks_path, as: :json, params: { task: attrs }
      assert_response :unprocessable_entity
      assert_equal "validation_failed", json.dig("error", "code")
      assert_equal 1, json.dig("error", "details").size, attrs.inspect
    end
  end

  test "tag_names replaces tags; leaving it out keeps them" do
    task = tasks(:overdue)
    patch api_v1_task_path(task), as: :json, params: { task: { title: "Renew passport!" } }
    assert_equal [ "errands" ], json["tags"].map { |t| t["name"] }

    patch api_v1_task_path(task), as: :json, params: { task: { tag_names: [] } }
    assert_empty json["tags"]
  end

  test "a failed update doesn't change tags either" do
    patch api_v1_task_path(tasks(:overdue)), as: :json, params: { task: { title: "", tag_names: [ "new" ] } }
    assert_response :unprocessable_entity
    assert_equal [ "errands" ], tasks(:overdue).reload.tags.map(&:name)
  end

  test "complete and reopen" do
    post complete_api_v1_task_path(tasks(:inbox_task)), as: :json
    assert_equal "done", json["status"]
    assert json["completed_at"]

    post reopen_api_v1_task_path(tasks(:inbox_task)), as: :json
    assert_equal "todo", json["status"]
  end

  test "delete is a soft delete" do
    delete api_v1_task_path(tasks(:inbox_task)), as: :json
    assert_response :no_content
    assert tasks(:inbox_task).reload.discarded?
  end

  test "reorder moves tasks, across sections too" do
    patch reorder_api_v1_tasks_path, as: :json, params: { moves: [
      { id: tasks(:due_later).id, position: 0.5, section_id: sections(:week_one).id }
    ] }
    assert_response :success
    assert_equal sections(:week_one).id, tasks(:due_later).reload.section_id
    assert_equal 0.5, tasks(:due_later).position
  end

  test "reorder is all or nothing" do
    patch reorder_api_v1_tasks_path, as: :json, params: { moves: [
      { id: tasks(:due_later).id, position: 9 },
      { id: tasks(:inbox_task).id, position: 1, section_id: sections(:week_one).id }
    ] }
    assert_response :unprocessable_entity
    assert_equal 2, tasks(:due_later).reload.position
  end

  test "counts match the views" do
    get counts_api_v1_tasks_path, as: :json
    assert_equal({ "inbox" => 3, "today" => 2, "overdue" => 1, "upcoming" => 2,
      "projects" => { projects(:rails).id.to_s => 2 } }, json)
  end

  test "list queries don't grow with the number of tasks" do
    20.times { |i| Task.create!(title: "Bulk #{i}", due_date: Date.current, tag_names: [ "bulk" ]) }
    queries = 0
    counter = ->(*, payload) { queries += 1 unless payload[:name] == "SCHEMA" || payload[:cached] }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get api_v1_tasks_path(view: "today"), as: :json }
    assert_operator queries, :<=, 8
  end
end
