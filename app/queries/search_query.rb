# GET /api/v1/search?q= — one search box over notes and tasks (LRN-7). The journal is never
# searched: its contents only exist encrypted.
#
# Notes combine two Postgres techniques:
#   full-text search  — stemmed words ("indexing" finds "indexes"), ranked by ts_rank with
#                       the title weighted above the body (setweight A/B in the column)
#   trigram matching  — typo tolerance on titles ("postgress" → "Postgres"), via pg_trgm
class SearchQuery
  LIMIT = 12
  # ts_headline wraps matches in these; the UI turns them into <mark> without parsing HTML.
  MARK_START = "\u0002"
  MARK_STOP = "\u0003"

  def initialize(q)
    @q = q.to_s.strip.first(200)
    @words = @q.scan(/[[:alnum:]]+/).first(8)
  end

  def call
    return { notes: [], tasks: [] } if @words.empty?
    { notes:, tasks: }
  end

  private
    # Prefix match on every word, so results appear while typing ("postg" → "postgres").
    def tsquery = @words.map { |w| "#{w}:*" }.join(" & ")

    def notes
      sql = <<~SQL
        SELECT notes.id, notes.title, notes.icon, notes.folder_id, notes.updated_at,
               ts_headline('english', notes.content_text, query,
                 'MaxFragments=1, MaxWords=24, MinWords=10, StartSel=#{MARK_START}, StopSel=#{MARK_STOP}') AS snippet,
               ts_rank(notes.search_vector, query) + similarity(notes.title, :raw) AS rank
        FROM notes, to_tsquery('english', :tsquery) AS query
        WHERE notes.discarded_at IS NULL
          AND (notes.search_vector @@ query OR notes.title % :raw)
        ORDER BY rank DESC, notes.updated_at DESC
        LIMIT #{LIMIT}
      SQL
      Note.find_by_sql([ sql, { tsquery:, raw: @q } ]).map do |note|
        { id: note.id, title: note.title, icon: note.icon, folder_id: note.folder_id, snippet: note.snippet, updated_at: note.updated_at }
      end
    rescue ActiveRecord::StatementInvalid
      [] # a query made only of stop words ("the") can't be parsed by to_tsquery
    end

    def tasks
      TasksQuery.new(ActionController::Parameters.new(view: "search", q: @q)).call.tasks.first(LIMIT).map do |task|
        task.slice(:id, :title, :status, :project_id, :due_date)
      end
    rescue Api::V1::BaseController::InvalidParameter
      []
    end
end
