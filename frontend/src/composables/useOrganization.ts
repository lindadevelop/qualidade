// composables/useOrganization.ts — organização ativa persistida em localStorage + Pinia
import { supabase } from '@/lib/supabase'
import { ref, computed, watch } from 'vue'
import { listOrganizations } from '@/services/strategy'
import type { Organization } from '@/types/strategy'

const STORAGE_KEY = 'samsys-qualidade:active-organization-id'
const orgId = ref<string>(localStorage.getItem(STORAGE_KEY) ?? '')
const organizations = ref<Organization[]>([])
const loading = ref(false)
const loaded = ref(false)
let sessionUser: string | undefined
supabase.auth.onAuthStateChange((_event,session) => {
 const next=session?.user.id
 if(next!==sessionUser){sessionUser=next;loaded.value=false;organizations.value=[];orgId.value=''}
})

export function useOrganization() {
  const activeOrganization = computed(() => organizations.value.find(o => o.id === orgId.value) ?? organizations.value[0] ?? null)

  async function loadOrganizations(force = false) {
    if (loaded.value && !force) return
    loading.value = true
    try {
      organizations.value = await listOrganizations()
      loaded.value = true
      // se nenhuma ativa ou inválida, escolher a primeira ativa
      if (!orgId.value || !organizations.value.some(o => o.id === orgId.value)) {
        orgId.value = organizations.value[0]?.id ?? ''
      }
    } finally {
      loading.value = false
    }
  }

  function setOrganization(id: string) {
    orgId.value = id
  }

  watch(orgId, (id) => {
    if (id) localStorage.setItem(STORAGE_KEY, id)
    else localStorage.removeItem(STORAGE_KEY)
  })

  return {
    organizations,
    activeOrganization,
    orgId,
    loading,
    loaded,
    loadOrganizations,
    setOrganization,
  }
}
