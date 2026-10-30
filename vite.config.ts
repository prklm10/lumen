import { defineConfig } from 'vite'
import RubyPlugin from 'vite-plugin-ruby'
import vue from '@vitejs/plugin-vue'
import tailwindcss from '@tailwindcss/vite'

// vite-plugin-ruby already aliases `@/` and `~/` to app/frontend.
export default defineConfig({
  plugins: [RubyPlugin(), vue(), tailwindcss()],
  build: {
    // Keep the production image lean (PRD DKR-2); dev builds still have source maps.
    sourcemap: false,
  },
})
