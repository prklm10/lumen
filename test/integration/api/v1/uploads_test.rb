require "test_helper"

class Api::V1::UploadsTest < ActionDispatch::IntegrationTest
  test "uploads an image and serves resized WebP variants to the signed-in user only" do
    sign_in
    post api_v1_uploads_path, params: { file: fixture_file_upload("photo.jpg", "image/jpeg") }
    assert_response :created
    assert_equal "image/jpeg", json["content_type"]
    assert_equal [ 1600, 1200 ], json.values_at("width", "height")

    thumb_url = json["thumb_url"]
    get thumb_url
    assert_response :success
    assert_equal "image/webp", response.media_type
    thumb = Vips::Image.new_from_buffer(response.body, "")
    assert_equal [ 320, 240 ], [ thumb.width, thumb.height ]
    assert_equal 0, thumb.get_typeof("exif-data"), "variants must not carry EXIF metadata"

    delete api_v1_session_path, as: :json
    get thumb_url
    assert_response :unauthorized
  end

  test "rejects files that aren't images, whatever they're called" do
    sign_in
    post api_v1_uploads_path, params: { file: fixture_file_upload("not-an-image.png", "image/png") }
    assert_response :unsupported_media_type
    assert_equal "unsupported_type", json.dig("error", "code")
  end

  test "requires sign in" do
    post api_v1_uploads_path, params: { file: fixture_file_upload("photo.jpg", "image/jpeg") }
    assert_response :unauthorized
  end

  test "Active Storage's public routes are off" do
    assert_not Rails.application.routes.named_routes.key?(:rails_blob_representation)
  end
end
