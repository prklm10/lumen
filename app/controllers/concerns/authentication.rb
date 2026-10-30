module Authentication
  extend ActiveSupport::Concern

  # Sessions expire after this long without activity (PRD AUTH-2).
  IDLE_TIMEOUT = 7.days
  # Avoid a DB write on every request: refresh last activity at most this often.
  TOUCH_INTERVAL = 1.hour

  included do
    before_action :require_authentication
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private
    def authenticated?
      resume_session
    end

    def require_authentication
      resume_session || request_authentication
    end

    def resume_session
      Current.session ||= find_session_by_cookie
    end

    def find_session_by_cookie
      return unless (id = cookies.signed[:session_id])

      session = Session.find_by(id: id)
      return unless session

      if session.updated_at < IDLE_TIMEOUT.ago
        session.destroy
        cookies.delete(:session_id)
        return
      end

      session.touch if session.updated_at < TOUCH_INTERVAL.ago
      session
    end

    def request_authentication
      render json: { error: { code: "unauthenticated", message: "Please sign in." } }, status: :unauthorized
    end

    def start_new_session_for(user)
      user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
        Current.session = session
        cookies.signed.permanent[:session_id] = { value: session.id, httponly: true, same_site: :strict }
      end
    end

    def terminate_session
      Current.session.destroy
      cookies.delete(:session_id)
    end
end
