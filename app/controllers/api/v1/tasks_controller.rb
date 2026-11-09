module Api
  module V1
    class TasksController < BaseController
      MAX_REORDER_MOVES = 200

      before_action :set_task, only: %i[show update destroy complete reopen]

      def index
        result = TasksQuery.new(params).call
        render json: { tasks: serialize(result.tasks), next_cursor: result.next_cursor }
      end

      def show
        render json: serialize(@task, with_subtasks: true)
      end

      def create
        task = Task.new(task_params.except(:tag_names))
        save_with_tags(task) ? render(json: serialize(task), status: :created) : render_validation_errors(task)
      end

      def update
        @task.assign_attributes(task_params.except(:tag_names))
        save_with_tags(@task) ? render(json: serialize(@task)) : render_validation_errors(@task)
      end

      def destroy
        @task.discard!
        head :no_content
      end

      def complete
        @task.complete!
        render json: serialize(@task)
      end

      def reopen
        @task.reopen!
        render json: serialize(@task)
      end

      # PATCH /tasks/reorder { moves: [{ id, position, section_id? }] } — all or nothing.
      def reorder
        moves = params.require(:moves)
        raise InvalidParameter, "moves must be a list of at most #{MAX_REORDER_MOVES}" unless moves.is_a?(Array) && moves.size <= MAX_REORDER_MOVES

        tasks = Task.transaction do
          moves.map do |move|
            move = move.permit(:id, :position, :section_id)
            task = Task.kept.find(move[:id])
            task.position = move.require(:position)
            task.section_id = move[:section_id] if move.key?(:section_id)
            task.tap(&:save!)
          end
        end
        render json: { tasks: tasks.map { |t| { id: t.id, position: t.position.to_f, section_id: t.section_id } } }
      end

      # Sidebar badges: open, top-level tasks only, same rules as the views.
      def counts
        today = Date.current
        open = Task.kept.top_level.open
        inbox, due_today, overdue, upcoming = open.pick(
          Arel.sql("count(*) FILTER (WHERE project_id IS NULL)"),
          Arel.sql(Task.sanitize_sql_array([ "count(*) FILTER (WHERE due_date <= ?)", today ])),
          Arel.sql(Task.sanitize_sql_array([ "count(*) FILTER (WHERE due_date < ? OR due_at < ?)", today, Time.current ])),
          Arel.sql(Task.sanitize_sql_array([ "count(*) FILTER (WHERE due_date BETWEEN ? AND ?)", today, today + 6 ]))
        )
        projects = open.where.not(project_id: nil).group(:project_id).count
        render json: { inbox:, today: due_today, overdue:, upcoming:, projects: }
      end

      private
        def set_task
          @task = Task.kept.find(params[:id])
        end

        def task_params
          @task_params ||= params.require(:task).except(:description)
            .permit(:title, :status, :priority, :due_date, :due_at, :estimate_minutes, :project_id, :section_id, :parent_id, :recurrence_rule, tag_names: [])
            .to_h.tap { |p| p[:description] = description_param if params[:task].key?(:description) }
        end

        # A TipTap/ProseMirror document: arbitrarily nested JSON that strong params can't describe
        # field by field, so it's accepted as a whole — but only as an object (or null).
        def description_param
          value = params[:task][:description]
          return if value.nil?
          raise InvalidParameter, "description must be a JSON object" unless value.is_a?(ActionController::Parameters)

          value.to_unsafe_h
        end

        # Assigning tags to a saved task writes taggings immediately, so the save and the tag
        # change share a transaction: a validation failure leaves both untouched.
        def save_with_tags(task)
          Task.transaction do
            task.tag_names = params[:task][:tag_names] if params[:task].key?(:tag_names)
            task.save || raise(ActiveRecord::Rollback)
          end
          task.persisted? && task.errors.empty?
        end

        def serialize(tasks, with_subtasks: false)
          subtask_counts = Task.subtask_counts_for(Array(tasks))
          TaskResource.new(tasks, params: { subtask_counts:, with_subtasks: }).to_h
        end
    end
  end
end
