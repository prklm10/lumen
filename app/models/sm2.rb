# The SM-2 spaced-repetition algorithm (SuperMemo 2, Wozniak 1990), used for flashcards (LRN-11).
#
# Grade 0–5 for how well you remembered. Below 3 the card starts over tomorrow; otherwise the
# gap grows: 1 day, 6 days, then the previous gap × the card's "ease". Ease drifts down on hard
# recalls and up on easy ones, never below 1.3.
module Sm2
  Result = Data.define(:ease, :interval_days, :repetitions, :due_on)
  MIN_EASE = 1.3

  def self.review(ease:, interval_days:, repetitions:, grade:, today: Date.current)
    raise ArgumentError, "grade must be 0–5" unless (0..5).cover?(grade)

    ease = [ ease + (0.1 - (5 - grade) * (0.08 + (5 - grade) * 0.02)), MIN_EASE ].max.round(2)
    if grade < 3
      repetitions = 0
      interval_days = 1
    else
      interval_days = case repetitions
      when 0 then 1
      when 1 then 6
      else (interval_days * ease).round
      end
      repetitions += 1
    end
    Result.new(ease:, interval_days:, repetitions:, due_on: today + interval_days)
  end
end
