module Api
  module V1
    # POST /api/v1/uploads (multipart, field "file") → a stored image the editor can embed.
    # The type is sniffed from the bytes (Marcel), not trusted from the filename or browser.
    class UploadsController < BaseController
      def create
        file = params.require(:file)
        raise InvalidParameter, "file must be an uploaded file" unless file.respond_to?(:tempfile)
        return render_error(:content_too_large, "file_too_large", "Images can be up to #{Media::MAX_BYTES / 1.megabyte} MB.") if file.size > Media::MAX_BYTES

        content_type = Marcel::MimeType.for(file.tempfile, name: file.original_filename)
        unless Media::CONTENT_TYPES.include?(content_type)
          return render_error(:unsupported_media_type, "unsupported_type", "Only JPEG, PNG, WebP, GIF, AVIF and HEIC images are supported.")
        end

        blob = ActiveStorage::Blob.create_and_upload!(io: file.tempfile, filename: file.original_filename, content_type:, identify: false)
        blob.analyze
        render json: UploadResource.new(blob).to_h, status: :created
      end
    end
  end
end
