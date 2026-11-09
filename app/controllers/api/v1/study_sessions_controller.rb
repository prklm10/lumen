module Api
  module V1
    class StudySessionsController < BaseController
      # GET /study_sessions?days=30 — recent sessions plus minutes per topic for that window.
      def index
        days = params.fetch(:days, 30).to_i.clamp(1, 366)
        sessions = StudySession.where(studied_on: (Date.current - (days - 1))..).order(studied_on: :desc, created_at: :desc)
        by_topic = sessions.unscope(:order).group(:topic_id).sum(:duration_minutes).map { |topic_id, minutes| { topic_id:, minutes: } }
        render json: { sessions: StudySessionResource.new(sessions.limit(100)).to_h, by_topic:, total_minutes: by_topic.sum { |t| t[:minutes] } }
      end

      def create
        session = StudySession.new(params.require(:study_session).permit(:topic_id, :resource_id, :studied_on, :duration_minutes, :notes))
        session.studied_on ||= Date.current
        session.save ? render(json: StudySessionResource.new(session).to_h, status: :created) : render_validation_errors(session)
      end

      def destroy
        StudySession.find(params[:id]).destroy!
        head :no_content
      end
    end
  end
end
