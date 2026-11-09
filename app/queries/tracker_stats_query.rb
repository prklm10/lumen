# Streaks and completion rates for trackers (TRK-4), computed in one SQL query with the
# "gaps and islands" technique:
#
#   1. periods — every period a tracker expects a check-in, from its first day to today:
#                each day (daily), each scheduled weekday (weekdays), or each ISO week (weekly).
#   2. flagged — whether each period was met (enough check-ins that hit the target).
#   3. islands — consecutive met periods share the same value of
#                  row_number() over all periods − row_number() over met periods
#                because both counters advance together inside a run and drift apart at a gap.
#   4. the longest island is the longest streak; the island ending at the latest period
#      (or the one before, if today's period isn't met *yet*) is the current streak.
class TrackerStatsQuery
  Stats = Data.define(:current_streak, :longest_streak, :completion_rate, :periods_met, :periods_total) do
    def self.empty = new(current_streak: 0, longest_streak: 0, completion_rate: nil, periods_met: 0, periods_total: 0)
  end

  WINDOW_DAYS = 30

  def initialize(trackers, today: Date.current, time_zone: Time.zone.tzinfo.name, window_days: WINDOW_DAYS)
    @trackers = Array(trackers)
    @today = today
    @time_zone = time_zone
    @window_days = window_days
  end

  # { tracker_id => Stats }
  def call
    return {} if @trackers.empty?

    rows = Tracker.connection.select_all(Tracker.sanitize_sql_array([ SQL, {
      ids: @trackers.map(&:id), today: @today, window_start: @today - (@window_days - 1), tz: @time_zone
    } ]))
    stats = rows.to_h do |row|
      total = row["window_total"].to_i
      met = row["window_met"].to_i
      [ row["tracker_id"], Stats.new(
        current_streak: row["current_streak"].to_i,
        longest_streak: row["longest_streak"].to_i,
        completion_rate: total.zero? ? nil : (met.to_f / total).round(3),
        periods_met: met,
        periods_total: total
      ) ]
    end
    @trackers.to_h { |t| [ t.id, stats.fetch(t.id, Stats.empty) ] }
  end

  SQL = <<~SQL
    WITH t AS (
      SELECT tr.id, tr.kind, tr.target, tr.frequency,
             least((tr.created_at AT TIME ZONE :tz)::date,
                   coalesce((SELECT min(logged_on) FROM tracker_entries e WHERE e.tracker_id = tr.id), :today)) AS start_on
      FROM trackers tr
      WHERE tr.id IN (:ids)
    ),
    periods AS (
      SELECT t.id AS tracker_id, d::date AS period_start, d::date AS period_end
      FROM t, generate_series(t.start_on, :today::date, interval '1 day') AS d
      WHERE t.frequency->>'type' = 'daily'
         OR (t.frequency->>'type' = 'weekdays'
             AND t.frequency->'days' @> to_jsonb(extract(isodow FROM d)::int))
      UNION ALL
      SELECT t.id, w::date, (w + interval '6 days')::date
      FROM t, generate_series(date_trunc('week', t.start_on), :today::date, interval '1 week') AS w
      WHERE t.frequency->>'type' = 'weekly'
    ),
    flagged AS (
      SELECT p.tracker_id, p.period_start, p.period_end,
             count(e.id) FILTER (
               WHERE CASE WHEN t.kind = 'boolean' THEN e.value >= 1
                          WHEN t.target IS NULL THEN true
                          ELSE e.value >= t.target END
             ) >= CASE WHEN t.frequency->>'type' = 'weekly' THEN (t.frequency->>'times')::int ELSE 1 END AS met,
             :today::date BETWEEN p.period_start AND p.period_end AS is_current
      FROM periods p
      JOIN t ON t.id = p.tracker_id
      LEFT JOIN tracker_entries e ON e.tracker_id = p.tracker_id AND e.logged_on BETWEEN p.period_start AND p.period_end
      GROUP BY p.tracker_id, p.period_start, p.period_end, t.kind, t.target, t.frequency
    ),
    numbered AS (
      SELECT f.*,
             row_number() OVER (PARTITION BY tracker_id ORDER BY period_start) AS rn,
             count(*) OVER (PARTITION BY tracker_id) AS total,
             bool_or(is_current AND met) OVER (PARTITION BY tracker_id) AS current_met
      FROM flagged f
    ),
    islands AS (
      SELECT tracker_id, count(*) AS length, max(rn) AS last_rn, max(total) AS total, bool_or(current_met) AS current_met
      FROM (
        SELECT n.*, rn - row_number() OVER (PARTITION BY tracker_id ORDER BY period_start) AS island
        FROM numbered n
        WHERE met
      ) runs
      GROUP BY tracker_id, island
    ),
    streaks AS (
      SELECT tracker_id,
             max(length) AS longest_streak,
             max(length) FILTER (WHERE last_rn = total OR (last_rn = total - 1 AND NOT current_met)) AS current_streak
      FROM islands
      GROUP BY tracker_id
    ),
    recent AS (
      -- The current period only counts once it's met: an unfinished today isn't a miss.
      SELECT tracker_id,
             count(*) FILTER (WHERE met) AS window_met,
             count(*) FILTER (WHERE met OR NOT is_current) AS window_total
      FROM flagged
      WHERE period_end >= :window_start
      GROUP BY tracker_id
    )
    SELECT t.id AS tracker_id,
           coalesce(s.current_streak, 0) AS current_streak,
           coalesce(s.longest_streak, 0) AS longest_streak,
           coalesce(r.window_met, 0) AS window_met,
           coalesce(r.window_total, 0) AS window_total
    FROM t
    LEFT JOIN streaks s ON s.tracker_id = t.id
    LEFT JOIN recent r ON r.tracker_id = t.id
  SQL
end
