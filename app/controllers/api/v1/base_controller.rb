module Api
  module V1
    class BaseController < ApplicationController
      rescue_from ActionController::InvalidAuthenticityToken do
        render_error :unprocessable_entity, "invalid_csrf_token", "Your session expired. Reload the page and try again."
      end

      rescue_from ActiveRecord::RecordNotFound do
        render_error :not_found, "not_found", "Not found"
      end

      private
        def render_error(status, code, message, details: nil)
          render json: { error: { code:, message:, details: }.compact }, status:
        end

        def render_validation_errors(record)
          render_error :unprocessable_entity, "validation_failed", record.errors.full_messages.to_sentence,
            details: record.errors.to_hash
        end
    end
  end
end
