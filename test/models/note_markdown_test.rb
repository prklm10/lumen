require "test_helper"

class NoteMarkdownTest < ActiveSupport::TestCase
  def t(text, *marks) = { "type" => "text", "text" => text, "marks" => marks.map { |m| m.is_a?(Hash) ? m : { "type" => m } } }
  def para(*inline) = { "type" => "paragraph", "content" => inline }

  test "converts blocks and marks to Markdown" do
    doc = { "type" => "doc", "content" => [
      { "type" => "heading", "attrs" => { "level" => 2 }, "content" => [ t("Indexes") ] },
      para(t("Use "), t("B-trees", "bold"), t(" and "), t("GIN", "code"), t(" — see "), { "type" => "wikiLink", "attrs" => { "title" => "Planner" } }, t(" or "), t("docs", { "type" => "link", "attrs" => { "href" => "https://postgresql.org" } })),
      { "type" => "bulletList", "content" => [ { "type" => "listItem", "content" => [ para(t("one")) ] }, { "type" => "listItem", "content" => [ para(t("two")) ] } ] },
      { "type" => "taskList", "content" => [ { "type" => "taskItem", "attrs" => { "checked" => true }, "content" => [ para(t("done")) ] } ] },
      { "type" => "callout", "attrs" => { "kind" => "warning" }, "content" => [ para(t("Careful")) ] },
      { "type" => "codeBlock", "attrs" => { "language" => "sql" }, "content" => [ t("SELECT 1;") ] },
      { "type" => "table", "content" => [
        { "type" => "tableRow", "content" => [ { "type" => "tableHeader", "content" => [ para(t("a")) ] }, { "type" => "tableHeader", "content" => [ para(t("b")) ] } ] },
        { "type" => "tableRow", "content" => [ { "type" => "tableCell", "content" => [ para(t("1|2")) ] }, { "type" => "tableCell", "content" => [ para(t("3")) ] } ] }
      ] }
    ] }

    assert_equal <<~MD, NoteMarkdown.new(doc).to_s
      ## Indexes

      Use **B-trees** and `GIN` — see [[Planner]] or [docs](https://postgresql.org)

      - one
      - two

      - [x] done

      > [!WARNING]
      > Careful

      ```sql
      SELECT 1;
      ```

      | a | b |
      | --- | --- |
      | 1\\|2 | 3 |
    MD
  end
end
