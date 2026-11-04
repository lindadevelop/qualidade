<script setup lang="ts">
import {API_BASE} from '@/lib/api-base'

import PageHeader from '@/components/PageHeader.vue'
import { ref, onMounted } from 'vue'
import { supabase } from '@/lib/supabase'
import { useRouter } from 'vue-router'
import {
  IconFileTypePpt, IconChevronLeft, IconDownload, IconRefresh, IconPresentation,
} from '@tabler/icons-vue'
import { useOrganization } from '@/composables/useOrganization'
import { useBrandKit } from '@/composables/useBrandKit'
import { listMeetings, listGeneratedFiles } from '@/services/strategy'
import type { Meeting, GeneratedFile } from '@/types/strategy'

const router = useRouter()
const { activeOrganization, loadOrganizations } = useOrganization()
useBrandKit()

const templates = ref<{id:string;name:string;is_default:boolean}[]>([])
const selectedTemplateId = ref('')
const meetings = ref<Meeting[]>([])
const files = ref<GeneratedFile[]>([])
const selectedMeetingId = ref<string>('')
const generating = ref(false)
const error = ref('')
const success = ref('')

async function load() {
  if (!activeOrganization.value) await loadOrganizations()
  if (!activeOrganization.value) return
  try {
    const [m, f, t] = await Promise.all([
      listMeetings(activeOrganization.value.id),
      listGeneratedFiles(activeOrganization.value.id),
      supabase.from('ppt_templates').select('id,name,is_default').eq('organization_id',activeOrganization.value.id).eq('active',true),
    ])
    if(t.error) throw t.error
    templates.value=t.data??[]
    if(!selectedTemplateId.value) selectedTemplateId.value=templates.value.find(t=>t.is_default)?.id??''
    meetings.value = m
    files.value = f
  } catch (e) { error.value = (e as Error).message }
}
onMounted(load)

async function generatePpt() {
  if (!activeOrganization.value) return
  generating.value = true
  error.value = ''
  success.value = ''
  try {
    const base = API_BASE || 'http://localhost:8000'
    const { data: { session } } = await supabase.auth.getSession()
    const token = session?.access_token
    if (!token) throw new Error('Inicia sessão para gerar a apresentação.')
    const res = await fetch(`${base}/ppt/generate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: token ? `Bearer ${token}` : '' },
      body: JSON.stringify({
        organization_id: activeOrganization.value.id,
        meeting_id: selectedMeetingId.value || undefined,
        template_id: selectedTemplateId.value || undefined,
      }),
    })
    const data = await res.json()
    if (!res.ok) throw new Error(data.error || 'Erro ao gerar PPT')
    success.value = `Apresentação gerada: ${data.name}`
    await load()
  } catch (e) { error.value = (e as Error).message } finally { generating.value = false }
}

async function downloadFile(file: GeneratedFile) {
  try {
    const base = API_BASE || 'http://localhost:8000'
    const {data:{session}} = await supabase.auth.getSession()
    if(!session) throw new Error('Inicia sessão para descarregar.')
    const response = await fetch(`${base}/ppt/download/${file.id}`, {headers:{Authorization:`Bearer ${session.access_token}`}})
    if(!response.ok) throw new Error('Não foi possível descarregar o ficheiro.')
    const url=URL.createObjectURL(await response.blob()), link=document.createElement('a')
    link.href=url;link.download=file.name;link.click();setTimeout(()=>URL.revokeObjectURL(url),1000)
  } catch(e) { error.value=(e as Error).message }
}
</script>

<template>
  <div>
    <div class="d-flex justify-content-between align-items-start flex-wrap gap-2">
      <div>
        <PageHeader><template #title>Apresentações</template><template #breadcrumb>Estratégia › Apresentações</template></PageHeader>
      </div>
      <button class="btn btn-outline-secondary d-flex align-items-center gap-2" @click="router.push('/estrategia/kpis')">
        <IconChevronLeft :size="16"/> KPIs
      </button>
    </div>

    <div v-if="error" class="alert alert-danger py-2">{{ error }}</div>
    <div v-if="success" class="alert alert-success py-2">{{ success }}</div>

    <div class="sq-card mb-3">
      <div class="row g-3 align-items-end">
        <div class="col-12"><label for="ppt-template" class="form-label">Template</label><select id="ppt-template" v-model="selectedTemplateId" class="form-select"><option value="">Modelo predefinido da organização</option><option v-for="t in templates" :key="t.id" :value="t.id">{{ t.name }}</option></select></div>
        <div class="col-12 col-md-6">
          <label class="form-label">Reunião (opcional)</label>
          <select v-model="selectedMeetingId" class="form-select">
            <option value="">Toda a organização</option>
            <option v-for="m in meetings" :key="m.id" :value="m.id">{{ m.title }} — {{ new Date(m.scheduled_at).toLocaleDateString('pt-PT') }}</option>
          </select>
        </div>
        <div class="col-12 col-md-6">
          <button class="btn btn-primary d-flex align-items-center gap-2" :disabled="generating" @click="generatePpt">
            <IconFileTypePpt :size="18"/> {{ generating ? 'A gerar…' : 'Gerar PPT' }}
          </button>
        </div>
      </div>
    </div>

    <div class="sq-card">
      <h6 class="sq-card-title d-flex align-items-center gap-2"><IconPresentation :size="18"/> Ficheiros gerados</h6>
      <table class="sq-table">
        <thead><tr><th>Nome</th><th>Estado</th><th>Gerado em</th><th></th></tr></thead>
        <tbody>
          <tr v-if="!files.length" class="text-center sq-muted"><td colspan="4">Nenhum ficheiro gerado.</td></tr>
          <tr v-for="f in files" :key="f.id">
            <td class="sq-ref">{{ f.name }}</td>
            <td><span class="sq-badge" :class="f.status==='ready'?'badge-soft-success':'badge-soft-warning'">{{ f.status }}</span></td>
            <td>{{ f.generated_at ? new Date(f.generated_at).toLocaleString('pt-PT') : '—' }}</td>
            <td>
              <button v-if="f.status==='ready'" @click="downloadFile(f)" class="btn btn-sm btn-outline-primary d-inline-flex align-items-center gap-1">
                <IconDownload :size="14"/> Download
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
