# A task's repeat rule — a small, validated subset of RFC 5545 RRULE:
#   FREQ=DAILY|WEEKLY|MONTHLY|YEARLY ; INTERVAL=n ; BYDAY=MO,TU,… (weekly only)
# "every weekday" is FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR.
class Recurrence
  FREQUENCIES = %w[DAILY WEEKLY MONTHLY YEARLY].freeze
  DAYS = %w[MO TU WE TH FR SA SU].freeze # index + 1 = ISO weekday

  class Invalid < ArgumentError; end

  attr_reader :freq, :interval, :by_day

  def self.parse(rule)
    parts = rule.to_s.split(";").to_h { |part| part.split("=", 2) }
    new(freq: parts["FREQ"], interval: parts.fetch("INTERVAL", "1"), by_day: parts["BYDAY"].to_s.split(","))
  rescue ArgumentError, TypeError
    raise Invalid, "isn't a valid repeat rule"
  end

  def initialize(freq:, interval:, by_day:)
    @freq = freq
    @interval = Integer(interval)
    @by_day = by_day.map { |d| DAYS.index(d)&.+(1) || raise(Invalid, "has an unknown weekday #{d}") }.uniq.sort
    raise Invalid, "must repeat daily, weekly, monthly or yearly" unless FREQUENCIES.include?(freq)
    raise Invalid, "interval must be 1–365" unless @interval.between?(1, 365)
    raise Invalid, "weekdays only apply to weekly rules" if @by_day.any? && freq != "WEEKLY"
  end

  def to_s
    [ "FREQ=#{freq}", "INTERVAL=#{interval}", ("BYDAY=#{by_day.map { |d| DAYS[d - 1] }.join(",")}" if by_day.any?) ].compact.join(";")
  end

  # The first occurrence strictly after `date`.
  def next_after(date)
    case freq
    when "DAILY" then date + interval
    when "MONTHLY" then date >> interval
    when "YEARLY" then date >> (12 * interval)
    when "WEEKLY"
      return date + (7 * interval) if by_day.empty?

      later_this_week = by_day.find { |d| d > date.cwday }
      return date + (later_this_week - date.cwday) if later_this_week
      # Jump to the first listed day of the week `interval` weeks on.
      date.beginning_of_week + (7 * interval) + (by_day.first - 1)
    end
  end

  # The next occurrence after `due` that isn't in the past: completing a long-overdue daily task
  # schedules it for tomorrow, not for a day that has already gone by.
  def next_occurrence(due, today: Date.current)
    date = next_after(due || today)
    date = next_after(date) while date <= today
    date
  end
end
