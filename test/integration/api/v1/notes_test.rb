require "test_helper"

class Api::V1::NotesTest < ActionDispatch::IntegrationTest
  setup { sign_in }

  test "index lists kept notes without content" do
    get api_v1_notes_path, as: :json
    assert_equal [ "Postgres indexes", "Query planner" ], json["notes"].map { |n| n["title"] }
    assert_not json["notes"].first.key?("content")
  end

  test "show includes content, tags and backlinks" do
    get api_v1_note_path(notes(:planner)), as: :json
    assert_equal [ { "id" => notes(:indexes).id, "title" => "Postgres indexes", "icon" => nil } ], json["backlinks"]
    assert_equal "doc", json.dig("content", "type")
  end

  test "create and autosave with lock_version" do
    post api_v1_notes_path, as: :json, params: { note: { title: "Joins", folder_id: folders(:tech).id } }
    assert_response :created
    id, version = json.values_at("id", "lock_version")

    content = { type: "doc", content: [ { type: "paragraph", content: [ { type: "text", text: "Hash join #sql" } ] } ] }
    patch api_v1_note_path(id), as: :json, params: { note: { content:, lock_version: version } }
    assert_response :success
    assert_equal [ "sql" ], json["tags"].map { |t| t["name"] }

    patch api_v1_note_path(id), as: :json, params: { note: { title: "Stale", lock_version: version } }
    assert_response :conflict
    assert_equal "stale_note", json.dig("error", "code")
  end

  test "moving or pinning a note doesn't conflict with the editor's lock_version" do
    note = notes(:planner)
    version, edited_at = note.lock_version, note.updated_at
    patch api_v1_note_path(note), as: :json, params: { note: { folder_id: folders(:tech).id, pinned: false } }
    assert_response :success
    assert_equal [ version, folders(:tech).id, false ], json.values_at("lock_version", "folder_id", "pinned")
    assert_equal edited_at.to_i, note.reload.updated_at.to_i

    patch api_v1_note_path(note), as: :json, params: { note: { title: "Planner", lock_version: version } }
    assert_response :success

    patch api_v1_note_path(note), as: :json, params: { note: { folder_id: 0 } }
    assert_response :unprocessable_entity
  end

  test "content must be a JSON document" do
    patch api_v1_note_path(notes(:planner)), as: :json, params: { note: { content: "<p>hi</p>" } }
    assert_response :unprocessable_entity
  end

  test "delete is a soft delete" do
    delete api_v1_note_path(notes(:planner)), as: :json
    assert_response :no_content
    get api_v1_note_path(notes(:planner)), as: :json
    assert_response :not_found
  end

  test "folders: tree, move, no cycles, delete keeps contents" do
    get api_v1_folders_path, as: :json
    assert_equal [ "Tech", "Databases" ], json["folders"].map { |f| f["name"] }

    patch api_v1_folder_path(folders(:tech)), as: :json, params: { folder: { parent_id: folders(:databases).id } }
    assert_response :unprocessable_entity

    delete api_v1_folder_path(folders(:databases)), as: :json
    assert_response :no_content
    assert_equal folders(:tech).id, notes(:planner).reload.folder_id
  end

  test "search ranks notes by text and tolerates typos in titles" do
    get api_v1_search_path(q: "analyz"), as: :json
    assert_equal [ "Query planner" ], json["notes"].map { |n| n["title"] }
    assert_includes json["notes"].first["snippet"], "#{SearchQuery::MARK_START}ANALYZE#{SearchQuery::MARK_STOP}"

    get api_v1_search_path(q: "postgress indxes"), as: :json
    assert_equal "Postgres indexes", json["notes"].first&.dig("title")

    get api_v1_search_path(q: "passport"), as: :json
    assert_equal [ "Renew passport" ], json["tasks"].map { |t| t["title"] }
  end

  test "search never errors on stop words or symbols" do
    get api_v1_search_path(q: "the"), as: :json
    assert_response :success
    get api_v1_search_path(q: "&|!"), as: :json
    assert_equal({ "notes" => [], "tasks" => [] }, json)
  end
end
