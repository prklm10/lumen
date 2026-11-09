class UploadResource
  include Alba::Resource
  include Rails.application.routes.url_helpers

  attribute(:signed_id) { |blob| blob.signed_id }
  attributes :filename, :content_type, :byte_size
  attribute(:width) { |blob| blob.metadata["width"] }
  attribute(:height) { |blob| blob.metadata["height"] }
  attribute(:url) { |blob| media_path(blob.signed_id, "medium") }
  attribute(:large_url) { |blob| media_path(blob.signed_id, "large") }
  attribute(:thumb_url) { |blob| media_path(blob.signed_id, "thumb") }
end
