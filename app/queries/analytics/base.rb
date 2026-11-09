module Analytics
  # Shared plumbing: binds, the user's zone for date bucketing, and caching.
  class Base
    def initialize(range)
      @range = range
      @tz = Time.zone.tzinfo.name
    end

    # Cached in Solid Cache. The key includes each source table's last change and row count,
    # so any write (or delete) produces a new key — no manual busting needed.
    def self.cached(range, *sources)
      version = sources.map do |m|
        stamp = m.column_names.include?("updated_at") ? :updated_at : :created_at
        [ m.table_name, m.maximum(stamp)&.to_f, m.count ]
      end
      Rails.cache.fetch([ "analytics/v1", name, range.key, Time.zone.tzinfo.name, Date.current, version ], expires_in: 12.hours) do
        new(range).call
      end
    end

    private
      def binds(extra = {})
        { from: @range.from, to: @range.to, from_ts: @range.from_time, to_ts: @range.to_time, tz: @tz, unit: @range.unit }.merge(extra)
      end

      def select_all(sql, extra = {})
        ActiveRecord::Base.connection.select_all(ActiveRecord::Base.sanitize_sql_array([ sql, binds(extra) ])).to_a
      end

      def select_one(sql, extra = {}) = select_all(sql, extra).first || {}

      # generate_series of bucket starts covering the window (days, or Mondays for a year).
      def buckets_sql
        "SELECT generate_series(date_trunc(:unit, :from::date::timestamp), :to::date::timestamp, ('1 ' || :unit)::interval)::date AS bucket"
      end

      def local_date(column) = "((#{column}) AT TIME ZONE :tz)::date"
      def bucket_of(date_sql) = "date_trunc(:unit, (#{date_sql})::timestamp)::date"
      def rate(part, whole) = whole.to_i.zero? ? nil : (part.to_f / whole.to_i).round(3)
  end
end
