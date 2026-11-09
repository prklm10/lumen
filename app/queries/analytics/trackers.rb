module Analytics
  # Habit analytics (PRD §4.8): consistency over the window, streaks, which weekdays slip,
  # and — for numbers — the daily values with a 7-day moving average (a window function).
  class Trackers < Base
    def self.for(range) = cached(range, Tracker, TrackerEntry)

    def call
      trackers = Tracker.active.ordered.to_a
      stats = TrackerStatsQuery.new(trackers, window_days: @range.days).call
      weekdays = weekday_rates(trackers)
      values = value_series(trackers.reject(&:kind_boolean?))

      { range: @range.to_h, trackers: trackers.map { |t|
        s = stats.fetch(t.id)
        {
          id: t.id, name: t.name, icon: t.icon, color: t.color, kind: t.kind, unit: t.unit, target: t.target&.to_f,
          frequency: t.frequency, consistency: s.completion_rate, periods_met: s.periods_met, periods_total: s.periods_total,
          current_streak: s.current_streak, longest_streak: s.longest_streak,
          weekdays: (1..7).map { |d| weekdays.dig(t.id, d) },
          values: values[t.id]
        }
      } }
    end

    private
      # Share of scheduled days met, per ISO weekday, within the window (daily / weekday trackers).
      def weekday_rates(trackers)
        ids = trackers.reject { |t| t.frequency_type == "weekly" }.map(&:id)
        return {} if ids.empty?

        rows = select_all(<<~SQL, ids:)
          WITH t AS (
            SELECT id, kind, target, frequency,
                   greatest(:from::date, least((created_at AT TIME ZONE :tz)::date,
                     coalesce((SELECT min(logged_on) FROM tracker_entries e WHERE e.tracker_id = trackers.id), :to::date))) AS start_on
            FROM trackers WHERE id IN (:ids)
          ),
          days AS (
            SELECT t.id AS tracker_id, d::date AS day
            FROM t, generate_series(t.start_on, :to::date, interval '1 day') AS d
            WHERE t.frequency->>'type' = 'daily' OR t.frequency->'days' @> to_jsonb(extract(isodow FROM d)::int)
          )
          SELECT days.tracker_id, extract(isodow FROM days.day)::int AS dow,
                 count(*) AS scheduled,
                 count(e.id) FILTER (WHERE CASE WHEN t.kind = 'boolean' THEN e.value >= 1
                                                WHEN t.target IS NULL THEN true
                                                ELSE e.value >= t.target END) AS met
          FROM days
          JOIN t ON t.id = days.tracker_id
          LEFT JOIN tracker_entries e ON e.tracker_id = days.tracker_id AND e.logged_on = days.day
          WHERE days.day < :to::date OR e.id IS NOT NULL   -- an unlogged today isn't a miss yet
          GROUP BY 1, 2
        SQL
        rows.each_with_object(Hash.new { |h, k| h[k] = {} }) { |r, out| out[r["tracker_id"]][r["dow"]] = rate(r["met"], r["scheduled"]) }
      end

      # Every day in the window with its value (or null) and the trailing 7-day average.
      # AVG ignores nulls, so missing days don't drag the average to zero.
      def value_series(trackers)
        return {} if trackers.empty?

        rows = select_all(<<~SQL, ids: trackers.map(&:id))
          SELECT t.id AS tracker_id, d::date AS day, e.value,
                 avg(e.value) OVER (PARTITION BY t.id ORDER BY d ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS avg7
          FROM trackers t
          CROSS JOIN generate_series(:from::date - 6, :to::date, interval '1 day') AS d
          LEFT JOIN tracker_entries e ON e.tracker_id = t.id AND e.logged_on = d::date
          WHERE t.id IN (:ids)
          ORDER BY t.id, d
        SQL
        rows.reject { |r| r["day"] < @range.from }.group_by { |r| r["tracker_id"] }.transform_values do |list|
          list.map { |r| { date: r["day"], value: r["value"]&.to_f, avg7: r["avg7"]&.to_f&.round(2) } }
        end
      end
  end
end
