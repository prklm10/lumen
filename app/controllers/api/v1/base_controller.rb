module Api
  module V1
    class BaseController < ApplicationController
      # Raised for a bad query/body value that isn't a model validation (unknown view, bad date…).
      class InvalidParameter < StandardError; end

      # The SPA sends explicit roots ({ task: {...} }); auto-wrapping would only add duplicates.
      wrap_parameters false

      around_action :use_user_time_zone

      rescue_from ActionController::InvalidAuthenticityToken do
        render_error :unprocessable_entity, "invalid_csrf_token", "Your session expired. Reload the page and try again."
      end

      rescue_from ActiveRecord::RecordNotFound do
        render_error :not_found, "not_found", "Not found"
      end

      rescue_from ActiveRecord::RecordInvalid do |error|
        render_validation_errors error.record
      end

      rescue_from InvalidParameter, ActionController::ParameterMissing do |error|
        render_error :unprocessable_entity, "invalid_parameter", error.message
      end

      private
        # "Today", "overdue" and due-date parsing all happen in the user's zone, not UTC.
        def use_user_time_zone(&)
          Current.user ? Time.use_zone(Current.user.time_zone, &) : yield
        end

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
