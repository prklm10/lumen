module Api
  module V1
    class SessionsController < BaseController
      allow_unauthenticated_access only: %i[show create]
      rate_limit to: 5, within: 1.minute, only: :create,
        with: -> { render_error :too_many_requests, "rate_limited", "Too many attempts. Try again in a minute." }

      # The SPA's bootstrap call: who am I, and does the app still need first-run setup?
      # Always 200 so a signed-out visit doesn't log an error in the browser console.
      def show
        if authenticated?
          render json: { user: UserResource.new(Current.user).to_h, needs_setup: false }
        else
          render json: { user: nil, needs_setup: !User.exists? }
        end
      end

      def create
        if (user = User.authenticate_by(params.permit(:email_address, :password)))
          start_new_session_for user
          render json: { user: UserResource.new(user).to_h }, status: :created
        else
          render_error :unauthorized, "invalid_credentials", "Wrong email or password."
        end
      end

      def destroy
        terminate_session
        head :no_content
      end
    end
  end
end
