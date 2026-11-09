require "test_helper"

class FlashcardTest < ActiveSupport::TestCase
  test "SM-2 intervals grow 1, 6, then by ease; a lapse starts over" do
    today = Date.new(2026, 11, 2)
    r1 = Sm2.review(ease: 2.5, interval_days: 0, repetitions: 0, grade: 4, today:)
    r2 = Sm2.review(ease: r1.ease, interval_days: r1.interval_days, repetitions: r1.repetitions, grade: 4, today:)
    r3 = Sm2.review(ease: r2.ease, interval_days: r2.interval_days, repetitions: r2.repetitions, grade: 5, today:)
    assert_equal [ 1, 6, 16 ], [ r1.interval_days, r2.interval_days, r3.interval_days ]
    assert_equal today + 16, r3.due_on

    lapse = Sm2.review(ease: r3.ease, interval_days: 16, repetitions: 3, grade: 1, today:)
    assert_equal [ 1, 0 ], [ lapse.interval_days, lapse.repetitions ]
    assert_operator lapse.ease, :<, r3.ease
  end

  test "ease never drops below 1.3" do
    ease = 2.5
    10.times { ease = Sm2.review(ease:, interval_days: 1, repetitions: 0, grade: 0).ease }
    assert_equal 1.3, ease
  end

  test "reviewing records history and reschedules" do
    card = Flashcard.create!(front: "What is MVCC?", back: "Multi-version concurrency control")
    card.review!(4)
    assert_equal [ 1, 1 ], [ card.reload.interval_days, card.reviews.count ]
    assert_equal Date.current + 1, card.due_on
  end

  test "Question :: Answer lines in a note become cards and stay in sync" do
    note = notes(:planner)
    doc = ->(*lines) { { "type" => "doc", "content" => lines.map { |l| { "type" => "paragraph", "content" => [ { "type" => "text", "text" => l } ] } } } }

    note.update!(content: doc.("What does EXPLAIN show? :: The query plan", "Just prose here", "Seq scan cost? :: Reads every row"))
    assert_equal [ "Seq scan cost?", "What does EXPLAIN show?" ], note.flashcards.order(:front).pluck(:front)

    card = note.flashcards.find_by(front: "What does EXPLAIN show?")
    card.review!(5)
    note.update!(content: doc.("What does EXPLAIN show? :: The plan, with costs"))
    assert_equal [ "The plan, with costs", 1 ], [ card.reload.back, card.repetitions ] # history kept
    assert_equal 1, note.flashcards.count
  end
end
