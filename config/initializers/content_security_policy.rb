# Be sure to restart your server when you modify this file.

# Strict CSP: XSS is the main way the in-memory journal key could be stolen (PRD §7.5).
# See https://guides.rubyonrails.org/security.html#content-security-policy-header
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src     :self
    policy.base_uri        :self
    policy.form_action     :self
    policy.frame_ancestors :none
    policy.object_src      :none
    policy.font_src        :self, :data
    policy.img_src         :self, :data, :blob
    policy.script_src      :self
    # Vue/Reka set inline style attributes for positioning popovers.
    policy.style_src       :self, :unsafe_inline
    policy.connect_src     :self

    if Rails.env.development?
      # Allow the Vite dev server (assets + HMR websocket).
      vite = "http://#{ViteRuby.config.host_with_port}"
      policy.script_src  *policy.script_src, vite
      policy.style_src   *policy.style_src, vite
      policy.font_src    *policy.font_src, vite
      policy.img_src     *policy.img_src, vite
      policy.connect_src *policy.connect_src, vite, "ws://#{ViteRuby.config.host_with_port}"
    end
  end

  # Nonce for the tiny inline theme script in the SPA layout (avoids a light/dark flash).
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]
end
