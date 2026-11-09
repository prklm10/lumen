module Api
  module V1
    # GLB-5: deleted tasks and notes stay restorable for 30 days, then TrashPurgeJob removes them.
    class TrashController < BaseController
      TYPES = { "task" => Task, "note" => Note }.freeze

      def index
        tasks = Task.where.not(discarded_at: nil).where(parent_id: nil).or(
          Task.where.not(discarded_at: nil).where(parent_id: Task.kept.select(:id))
        ).order(discarded_at: :desc).limit(200)
        notes = Note.where.not(discarded_at: nil).select(:id, :title, :icon, :discarded_at).order(discarded_at: :desc).limit(200)
        items = tasks.map { |t| { type: "task", id: t.id, title: t.title, discarded_at: t.discarded_at } } +
                notes.map { |n| { type: "note", id: n.id, title: n.title, icon: n.icon, discarded_at: n.discarded_at } }
        render json: { items: items.sort_by { |i| i[:discarded_at] }.reverse, retention_days: TrashPurgeJob::RETENTION.in_days.to_i }
      end

      def restore
        record.restore!
        head :no_content
      end

      def destroy
        record.destroy!
        head :no_content
      end

      def empty
        TrashPurgeJob.perform_now(older_than: Time.current)
        head :no_content
      end

      private
        def record
          model = TYPES.fetch(params[:type]) { raise InvalidParameter, "type must be task or note" }
          model.where.not(discarded_at: nil).find(params[:id])
        end
    end
  end
end
