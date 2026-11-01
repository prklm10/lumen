import { defineConfig, type Plugin } from 'vite'
import RubyPlugin from 'vite-plugin-ruby'
import vue from '@vitejs/plugin-vue'
import tailwindcss from '@tailwindcss/vite'

// In the Docker dev stack the dev server must listen on all interfaces so the published port
// reaches it. Runs after RubyPlugin (which sets host from config/vite.json) so it wins; asset
// URLs keep using localhost:3036.
const listenOnAllInterfaces: Plugin = {
  name: 'lumen:listen-all',
  enforce: 'post',
  config: () => (process.env.VITE_LISTEN_ALL === 'true' ? { server: { host: '0.0.0.0' } } : undefined),
}

// vite-plugin-ruby already aliases `@/` and `~/` to app/frontend.
export default defineConfig({
  plugins: [RubyPlugin(), vue(), tailwindcss(), listenOnAllInterfaces],
  build: {
    // Keep the production image lean (PRD DKR-2); dev builds still have source maps.
    sourcemap: false,
  },
})
