import { createRouter, createWebHistory, type RouteRecordRaw } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { primaryNav } from '@/lib/navigation'

declare module 'vue-router' {
  interface RouteMeta {
    public?: boolean
    title?: string
  }
}

const placeholders: RouteRecordRaw[] = primaryNav
  .filter((item) => item.phase)
  .map((item) => ({
    path: item.path.slice(1),
    name: item.name,
    component: () => import('@/features/placeholder/PlaceholderPage.vue'),
    props: { item },
    meta: { title: item.label },
  }))

const routes: RouteRecordRaw[] = [
  {
    path: '/',
    component: () => import('@/layouts/AppLayout.vue'),
    children: [
      { path: '', name: 'today', component: () => import('@/features/today/TodayPage.vue'), meta: { title: 'Today' } },
      ...placeholders,
      { path: 'settings', name: 'settings', component: () => import('@/features/settings/SettingsPage.vue'), meta: { title: 'Settings' } },
    ],
  },
  { path: '/login', name: 'login', component: () => import('@/features/auth/LoginPage.vue'), meta: { public: true, title: 'Sign in' } },
  { path: '/setup', name: 'setup', component: () => import('@/features/auth/SetupPage.vue'), meta: { public: true, title: 'Welcome' } },
  { path: '/:pathMatch(.*)*', redirect: '/' },
]

export const router = createRouter({ history: createWebHistory(), routes })

router.beforeEach(async (to) => {
  const auth = useAuthStore()
  await auth.bootstrap()

  if (auth.needsSetup) return to.name === 'setup' ? true : { name: 'setup' }
  if (to.name === 'setup') return { name: 'today' }
  if (!to.meta.public && !auth.isAuthenticated) return { name: 'login', query: to.fullPath === '/' ? {} : { next: to.fullPath } }
  if (to.name === 'login' && auth.isAuthenticated) return { name: 'today' }
  return true
})

router.afterEach((to) => {
  document.title = to.meta.title ? `${to.meta.title} · Lumen` : 'Lumen'
})
