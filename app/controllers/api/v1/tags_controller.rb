module Api
  module V1
    class TagsController < BaseController
      before_action :set_tag, only: %i[update destroy]

      def index
        tags = Tag.order(:name).to_a
        task_counts = Tagging.where(tag_id: tags.map(&:id), taggable_type: "Task", taggable_id: Task.kept.select(:id))
          .group(:tag_id).count
        render json: { tags: tags.map { |tag| TagResource.new(tag).to_h.merge(task_count: task_counts.fetch(tag.id, 0)) } }
      end

      def update
        @tag.update(params.require(:tag).permit(:name, :color)) ? render(json: TagResource.new(@tag).to_h) : render_validation_errors(@tag)
      end

      def destroy
        @tag.destroy!
        head :no_content
      end

      private
        def set_tag
          @tag = Tag.find(params[:id])
        end
    end
  end
end
