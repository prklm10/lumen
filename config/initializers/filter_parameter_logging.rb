# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  # Journal vault payloads (PRD §7.5) — never log, even though they are ciphertext.
  # (`iv` is matched exactly: as a substring it would also hide params like "archived".)
  :ciphertext, :wrapped_dek, :recovery, /\Aiv\z/
]
