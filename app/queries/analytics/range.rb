module Analytics
  # A reporting window ending today (in the user's zone): 7d, 30d, 90d or 1y.
  # Up to 90 days is bucketed by day; a year by ISO week (Monday).
  class Range
    PRESETS = { "7d" => 7, "30d" => 30, "90d" => 90, "1y" => 365 }.freeze

    attr_reader :key, :from, :to

    def initialize(key, today: Date.current)
      @key = PRESETS.key?(key) ? key : "30d"
      @to = today
      @from = today - (PRESETS.fetch(@key) - 1)
    end

    def days = (to - from).to_i + 1
    def unit = days > 90 ? "week" : "day"
    def previous = self.class.allocate.tap { |r| r.instance_variable_set(:@key, key); r.instance_variable_set(:@to, from - 1); r.instance_variable_set(:@from, from - days) }

    # Start of the window as a time in the user's zone, for comparing with timestamptz columns.
    def from_time = from.in_time_zone.beginning_of_day
    def to_time = to.in_time_zone.end_of_day

    def to_h = { key:, from:, to:, days:, unit: }
  end
end
