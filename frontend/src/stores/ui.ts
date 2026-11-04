import { defineStore } from 'pinia'

type ThemeMode = 'light' | 'dark' | 'system'

const STORAGE_KEY = 'samsys-qualidade:theme'

export const useUiStore = defineStore('ui', {
  state: () => ({
    sidebarCollapsed: false,
    mobileSidebarOpen: false,
    theme: (localStorage.getItem(STORAGE_KEY) as ThemeMode) || 'system',
  }),
  getters: {
    isDark(state): boolean {
      if (state.theme === 'system') {
        return window.matchMedia?.('(prefers-color-scheme: dark)').matches ?? false
      }
      return state.theme === 'dark'
    },
  },
  actions: {
    toggleSidebar() { this.sidebarCollapsed = !this.sidebarCollapsed },
    toggleMobileSidebar() { this.mobileSidebarOpen = !this.mobileSidebarOpen },
    closeMobileSidebar() { this.mobileSidebarOpen = false },
    setTheme(t: ThemeMode) {
      this.theme = t
      localStorage.setItem(STORAGE_KEY, t)
      this.applyTheme()
    },
    applyTheme() {
      const dark = this.isDark
      document.documentElement.setAttribute('data-bs-theme', dark ? 'dark' : 'light')
    },
  },
})
