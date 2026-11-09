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
      { path: 'tasks', name: 'tasks', redirect: { name: 'tasks-today' } },
      ...(['inbox', 'today', 'upcoming'] as const).map((view) => ({
        path: `tasks/${view}`,
        name: `tasks-${view}`,
        component: () => import('@/features/tasks/TaskViewPage.vue'),
        props: { view },
        meta: { title: view[0]!.toUpperCase() + view.slice(1) },
      })),
      { path: 'tasks/completed', name: 'tasks-completed', component: () => import('@/features/tasks/CompletedPage.vue'), meta: { title: 'Completed' } },
      { path: 'tasks/projects/:id', name: 'project', component: () => import('@/features/tasks/ProjectPage.vue'), props: true, meta: { title: 'Project' } },
      { path: 'learn', name: 'learn', component: () => import('@/features/learn/LearnHome.vue'), meta: { title: 'Learn' } },
      { path: 'learn/resources', name: 'resources', component: () => import('@/features/learn/study/ResourcesPage.vue'), meta: { title: 'Resources' } },
      { path: 'learn/review', name: 'review', component: () => import('@/features/learn/study/ReviewPage.vue'), meta: { title: 'Review' } },
      { path: 'learn/notes/:id', name: 'note', component: () => import('@/features/learn/NotePage.vue'), props: true, meta: { title: 'Note' } },
      { path: 'tracker', name: 'tracker', component: () => import('@/features/tracker/TrackerPage.vue'), meta: { title: 'Tracker' } },
      { path: 'tracker/:id', name: 'tracker-detail', component: () => import('@/features/tracker/TrackerDetailPage.vue'), props: true, meta: { title: 'Tracker' } },
      { path: 'journal', name: 'journal', component: () => import('@/features/journal/JournalHome.vue'), meta: { title: 'Journal' } },
      { path: 'journal/new', name: 'journal-new', component: () => import('@/features/journal/JournalEntryPage.vue'), meta: { title: 'Journal' } },
      { path: 'journal/entries/:id', name: 'journal-entry', component: () => import('@/features/journal/JournalEntryPage.vue'), props: true, meta: { title: 'Journal' } },
      { path: 'analytics', name: 'analytics', component: () => import('@/features/analytics/AnalyticsPage.vue'), meta: { title: 'Analytics' } },
      { path: 'trash', name: 'trash', component: () => import('@/features/trash/TrashPage.vue'), meta: { title: 'Trash' } },
      { path: 'review/week', name: 'weekly-review', component: () => import('@/features/review/WeeklyReviewPage.vue'), meta: { title: 'Weekly review' } },
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
