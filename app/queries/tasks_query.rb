# Builds the task list for one view of GET /api/v1/tasks (docs/phase-1-tasks.md §5.2).
# Every view starts from kept, non-cancelled tasks; dates are in the user's zone (Time.zone).
class TasksQuery
  VIEWS = %w[today upcoming inbox project completed search].freeze
  PAGE_SIZE = 50
  MAX_PAGE_SIZE = 100
  SEARCH_LIMIT = 20

  Result = Data.define(:tasks, :next_cursor)

  def initialize(params)
    @params = params
    @view = params[:view].to_s
    raise Api::V1::BaseController::InvalidParameter, "view must be one of: #{VIEWS.join(", ")}" unless VIEWS.include?(@view)
  end

  def call
    scope = send(:"view_#{@view}")
    scope = scope.where(id: Tagging.where(taggable_type: "Task").joins(:tag).where(tags: { name: @params[:tag] }).select(:taggable_id)) if @params[:tag].present?
    return paginate(scope) if @view == "completed"

    Result.new(tasks: scope.to_a, next_cursor: nil)
  end

  private
    def base = Task.kept.where.not(status: "cancelled").includes(:tags)
    def today = Date.current # in Time.zone, i.e. the user's zone
    def include_done? = ActiveModel::Type::Boolean.new.cast(@params[:include_done])

    # Open tasks due today or earlier, plus what was finished today (shown struck through).
    def view_today
      finished_today = Task.done.where(completed_at: today.all_day)
      base.top_level.open.where(due_date: ..today).or(base.top_level.merge(finished_today))
        .order(Arel.sql("status = 'done'"), :due_date, Arel.sql("due_at ASC NULLS LAST"), priority: :desc)
        .order(:position, :id)
    end

    def view_upcoming
      base.top_level.open.where(due_date: today..(today + 6))
        .order(:due_date, Arel.sql("due_at ASC NULLS LAST"), priority: :desc).order(:position, :id)
    end

    def view_inbox
      scope = base.top_level.where(project_id: nil)
      (include_done? ? scope.where(status: Task::OPEN_STATUSES + %w[done]) : scope.open).order(:position, :id)
    end

    def view_project
      raise Api::V1::BaseController::InvalidParameter, "project_id is required" if @params[:project_id].blank?

      project = Project.find(@params[:project_id])
      scope = base.top_level.where(project:)
      (include_done? ? scope.where(status: Task::OPEN_STATUSES + %w[done]) : scope.open)
        .order(Arel.sql("section_id ASC NULLS FIRST"), :position, :id)
    end

    def view_completed
      base.top_level.done.order(completed_at: :desc, id: :desc)
    end

    # Prefix search, so typing "post" in ⌘K already finds "Postgres". Subtasks included.
    def view_search
      words = @params[:q].to_s.scan(/[[:alnum:]]+/).first(8)
      raise Api::V1::BaseController::InvalidParameter, "q is required" if words.empty?

      tsquery = words.map { |w| "#{w}:*" }.join(" & ")
      base.where(status: Task::OPEN_STATUSES + %w[done])
        .where("search_vector @@ to_tsquery('simple', ?)", tsquery)
        .order(Arel.sql(Task.sanitize_sql_array([ "ts_rank(search_vector, to_tsquery('simple', ?)) DESC", tsquery ])))
        .order(:id).limit(SEARCH_LIMIT)
    end

    # Keyset pagination: "rows after (completed_at, id)" stays fast at any depth, unlike OFFSET.
    def paginate(scope)
      limit = (@params[:limit].presence || PAGE_SIZE).to_i.clamp(1, MAX_PAGE_SIZE)
      if (cursor = decode_cursor)
        scope = scope.where("(tasks.completed_at, tasks.id) < (?, ?)", *cursor)
      end

      rows = scope.limit(limit + 1).to_a
      next_cursor = (encode_cursor(rows[limit - 1]) if rows.size > limit)
      Result.new(tasks: rows.first(limit), next_cursor:)
    end

    def encode_cursor(task) = Base64.urlsafe_encode64("#{task.completed_at.utc.iso8601(6)}|#{task.id}", padding: false)

    def decode_cursor
      return if @params[:cursor].blank?

      time, id = Base64.urlsafe_decode64(@params[:cursor]).split("|", 2)
      [ Time.iso8601(time), Integer(id) ]
    rescue ArgumentError
      raise Api::V1::BaseController::InvalidParameter, "cursor is invalid"
    end
end
