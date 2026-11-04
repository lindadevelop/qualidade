import { defineStore } from 'pinia'
import { supabase } from '@/lib/supabase'

const KEY_AVISO = 'samsys-qualidade:aviso-dias'
const KEY_LIFECYCLE = 'samsys-qualidade:lifecycle-visivel'
const KEY_STRATEGY = 'samsys-qualidade:strategy-visivel'

export const useSettingsStore = defineStore('settings', {
  state: () => ({
    avisoDias: Number(localStorage.getItem(KEY_AVISO) ?? 5),
    lifecycleVisivel: localStorage.getItem(KEY_LIFECYCLE) !== 'desativado',
    strategyVisivel: localStorage.getItem(KEY_STRATEGY) !== 'desativado',
  }),
  actions: {
    // carrega o estado partilhado da BD (sobrepõe o local se existir)
    async initFromDb() {
      try {
        const { data } = await supabase.from('app_settings').select('key,value').in('key', ['lifecycle_visivel', 'strategy_visivel'])
        for (const row of (data ?? [])) {
          if (row.key === 'lifecycle_visivel') {
            this.lifecycleVisivel = String(row.value) !== 'false'
            localStorage.setItem(KEY_LIFECYCLE, String(row.value) !== 'false' ? 'ativado' : 'desativado')
          }
          if (row.key === 'strategy_visivel') {
            this.strategyVisivel = String(row.value) !== 'false'
            localStorage.setItem(KEY_STRATEGY, String(row.value) !== 'false' ? 'ativado' : 'desativado')
          }
        }
      } catch { /* offline — mantém local */ }
    },
    setAvisoDias(n: number) {
      this.avisoDias = n
      localStorage.setItem(KEY_AVISO, String(n))
    },
    async setLifecycleVisivel(v: boolean) {
      this.lifecycleVisivel = v
      localStorage.setItem(KEY_LIFECYCLE, v ? 'ativado' : 'desativado')
      try {
        // persiste na BD para o backend (/help IA) ler também
        await supabase.from('app_settings').upsert({ key: 'lifecycle_visivel', value: String(v) }, { onConflict: 'key' })
      } catch { /* offline */ }
    },
    async setStrategyVisivel(v: boolean) {
      this.strategyVisivel = v
      localStorage.setItem(KEY_STRATEGY, v ? 'ativado' : 'desativado')
      try {
        await supabase.from('app_settings').upsert({ key: 'strategy_visivel', value: String(v) }, { onConflict: 'key' })
      } catch { /* offline */ }
    },
  },
})