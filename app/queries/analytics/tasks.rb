module Analytics
  # Task analytics (PRD §4.8): throughput, completion and on-time rates, where the work went,
  # when you get things done, and how the overdue backlog moves. Cancelled and deleted tasks
  # are left out everywhere.
  class Tasks < Base
    def self.for(range) = cached(range, Task, Project)

    def call
      { range: @range.to_h, kpis:, series:, by_project:, by_priority:, hours:, backlog: }
    end

    private
      def kpis
        current = totals(@range)
        previous = totals(@range.previous)
        overdue_open = Task.kept.open.where(due_date: @range.from...@range.to).count
        current.merge(
          previous_completed: previous[:completed],
          completion_rate: rate(current[:completed], current[:completed] + overdue_open),
          overdue_open:
        )
      end

      def totals(range)
        row = ActiveRecord::Base.connection.select_one(ActiveRecord::Base.sanitize_sql_array([ <<~SQL, { from_ts: range.from_time, to_ts: range.to_time, tz: @tz } ]))
          SELECT
            count(*) FILTER (WHERE status = 'done' AND completed_at BETWEEN :from_ts AND :to_ts) AS completed,
            count(*) FILTER (WHERE created_at BETWEEN :from_ts AND :to_ts) AS created,
            count(*) FILTER (WHERE status = 'done' AND completed_at BETWEEN :from_ts AND :to_ts AND due_date IS NOT NULL) AS completed_with_due,
            count(*) FILTER (WHERE status = 'done' AND completed_at BETWEEN :from_ts AND :to_ts AND due_date IS NOT NULL
                             AND (completed_at AT TIME ZONE :tz)::date <= due_date) AS on_time,
            avg(extract(epoch FROM completed_at - created_at) / 3600.0)
              FILTER (WHERE status = 'done' AND completed_at BETWEEN :from_ts AND :to_ts) AS avg_hours
          FROM tasks
          WHERE discarded_at IS NULL AND status <> 'cancelled'
        SQL
        {
          completed: row["completed"].to_i,
          created: row["created"].to_i,
          on_time_rate: rate(row["on_time"], row["completed_with_due"]),
          avg_hours_to_complete: row["avg_hours"]&.to_f&.round(1)
        }
      end

      # Created vs completed per bucket — are you keeping up?
      def series
        select_all(<<~SQL).map { |r| { date: r["bucket"], created: r["created"], completed: r["completed"] } }
          WITH buckets AS (#{buckets_sql}),
          created AS (
            SELECT #{bucket_of(local_date("created_at"))} AS bucket, count(*) AS n
            FROM tasks WHERE discarded_at IS NULL AND status <> 'cancelled' AND created_at BETWEEN :from_ts AND :to_ts
            GROUP BY 1
          ),
          completed AS (
            SELECT #{bucket_of(local_date("completed_at"))} AS bucket, count(*) AS n
            FROM tasks WHERE discarded_at IS NULL AND status = 'done' AND completed_at BETWEEN :from_ts AND :to_ts
            GROUP BY 1
          )
          SELECT b.bucket, coalesce(c.n, 0) AS created, coalesce(d.n, 0) AS completed
          FROM buckets b
          LEFT JOIN created c USING (bucket)
          LEFT JOIN completed d USING (bucket)
          ORDER BY b.bucket
        SQL
      end

      def by_project
        select_all(<<~SQL).map { |r| { project_id: r["project_id"], name: r["name"] || "Inbox", color: r["color"], completed: r["completed"] } }
          SELECT t.project_id, p.name, p.color, count(*) AS completed
          FROM tasks t LEFT JOIN projects p ON p.id = t.project_id
          WHERE t.discarded_at IS NULL AND t.status = 'done' AND t.completed_at BETWEEN :from_ts AND :to_ts
          GROUP BY t.project_id, p.name, p.color
          ORDER BY completed DESC, p.name NULLS FIRST
          LIMIT 12
        SQL
      end

      # Average time from created to done, per priority (the enum's own order: none … urgent).
      def by_priority
        select_all(<<~SQL).map { |r| { priority: r["priority"], completed: r["completed"], avg_hours: r["avg_hours"]&.to_f&.round(1) } }
          SELECT priority::text AS priority, count(*) AS completed,
                 avg(extract(epoch FROM completed_at - created_at) / 3600.0) AS avg_hours
          FROM tasks
          WHERE discarded_at IS NULL AND status = 'done' AND completed_at BETWEEN :from_ts AND :to_ts
          GROUP BY priority
          ORDER BY tasks.priority DESC
        SQL
      end

      # Completions by ISO weekday (1 = Monday) and local hour: when do you get things done?
      def hours
        select_all(<<~SQL).map { |r| [ r["dow"], r["hour"], r["n"] ] }
          SELECT extract(isodow FROM completed_at AT TIME ZONE :tz)::int AS dow,
                 extract(hour FROM completed_at AT TIME ZONE :tz)::int AS hour,
                 count(*) AS n
          FROM tasks
          WHERE discarded_at IS NULL AND status = 'done' AND completed_at BETWEEN :from_ts AND :to_ts
          GROUP BY 1, 2
        SQL
      end

      # Open-and-overdue tasks at the end of each bucket, rebuilt from timestamps (LATERAL join).
      # Uses each task's current due date, so earlier reschedules aren't replayed.
      def backlog
        select_all(<<~SQL).map { |r| { date: r["bucket"], overdue: r["overdue"] } }
          WITH buckets AS (#{buckets_sql})
          SELECT b.bucket, o.overdue
          FROM buckets b
          CROSS JOIN LATERAL (
            SELECT count(*) AS overdue
            FROM tasks t
            WHERE t.status <> 'cancelled'
              AND t.due_date < least(b.bucket + CASE WHEN :unit = 'week' THEN 6 ELSE 0 END, :to::date)
              AND #{local_date("t.created_at")} <= least(b.bucket + CASE WHEN :unit = 'week' THEN 6 ELSE 0 END, :to::date)
              AND (t.completed_at IS NULL OR #{local_date("t.completed_at")} > least(b.bucket + CASE WHEN :unit = 'week' THEN 6 ELSE 0 END, :to::date))
              AND (t.discarded_at IS NULL OR #{local_date("t.discarded_at")} > least(b.bucket + CASE WHEN :unit = 'week' THEN 6 ELSE 0 END, :to::date))
          ) o
          ORDER BY b.bucket
        SQL
      end
  end
end
