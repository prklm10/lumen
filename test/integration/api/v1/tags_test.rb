require "test_helper"

class Api::V1::TagsTest < ActionDispatch::IntegrationTest
  setup { sign_in }

  test "lists tags with task counts" do
    get api_v1_tags_path, as: :json
    assert_equal [ [ "errands", 1 ], [ "postgres", 1 ] ], json["tags"].map { |t| t.values_at("name", "task_count") }
  end

  test "rename collisions are rejected, case-insensitively" do
    patch api_v1_tag_path(tags(:errands)), as: :json, params: { tag: { name: "Postgres" } }
    assert_response :unprocessable_entity
  end

  test "deleting a tag untags its tasks" do
    delete api_v1_tag_path(tags(:errands)), as: :json
    assert_response :no_content
    assert_empty tasks(:overdue).reload.tags
  end

  test "meta lists colors, priorities and statuses" do
    get api_v1_meta_path, as: :json
    assert_includes json["colors"], "violet"
    assert_equal({ "value" => "urgent", "label" => "Urgent" }, json["priorities"].last)
  end
end
