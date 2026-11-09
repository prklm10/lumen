# Public key-derivation parameters plus the journal's data key, wrapped twice (passphrase and
# recovery key). Nothing here can decrypt anything without the passphrase or recovery key,
# which never reach the server (PRD §7.2).
class JournalVault < ApplicationRecord
  KDF_LIMITS = { "m" => 19_456..1_048_576, "t" => 1..10, "p" => 1..4 }.freeze # OWASP minimum is m=19 MiB, t=2

  belongs_to :user

  validates :kdf_algo, inclusion: { in: %w[argon2id] }
  validates :salt, :recovery_salt, length: { is: 16 }
  validates :wrapped_dek_iv, :wrapped_dek_recovery_iv, length: { is: 12 }
  validates :wrapped_dek, :wrapped_dek_recovery, length: { is: 48 }
  validate :kdf_params_in_range

  private
    def kdf_params_in_range
      params = kdf_params.is_a?(Hash) ? kdf_params : {}
      ok = KDF_LIMITS.all? { |key, range| params[key].is_a?(Integer) && range.cover?(params[key]) } && params.keys.sort == KDF_LIMITS.keys.sort
      errors.add(:kdf_params, "must be Argon2id { m, t, p } within safe limits") unless ok
    end
end
