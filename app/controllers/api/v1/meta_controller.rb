module Api
  module V1
    # Values the backend owns, so the UI never hard-codes them.
    class MetaController < BaseController
      def show
        render json: {
          colors: Palette::COLORS,
          priorities: Task.priorities.keys.map { |value| { value:, label: value.humanize } },
          statuses: Task.statuses.keys
        }
      end
    end
  end
end
