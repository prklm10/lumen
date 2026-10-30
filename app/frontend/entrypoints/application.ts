import '@fontsource-variable/inter'
import '@fontsource-variable/jetbrains-mono'
import 'vue-sonner/style.css'
import '@/styles/main.css'

import { createApp } from 'vue'
import { createPinia } from 'pinia'
import { VueQueryPlugin } from '@tanstack/vue-query'
import App from '@/App.vue'
import { router } from '@/router'

createApp(App).use(createPinia()).use(router).use(VueQueryPlugin).mount('#app')
