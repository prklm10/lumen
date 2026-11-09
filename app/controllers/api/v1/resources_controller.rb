module Api
  module V1
    class ResourcesController < BaseController
      before_action :set_resource, only: %i[update destroy]

      def index
        resources = Resource.order(Arel.sql("CASE status WHEN 'in_progress' THEN 0 WHEN 'to_learn' THEN 1 ELSE 2 END"), updated_at: :desc)
        resources = resources.where(topic_id: params[:topic_id]) if params[:topic_id].present?
        render json: { resources: serialize(resources.to_a) }
      end

      def create
        resource = Resource.new(resource_params)
        resource.save ? render(json: serialize(resource), status: :created) : render_validation_errors(resource)
      end

      def update
        @resource.update(resource_params) ? render(json: serialize(@resource)) : render_validation_errors(@resource)
      end

      def destroy
        @resource.destroy!
        head :no_content
      end

      private
        def set_resource = @resource = Resource.find(params[:id])
        def resource_params = params.require(:resource).permit(:topic_id, :title, :url, :kind, :status, :progress, :rating, :started_on, :finished_on)

        def serialize(resources)
          minutes = StudySession.where(resource_id: Array(resources).map(&:id)).group(:resource_id).sum(:duration_minutes)
          LearningResourceResource.new(resources, params: { minutes: }).to_h
        end
    end
  end
end
