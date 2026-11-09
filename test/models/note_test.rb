require "test_helper"

class NoteTest < ActiveSupport::TestCase
  def doc(*nodes) = { "type" => "doc", "content" => nodes }
  def para(*inline) = { "type" => "paragraph", "content" => inline }
  def text(t) = { "type" => "text", "text" => t }
  def link(title, id = nil) = { "type" => "wikiLink", "attrs" => { "title" => title, "id" => id } }

  test "extracts searchable text, one line per block, including link titles" do
    note = Note.create!(title: "x", content: doc(para(text("Hello "), link("World")), { "type" => "heading", "content" => [ text("Next") ] }))
    assert_equal "Hello World\nNext", note.content_text
  end

  test "tags come from #words in prose, not from code" do
    code = { "type" => "codeBlock", "content" => [ text("#include <stdio.h>") ] }
    note = Note.create!(title: "x", content: doc(para(text("Learning #Postgres and #rails/active-record, not C#")), code))
    assert_equal %w[postgres rails/active-record], note.tags.map(&:name).sort
  end

  test "links resolve by id or title, and dangling links attach when the note appears" do
    note = Note.create!(title: "x", content: doc(para(link("Query planner"), link("Future idea"))))
    assert_equal notes(:planner).id, note.outgoing_links.find_by(target_title: "Query planner").target_note_id
    assert_nil note.outgoing_links.find_by(target_title: "Future idea").target_note_id

    future = Note.create!(title: "future IDEA")
    assert_equal future.id, note.outgoing_links.find_by(target_title: "Future idea").target_note_id
  end

  test "removing a link from the content removes it from backlinks" do
    assert_equal [ notes(:indexes) ], notes(:planner).backlinks.to_a
    notes(:indexes).update!(content: doc(para(text("no links"))))
    assert_empty notes(:planner).backlinks
  end

  test "discarded notes don't count as backlinks" do
    notes(:indexes).discard!
    assert_empty notes(:planner).backlinks
  end

  test "blank titles become Untitled" do
    assert_equal "Untitled", Note.create!(title: "  ").title
  end

  test "content must be a document" do
    note = Note.new(title: "x", content: { "type" => "paragraph" })
    assert_not note.valid?
  end

  test "optimistic locking stops a stale save" do
    stale = Note.find(notes(:planner).id)
    notes(:planner).update!(title: "Planner v2")
    assert_raises(ActiveRecord::StaleObjectError) { stale.update!(title: "Planner v3") }
  end
end
