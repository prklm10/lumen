module Api
  module V1
    class WeeklyReviewsController < BaseController
      # GET /weekly_review?week=YYYY-MM-DD (any day in the week; default: this week)
      def show
        day = params[:week].present? ? Date.iso8601(params[:week]) : Date.current
        render json: WeeklyReviewQuery.new(day).call
      rescue Date::Error
        raise InvalidParameter, "week must be a date"
      end
    end
  end
end
