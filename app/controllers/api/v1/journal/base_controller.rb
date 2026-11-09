module Api
  module V1
    module Journal
      # Binary columns travel as base64 strings in JSON.
      class BaseController < Api::V1::BaseController
        private
          def decode64(value, name)
            Base64.strict_decode64(value.to_s)
          rescue ArgumentError
            raise InvalidParameter, "#{name} must be base64"
          end

          def encode64(bytes) = Base64.strict_encode64(bytes)
      end
    end
  end
end
