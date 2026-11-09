module Api
  module V1
    module Journal
      # Opaque ciphertext in, opaque ciphertext out. Never decrypt, never log (filter_parameters).
      class EntriesController < BaseController
        MAX_RANGE_DAYS = 400

        # GET /journal/entries?from=YYYY-MM-DD&to=YYYY-MM-DD (default: the last 90 days)
        def index
          to = date_param(:to) || Date.current
          from = date_param(:from) || (to - 89)
          raise InvalidParameter, "from must be before to, at most #{MAX_RANGE_DAYS} days apart" if from > to || (to - from) > MAX_RANGE_DAYS

          entries = JournalEntry.where(entry_date: from..to).order(entry_date: :desc, created_at: :desc)
          render json: { from:, to:, entries: entries.map { |e| serialize(e) } }
        end

        # GET /journal/entries/dates — every entry date, for the calendar and streak, no ciphertext.
        def dates
          counts = JournalEntry.group(:entry_date).order(:entry_date).count
          render json: {
            dates: counts.map { |date, count| { entry_date: date, count: } },
            total: counts.values.sum,
            streak: JournalEntry.writing_streak
          }
        end

        def show
          render json: serialize(JournalEntry.find(params[:id]))
        end

        def create
          entry = JournalEntry.new(id: params.require(:entry)[:id], **entry_attributes)
          entry.save ? render(json: serialize(entry), status: :created) : render_validation_errors(entry)
        rescue ActiveRecord::RecordNotUnique
          render_error :conflict, "entry_exists", "An entry with this id already exists."
        end

        # PUT /journal/entries/:id { entry: { ciphertext, iv, version, entry_date? } }
        # `version` is the one the client last saw. The update only applies if it still matches
        # (compare-and-swap in a single UPDATE), so two tabs can't silently overwrite each other.
        def update
          expected = Integer(params.require(:entry).require(:version), exception: false) || raise(InvalidParameter, "version must be a number")
          attrs = entry_attributes(require_date: false)
          probe = JournalEntry.new(id: params[:id], entry_date: attrs[:entry_date] || Date.current, **attrs.except(:entry_date))
          return render_validation_errors(probe) unless probe.valid?

          # Hash form, so each value is bound with its column type (bytea for the ciphertext).
          updated = JournalEntry.where(id: params[:id], version: expected)
            .update_all(attrs.merge(version: Arel.sql("version + 1"), updated_at: Time.current))
          return render(json: serialize(JournalEntry.find(params[:id]))) if updated == 1

          JournalEntry.find(params[:id]) # 404 if it's gone
          render_error :conflict, "stale_entry", "This entry was changed in another tab or window."
        end

        def destroy
          JournalEntry.where(id: params[:id]).delete_all
          head :no_content
        end

        private
          def entry_attributes(require_date: true)
            input = params.require(:entry)
            attrs = { ciphertext: decode64(input.require(:ciphertext), "ciphertext"), iv: decode64(input.require(:iv), "iv") }
            date = require_date ? input.require(:entry_date) : input[:entry_date]
            attrs[:entry_date] = parse_date(date, "entry_date") if date.present?
            attrs
          end

          def date_param(key) = (parse_date(params[key], key) if params[key].present?)

          def parse_date(value, name)
            Date.iso8601(value.to_s)
          rescue Date::Error
            raise InvalidParameter, "#{name} must be a date (YYYY-MM-DD)"
          end

          def serialize(entry)
            { id: entry.id, entry_date: entry.entry_date, version: entry.version,
              ciphertext: encode64(entry.ciphertext), iv: encode64(entry.iv),
              created_at: entry.created_at, updated_at: entry.updated_at }
          end
      end
    end
  end
end
