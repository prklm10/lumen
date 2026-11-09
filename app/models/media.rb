# Image uploads (PRD §4.6). Originals are kept as uploaded, but only re-encoded WebP variants
# are ever served — re-encoding with `strip` drops EXIF/GPS metadata, so a photo's location
# never leaves the server.
module Media
  CONTENT_TYPES = %w[image/jpeg image/png image/webp image/gif image/avif image/heic image/heif].freeze
  MAX_BYTES = Integer(ENV.fetch("LUMEN_MAX_UPLOAD_MB", 20)) * 1024 * 1024

  VARIANTS = {
    "thumb" => 320,
    "medium" => 1024,
    "large" => 2048
  }.freeze

  def self.variant(blob, name)
    size = VARIANTS.fetch(name)
    blob.variant(resize_to_limit: [ size, size ], format: :webp, saver: { strip: true, quality: 82 })
  end
end
