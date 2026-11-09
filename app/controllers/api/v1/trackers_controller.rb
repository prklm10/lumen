module Api
  module V1
    class TrackersController < BaseController
      RECENT_DAYS = 14

      before_action :set_tracker, only: %i[show update destroy]

      def index
        trackers = Tracker.ordered
        trackers = trackers.active unless ActiveModel::Type::Boolean.new.cast(params[:include_archived])
        render json: { trackers: serialize(trackers.to_a) }
      end

      def show
        render json: serialize(@tracker)
      end

      def create
        tracker = Tracker.new(tracker_params)
        tracker.save ? render(json: serialize(tracker), status: :created) : render_validation_errors(tracker)
      end

      def update
        @tracker.update(tracker_params) ? render(json: serialize(@tracker)) : render_validation_errors(@tracker)
      end

      # POST /trackers/mood — the built-in Mood tracker, created on first use.
      def mood
        render json: serialize(Tracker.mood!)
      end

      # Deletes the tracker and all its history. Archive (PATCH archived: true) keeps it.
      def destroy
        @tracker.destroy!
        head :no_content
      end

      private
        def set_tracker
          @tracker = Tracker.find(params[:id])
        end

        def tracker_params
          params.require(:tracker).permit(:name, :icon, :color, :kind, :unit, :target, :position, :archived,
            frequency: [ :type, :times, { days: [] } ])
        end

        # Stats and the last two weeks of entries for every tracker: two queries in total.
        def serialize(trackers)
          list = Array(trackers)
          from = Date.current - (RECENT_DAYS - 1)
          recent = TrackerEntry.where(tracker_id: list.map(&:id), logged_on: from..).order(:logged_on).group_by(&:tracker_id)
          TrackerResource.new(trackers, params: { stats: TrackerStatsQuery.new(list).call, recent: }).to_h
        end
    end
  end
end
