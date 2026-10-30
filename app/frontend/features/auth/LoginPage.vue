<script setup lang="ts">
import { ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Loader2 } from '@lucide/vue'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { ApiError } from '@/api/client'
import { useAuthStore } from '@/stores/auth'
import AuthShell from './AuthShell.vue'

const auth = useAuthStore()
const router = useRouter()
const route = useRoute()

const email = ref('')
const password = ref('')
const error = ref('')
const submitting = ref(false)

async function submit() {
  error.value = ''
  submitting.value = true
  try {
    await auth.login(email.value, password.value)
    const next = typeof route.query.next === 'string' && route.query.next.startsWith('/') ? route.query.next : '/'
    router.replace(next)
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'Something went wrong. Is the server running?'
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <AuthShell title="Welcome back" subtitle="Sign in to your Lumen workspace">
    <form class="space-y-4" @submit.prevent="submit">
      <div class="space-y-1.5">
        <Label for="email">Email</Label>
        <Input id="email" v-model="email" type="email" autocomplete="username" required autofocus />
      </div>
      <div class="space-y-1.5">
        <Label for="password">Password</Label>
        <Input id="password" v-model="password" type="password" autocomplete="current-password" required />
      </div>
      <p v-if="error" class="text-sm text-destructive" role="alert">{{ error }}</p>
      <Button type="submit" class="w-full" :disabled="submitting">
        <Loader2 v-if="submitting" class="animate-spin" />
        Sign in
      </Button>
    </form>
  </AuthShell>
</template>
