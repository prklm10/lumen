# Reads a TipTap/ProseMirror document (notes.content) and pulls out what the server needs:
# plain text for search, [[wiki links]], #tags and the images it embeds. The editor is the
# only writer of this JSON, but it arrives from the browser, so every field is treated as untrusted.
class NoteContent
  TAG_PATTERN = /(?<![\p{L}\p{N}_&\/#])#([\p{L}\p{N}][\p{L}\p{N}_\/-]{0,49})/
  BLOCK_TYPES = %w[paragraph heading blockquote codeBlock listItem taskItem tableCell tableHeader callout].freeze
  Link = Data.define(:title, :note_id)

  def initialize(doc)
    @doc = doc.is_a?(Hash) ? doc.deep_stringify_keys : {}
  end

  # One line per block, so snippets and phrase search don't glue paragraphs together.
  def text
    @text ||= begin
      lines = []
      walk(@doc) { |node, _| lines << block_text(node) if BLOCK_TYPES.include?(node["type"]) && leaf_block?(node) }
      lines.reject(&:blank?).join("\n")
    end
  end

  def links
    @links ||= nodes("wikiLink").filter_map do |node|
      title = node.dig("attrs", "title").to_s.strip.first(200)
      Link.new(title:, note_id: Integer(node.dig("attrs", "id"), exception: false)) if title.present?
    end.uniq { |link| link.title.downcase }
  end

  # #tags in prose (not in code blocks, where # means something else).
  def tag_names
    @tag_names ||= begin
      found = []
      walk(@doc) { |node, in_code| found.concat(node["text"].to_s.scan(TAG_PATTERN).flatten) if node["type"] == "text" && !in_code }
      found.map { |t| t.delete_suffix("/") }.uniq(&:downcase)
    end
  end

  def image_signed_ids
    nodes("image").filter_map { |node| node.dig("attrs", "signedId").presence }.uniq
  end

  private
    def nodes(type)
      found = []
      walk(@doc) { |node, _| found << node if node["type"] == type }
      found
    end

    def walk(node, in_code = false, &block)
      return unless node.is_a?(Hash)

      in_code ||= node["type"] == "codeBlock" || Array(node["marks"]).any? { |m| m.is_a?(Hash) && m["type"] == "code" }
      yield node, in_code
      Array(node["content"]).each { |child| walk(child, in_code, &block) }
    end

    def leaf_block?(node) = Array(node["content"]).none? { |c| c.is_a?(Hash) && BLOCK_TYPES.include?(c["type"]) }

    def block_text(node)
      Array(node["content"]).map do |child|
        next unless child.is_a?(Hash)
        case child["type"]
        when "text" then child["text"].to_s
        when "wikiLink" then child.dig("attrs", "title").to_s
        when "hardBreak" then " "
        else block_text(child)
        end
      end.join
    end
end
