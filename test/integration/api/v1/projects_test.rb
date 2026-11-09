require "test_helper"

class Api::V1::ProjectsTest < ActionDispatch::IntegrationTest
  setup { sign_in }

  test "lists active projects with sections and open task counts" do
    get api_v1_projects_path, as: :json
    assert_equal [ "Learn Rails" ], json["projects"].map { |p| p["name"] }
    project = json["projects"].first
    assert_equal 2, project["open_task_count"]
    assert_equal [ "Week 1" ], project["sections"].map { |s| s["name"] }

    get api_v1_projects_path(include_archived: true), as: :json
    assert_equal 2, json["projects"].size
  end

  test "create, rename and archive" do
    post api_v1_projects_path, as: :json, params: { project: { name: "Reading", color: "teal", icon: "book-open" } }
    assert_response :created
    assert_equal 3, json["position"]

    patch api_v1_project_path(json["id"]), as: :json, params: { project: { archived: true } }
    assert json["archived"]
  end

  test "rejects colors outside the palette" do
    post api_v1_projects_path, as: :json, params: { project: { name: "x", color: "chartreuse" } }
    assert_response :unprocessable_entity
  end

  test "a project with tasks can't be deleted" do
    delete api_v1_project_path(projects(:rails)), as: :json
    assert_response :conflict
    assert_equal "project_not_empty", json.dig("error", "code")

    delete api_v1_project_path(projects(:archived)), as: :json
    assert_response :no_content
  end

  test "sections: create, rename, delete moves tasks to the project root" do
    post api_v1_project_sections_path(projects(:rails)), as: :json, params: { section: { name: "Week 2" } }
    assert_response :created
    assert_equal 2, json["position"]

    patch api_v1_project_section_path(projects(:rails), sections(:week_one)), as: :json, params: { section: { name: "Kickoff" } }
    assert_equal "Kickoff", json["name"]

    delete api_v1_project_section_path(projects(:rails), sections(:week_one)), as: :json
    assert_response :no_content
    assert_nil tasks(:due_today).reload.section_id
  end

  test "a section is only reachable through its own project" do
    patch api_v1_project_section_path(projects(:archived), sections(:week_one)), as: :json, params: { section: { name: "x" } }
    assert_response :not_found
  end
end
