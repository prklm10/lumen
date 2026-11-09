module Api
  module V1
    # GET /api/v1/analytics/{tasks,trackers,learning}?range=7d|30d|90d|1y
    class AnalyticsController < BaseController
      def tasks = render(json: Analytics::Tasks.for(range))
      def trackers = render(json: Analytics::Trackers.for(range))
      def learning = render(json: Analytics::Learning.for(range))

      private
        def range = Analytics::Range.new(params[:range])
    end
  end
end
