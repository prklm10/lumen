module Analytics
  # Knowledge growth (PRD §4.8 Learning) and journal consistency. The journal part only uses
  # entry dates: its contents are encrypted and the server can't read them.
  class Learning < Base
    def self.for(range) = cached(range, Note, NoteLink, JournalEntry)

    def call
      { range: @range.to_h, totals:, series: }
    end

    private
      def totals
        {
          notes: Note.kept.count,
          links: NoteLink.joins(:source_note).merge(Note.kept).where.not(target_note_id: nil).count,
          tags: Tag.joins(:taggings).where(taggings: { taggable_type: "Note" }).distinct.count,
          notes_created: Note.kept.where(created_at: @range.from_time..@range.to_time).count,
          journal_entries: JournalEntry.where(entry_date: @range.from..@range.to).count,
          journal_days: JournalEntry.where(entry_date: @range.from..@range.to).distinct.count(:entry_date),
          journal_streak: JournalEntry.writing_streak
        }
      end

      def series
        select_all(<<~SQL).map { |r| r.transform_keys(&:to_sym).merge(date: r["bucket"]).except(:bucket) }
          WITH buckets AS (#{buckets_sql}),
          created AS (
            SELECT #{bucket_of(local_date("created_at"))} AS bucket, count(*) AS n
            FROM notes WHERE discarded_at IS NULL AND created_at BETWEEN :from_ts AND :to_ts GROUP BY 1
          ),
          edited AS (
            SELECT #{bucket_of(local_date("updated_at"))} AS bucket, count(*) AS n
            FROM notes WHERE discarded_at IS NULL AND updated_at BETWEEN :from_ts AND :to_ts GROUP BY 1
          ),
          journal AS (
            SELECT #{bucket_of("entry_date")} AS bucket, count(DISTINCT entry_date) AS n
            FROM journal_entries WHERE entry_date BETWEEN :from AND :to GROUP BY 1
          )
          SELECT b.bucket, coalesce(c.n, 0) AS notes_created, coalesce(e.n, 0) AS notes_edited, coalesce(j.n, 0) AS journal_days
          FROM buckets b
          LEFT JOIN created c USING (bucket)
          LEFT JOIN edited e USING (bucket)
          LEFT JOIN journal j USING (bucket)
          ORDER BY b.bucket
        SQL
      end
  end
end
