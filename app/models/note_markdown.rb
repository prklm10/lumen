# Converts a note's TipTap JSON to Markdown (Obsidian-flavoured: [[wiki links]], > [!INFO]
# callouts, - [ ] tasks, GFM tables) for export (PRD LRN-14, "no lock-in").
class NoteMarkdown
  def initialize(doc) = @doc = doc.is_a?(Hash) ? doc.deep_stringify_keys : {}

  def to_s = blocks(@doc["content"]).join("\n\n").gsub(/\n{3,}/, "\n\n").strip + "\n"

  private
    def blocks(nodes, prefix = "") = Array(nodes).map { |n| block(n, prefix) }.compact

    def block(node, prefix)
      case node["type"]
      when "paragraph" then inline(node["content"])
      when "heading" then "#{"#" * node.dig("attrs", "level").to_i.clamp(1, 6)} #{inline(node["content"])}"
      when "blockquote" then quote(blocks(node["content"]).join("\n\n"))
      when "callout" then quote("[!#{node.dig("attrs", "kind").to_s.upcase.presence || "INFO"}]\n" + blocks(node["content"]).join("\n\n"))
      when "codeBlock" then "```#{node.dig("attrs", "language")}\n#{text_of(node)}\n```"
      when "horizontalRule" then "---"
      when "bulletList" then list(node, ->(_) { "- " })
      when "orderedList" then list(node, ->(i) { "#{i + node.dig("attrs", "start").to_i.clamp(1, 10_000)}. " })
      when "taskList" then list(node, ->(_) { "- [ ] " })
      when "table" then table(node)
      when "image" then "![#{node.dig("attrs", "alt")}](#{node.dig("attrs", "src")})"
      else inline(node["content"]).presence
      end
    end

    def list(node, marker)
      Array(node["content"]).each_with_index.map do |item, i|
        mark = marker.(i)
        mark = "- [x] " if item["type"] == "taskItem" && item.dig("attrs", "checked")
        first, *rest = blocks(item["content"])
        indent = " " * mark.length
        ([ "#{mark}#{first}" ] + rest.map { |b| b.gsub(/^/, indent) }).join("\n")
      end.join("\n")
    end

    def table(node)
      rows = Array(node["content"]).map { |row| Array(row["content"]).map { |cell| blocks(cell["content"]).join(" ").gsub("|", "\\|") } }
      return "" if rows.empty?
      width = rows.map(&:size).max
      rows = rows.map { |r| r + [ "" ] * (width - r.size) }
      ([ rows.first, [ "---" ] * width ] + rows.drop(1)).map { |r| "| #{r.join(" | ")} |" }.join("\n")
    end

    def quote(text) = text.lines.map { |l| l.strip.empty? ? ">" : "> #{l.chomp}" }.join("\n")

    def inline(nodes)
      Array(nodes).map do |n|
        case n["type"]
        when "text" then marks(n["text"].to_s, Array(n["marks"]))
        when "hardBreak" then "  \n"
        when "wikiLink" then "[[#{n.dig("attrs", "title")}]]"
        when "image" then "![#{n.dig("attrs", "alt")}](#{n.dig("attrs", "src")})"
        else inline(n["content"])
        end
      end.join
    end

    def marks(text, marks)
      marks.reverse_each do |m|
        text = case m["type"]
        when "bold" then "**#{text}**"
        when "italic" then "_#{text}_"
        when "strike" then "~~#{text}~~"
        when "code" then "`#{text}`"
        when "link" then "[#{text}](#{m.dig("attrs", "href")})"
        else text
        end
      end
      text
    end

    def text_of(node) = node["text"].to_s + Array(node["content"]).map { |c| text_of(c) }.join
end
