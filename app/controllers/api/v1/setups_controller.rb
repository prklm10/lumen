module Api
  module V1
    # First-run account creation. Only works while no user exists.
    class SetupsController < BaseController
      allow_unauthenticated_access

      def create
        return render_error(:forbidden, "already_set_up", "An account already exists.") if User.exists?

        user = User.new(params.permit(:email_address, :password, :time_zone))
        if user.save
          start_new_session_for user
          render json: { user: UserResource.new(user).to_h }, status: :created
        else
          render_validation_errors user
        end
      end
    end
  end
end
