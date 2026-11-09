module Api
  module V1
    # A tracker's check-ins, addressed by date: PUT is an idempotent upsert for that day.
    class TrackerEntriesController < BaseController
      MAX_RANGE = 400.days

      before_action :set_tracker

      # GET /trackers/:tracker_id/entries?from=2026-01-01&to=2026-12-31 (default: the last year)
      def index
        to = date_param(:to) || Date.current
        from = date_param(:from) || (to - 364)
        raise InvalidParameter, "from must be before to, at most 400 days apart" if from > to || (to - from) > MAX_RANGE.in_days

        entries = @tracker.entries.where(logged_on: from..to).order(:logged_on)
        render json: { from:, to:, entries: TrackerEntryResource.new(entries).to_h }
      end

      # PUT /trackers/:tracker_id/entries/:date { entry: { value, note } }
      def update
        entry = @tracker.entries.find_or_initialize_by(logged_on: date_param(:date) || raise(InvalidParameter, "date is invalid"))
        entry.assign_attributes(params.require(:entry).permit(:value, :note))
        entry.save ? render(json: TrackerEntryResource.new(entry).to_h) : render_validation_errors(entry)
      rescue ActiveRecord::RecordNotUnique
        retry # two check-ins for the same day raced; the second becomes an update
      end

      # DELETE /trackers/:tracker_id/entries/:date — clears that day.
      def destroy
        @tracker.entries.where(logged_on: date_param(:date) || raise(InvalidParameter, "date is invalid")).delete_all
        head :no_content
      end

      private
        def set_tracker
          @tracker = Tracker.find(params[:tracker_id])
        end

        def date_param(key)
          Date.iso8601(params[key]) if params[key].present?
        rescue Date::Error
          raise InvalidParameter, "#{key} must be a date (YYYY-MM-DD)"
        end
    end
  end
end
