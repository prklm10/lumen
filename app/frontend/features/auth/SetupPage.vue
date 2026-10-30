<script setup lang="ts">
import { computed, ref } from 'vue'
import { useRouter } from 'vue-router'
import { Loader2 } from '@lucide/vue'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { ApiError } from '@/api/client'
import { useAuthStore } from '@/stores/auth'
import AuthShell from './AuthShell.vue'

const MIN_PASSWORD = 10

const auth = useAuthStore()
const router = useRouter()

const email = ref('')
const password = ref('')
const confirmation = ref('')
const error = ref('')
const submitting = ref(false)

const mismatch = computed(() => confirmation.value.length > 0 && confirmation.value !== password.value)

async function submit() {
  if (password.value.length < MIN_PASSWORD) return (error.value = `Use at least ${MIN_PASSWORD} characters.`)
  if (mismatch.value) return (error.value = 'Passwords do not match.')

  error.value = ''
  submitting.value = true
  try {
    await auth.setup(email.value, password.value)
    router.replace('/')
  } catch (e) {
    error.value = e instanceof ApiError ? e.message : 'Something went wrong. Is the server running?'
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <AuthShell title="Set up Lumen" subtitle="Create the account that protects this workspace">
    <form class="space-y-4" @submit.prevent="submit">
      <div class="space-y-1.5">
        <Label for="email">Email</Label>
        <Input id="email" v-model="email" type="email" autocomplete="username" required autofocus />
      </div>
      <div class="space-y-1.5">
        <Label for="password">Password</Label>
        <Input id="password" v-model="password" type="password" autocomplete="new-password" :minlength="MIN_PASSWORD" required />
        <p class="text-xs text-muted-foreground">At least {{ MIN_PASSWORD }} characters.</p>
      </div>
      <div class="space-y-1.5">
        <Label for="confirmation">Confirm password</Label>
        <Input id="confirmation" v-model="confirmation" type="password" autocomplete="new-password" :aria-invalid="mismatch" required />
      </div>
      <p v-if="error" class="text-sm text-destructive" role="alert">{{ error }}</p>
      <Button type="submit" class="w-full" :disabled="submitting">
        <Loader2 v-if="submitting" class="animate-spin" />
        Create account
      </Button>
    </form>
    <template #footer>
      <p class="mt-4 text-center text-xs leading-relaxed text-muted-foreground">
        This password signs you in to the app. Your journal will get its own separate passphrase.
      </p>
    </template>
  </AuthShell>
</template>
