import { useColorMode } from '@vueuse/core'

export type ThemeMode = 'light' | 'dark' | 'auto'

// Storage key must match the inline script in layouts/application.html.erb.
export function useTheme() {
  return useColorMode({ storageKey: 'lumen-theme', disableTransition: true })
}
