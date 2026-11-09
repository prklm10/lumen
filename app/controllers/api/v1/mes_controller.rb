module Api
  module V1
    # PATCH /api/v1/me — the signed-in user's time zone and settings.
    class MesController < BaseController
      def update
        user = Current.user
        input = params.require(:user)
        user.time_zone = input[:time_zone] if input.key?(:time_zone)
        user.settings = input[:settings].permit(*User::SETTINGS.keys).to_h if input[:settings].respond_to?(:permit)
        user.save ? render(json: { user: UserResource.new(user).to_h }) : render_validation_errors(user)
      end
    end
  end
end
