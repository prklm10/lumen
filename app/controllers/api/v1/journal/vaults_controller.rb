module Api
  module V1
    module Journal
      class VaultsController < BaseController
        BINARY_FIELDS = %w[salt wrapped_dek wrapped_dek_iv recovery_salt wrapped_dek_recovery wrapped_dek_recovery_iv].freeze

        # { vault: null } until the journal is set up (a normal state, so not an error status).
        def show
          vault = Current.user.journal_vault
          render json: { vault: vault && serialize(vault) }
        end

        def create
          if Current.user.journal_vault
            return render_error(:conflict, "vault_exists", "The journal is already set up.")
          end

          vault = Current.user.build_journal_vault(vault_attributes(require_all: true))
          vault.save ? render(json: serialize(vault), status: :created) : render_validation_errors(vault)
        end

        # Re-wrapping the data key (new passphrase or recovery key). The server can't check the
        # passphrase, so it asks for the login password: a stolen session alone can't replace
        # the wrapped keys and lock the owner out of their journal.
        def update
          vault = Current.user.journal_vault || raise(ActiveRecord::RecordNotFound)
          unless Current.user.authenticate(params.require(:password).to_s)
            return render_error(:forbidden, "invalid_password", "That login password isn't right.")
          end

          vault.update(vault_attributes(require_all: false)) ? render(json: serialize(vault)) : render_validation_errors(vault)
        end

        private
          def vault_attributes(require_all:)
            input = params.require(:vault)
            attrs = BINARY_FIELDS.each_with_object({}) do |field, out|
              next if !input.key?(field) && !require_all
              out[field] = decode64(input.require(field), field)
            end
            attrs["kdf_algo"] = input[:kdf_algo] if input.key?(:kdf_algo)
            attrs["kdf_params"] = input.require(:kdf_params).permit(:m, :t, :p).to_h.transform_values { |v| Integer(v, exception: false) || v } if require_all || input.key?(:kdf_params)
            attrs
          end

          def serialize(vault)
            { kdf_algo: vault.kdf_algo, kdf_params: vault.kdf_params, updated_at: vault.updated_at }
              .merge(BINARY_FIELDS.to_h { |field| [ field, encode64(vault[field]) ] })
          end
      end
    end
  end
end
