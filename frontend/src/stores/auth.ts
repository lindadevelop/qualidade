import { defineStore } from 'pinia'
import type { Profile, ProfileRole } from '@/types/database'
import type { AppModule } from '@/domain/module-access'
import { supabase } from '@/lib/supabase'

export const useAuthStore = defineStore('auth', {
  state: () => ({
    profile: null as Profile | null,
    loading: false,
    initialized: false,
  }),
  getters: {
    isAuthenticated: (s) => s.profile?.active === true,
    isGlobalAdmin: (s) => s.profile?.active === true && s.profile.is_super_admin === true,
    hasModule: (s) => (module: AppModule): boolean => s.profile?.active === true && (s.profile.role === 'admin' || (!s.profile.module_access || s.profile.module_access[module] === true)),
    role: (s): ProfileRole | null => s.profile?.role ?? null,
    fullName: (s) => s.profile?.full_name ?? '',
    /** QUALIDADE e admin gerem tudo */
    canManage: (s) => s.profile?.role==='admin'||(s.profile as any)?.effective_roles?.quality?.includes('quality'),
    canManageStrategy: (s) => s.profile?.role==='admin'||(s.profile as any)?.effective_roles?.strategy?.includes('quality'),
    canManageLifecycle: (s) => s.profile?.role==='admin'||(s.profile as any)?.effective_roles?.lifecycle?.includes('quality'),
    /** Apenas Qualidade/Admin validam eficácia e encerram */
    canValidateEffectiveness: (s) => s.profile?.role==='admin'||(s.profile as any)?.effective_roles?.quality?.includes('quality'),
    canAdminister: (s) => s.profile?.active === true && (s.profile.role === 'admin' || !s.profile.module_access && s.profile.role === 'quality'),
    isManagement: (s) => (s.profile as any)?.effective_roles?.quality?.includes('management'),
    /** Só lê? Management é read-only */
    isReadOnly(): boolean {
      const roles=(this.profile as any)?.effective_roles?.quality||[]
      return this.profile?.role!=='admin' && !roles.includes('quality') && !roles.includes('action_owner')
    },
  },
  actions: {
    async init() {
      if (this.initialized) return
      this.loading = true
      try {
        const { data } = await supabase.auth.getSession()
        if (data.session?.user) await this.loadProfile(data.session.user.id)
        supabase.auth.onAuthStateChange(async (_e, session) => {
          if (session?.user) await this.loadProfile(session.user.id)
          else this.profile = null
        })
      } finally {
        this.loading = false
        this.initialized = true
      }
    },

    async loadProfile(userId: string) {
      const { data, error } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', userId)
        .maybeSingle()
      if (error) { this.profile = null; return }
      this.profile = data?.active ? (data as unknown as Profile) : null
      if(this.profile){const roles:any={};for(const module of ['quality','strategy','lifecycle']){const result=await supabase.rpc('effective_roles',{p_user:userId,p_module:module});roles[module]=result.data||[]}Object.assign(this.profile,{effective_roles:roles})}
    },

    async signIn(email: string, password: string) {
      const { error } = await supabase.auth.signInWithPassword({ email, password })
      if (error) throw error
      const { data } = await supabase.auth.getSession()
      if (data.session?.user) await this.loadProfile(data.session.user.id)
    },

    async signOut() {
      await supabase.auth.signOut()
      this.profile = null
    },

    async requestPasswordReset(email: string) {
      const { error } = await supabase.auth.resetPasswordForEmail(email, {
        redirectTo: `${window.location.origin}/reset-password`,
      })
      if (error) throw error
    },

    async updatePassword(newPassword: string) {
      const { error } = await supabase.auth.updateUser({ password: newPassword })
      if (error) throw error
      await this.signOut()
      window.location.assign('/login')
    },
  },
})
