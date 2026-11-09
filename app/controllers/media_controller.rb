# GET /media/:signed_id/:variant — serves a resized, metadata-stripped WebP of an upload.
# Unlike Active Storage's built-in routes (public to anyone holding the URL), this one
# requires the signed-in session, and originals are never served.
class MediaController < ApplicationController
  include ActiveStorage::Streaming

  def show
    blob = ActiveStorage::Blob.find_signed!(params[:signed_id])
    raise ActiveRecord::RecordNotFound unless Media::VARIANTS.key?(params[:variant]) && blob.variable?

    variant = Media.variant(blob, params[:variant]).processed
    http_cache_forever(public: false) do
      send_blob_stream variant.image.blob, disposition: :inline
    end
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
    head :not_found
  end

  private
    # <img> requests can't be redirected to a login page usefully; just refuse.
    def request_authentication
      head :unauthorized
    end
end
