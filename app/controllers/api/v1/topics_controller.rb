module Api
  module V1
    class TopicsController < BaseController
      before_action :set_topic, only: %i[update destroy]

      def index
        render json: { topics: TopicResource.new(Topic.order(:name)).to_h }
      end

      def create
        topic = Topic.new(topic_params)
        topic.save ? render(json: TopicResource.new(topic).to_h, status: :created) : render_validation_errors(topic)
      end

      def update
        @topic.update(topic_params) ? render(json: TopicResource.new(@topic).to_h) : render_validation_errors(@topic)
      end

      # Notes, resources, sessions and cards keep existing; they just lose the topic.
      def destroy
        @topic.destroy!
        head :no_content
      end

      private
        def set_topic = @topic = Topic.find(params[:id])
        def topic_params = params.require(:topic).permit(:name, :color, :description)
    end
  end
end
