<script setup lang="ts">
// CvQueuePanel.vue — card permanente + popup da fila de processamento de CVs.
// Não bloqueante: mostra totais, atualiza em tempo real (polling), permite ver a fila,
// cancelar, repetir e marcar como visto.
import { ref, onMounted, onUnmounted, computed, watch } from 'vue'
import { IconRefresh, IconX, IconFileText, IconCheck, IconAlertTriangle, IconLoader } from '@tabler/icons-vue'
import { listCvJobs, cancelCvJob, retryCvJob, markCvJobViewed, archiveCvJob, type CvJob } from '@/services/lifecycle'

const props = defineProps<{ ativo?: boolean }>()
const emit = defineEmits<{ (e: 'open-caso', id: string): void; (e: 'validar', job: CvJob): void }>()

const jobs = ref<CvJob[]>([])
const aberto = ref(false)
const filtro = ref('')
const pesquisa = ref('')
const erro = ref('')
const loading = ref(true)
const vistosAte = ref<string[]>([])
let timer: ReturnType<typeof setInterval> | null = null
let cancPetition = false

const ATIVOS = ['QUEUED', 'UPLOADING', 'EXTRACTING', 'OCR', 'ANALYZING', 'VALIDATING', 'DEDUPLICATING', 'CREATING', 'CANCEL_REQUESTED']
const totais = computed(() => {
  let fila = 0, processando = 0, concluidos = 0, erros = 0, cancelados = 0
  for (const j of jobs.value) {
    if (['DONE', 'DONE_WARN'].includes(j.status)) concluidos++
    else if (j.status === 'ERROR') erros++
    else if (['CANCELLED', 'CANCEL_REQUESTED'].includes(j.status)) cancelados++
    else if (j.status === 'QUEUED') fila++
    else processando++
  }
  return { fila, processando, concluidos, erros, cancelados, total: jobs.value.length }
})
const temAtividade = computed(() => totais.value.processando + totais.value.fila > 0)
const ativoNome = computed<string | null>(() => {
  const a = jobs.value.find((j) => ATIVOS.includes(j.status) && j.status !== 'QUEUED' && j.status !== 'CANCEL_REQUESTED')
    || jobs.value.find((j) => j.status === 'QUEUED')
  return a ? a.file_name : null
})

const filtrados = computed(() => {
  let m = jobs.value
  if (filtro.value) m = m.filter((j) => j.status === filtro.value)
  if (pesquisa.value.trim()) {
    const s = pesquisa.value.trim().toLowerCase()
    m = m.filter((j) => (j.file_name || '').toLowerCase().includes(s) || (j.error_message || '').toLowerCase().includes(s))
  }
  // ordena: ativos primeiro, depois erros, depois concluídos recentes
  const peso = (j: CvJob) => ATIVOS.includes(j.status) ? 0 : j.status === 'ERROR' ? 1 : j.status === 'CANCELLED' ? 2 : 3
  return [...m].sort((a, b) => peso(a) - peso(b) || String(b.created_at || '').localeCompare(String(a.created_at || '')))
})

function statusLabel(s: string): string {
  return { QUEUED: 'Na fila', UPLOADING: 'A carregar', EXTRACTING: 'A extrair texto', OCR: 'A executar OCR', ANALYZING: 'A analisar (Ollama)', VALIDATING: 'A validar', DEDUPLICATING: 'A verificar duplicados', CREATING: 'A criar ficha', DONE: 'Concluído', DONE_WARN: 'Concluído c/ avisos', ERROR: 'Erro', CANCEL_REQUESTED: 'Cancelamento pedido', CANCELLED: 'Cancelado' }[s] || s
}
function tone(s: string): string {
  if (['DONE', 'DONE_WARN'].includes(s)) return 'badge-soft-success'
  if (s === 'ERROR') return 'badge-soft-danger'
  if (['CANCELLED', 'CANCEL_REQUESTED'].includes(s)) return 'badge-soft-secondary'
  return 'badge-soft-primary'
}
function icone(s: string) {
  if (['QUEUED', 'UPLOADING', 'EXTRACTING', 'OCR', 'ANALYZING', 'VALIDATING', 'DEDUPLICATING', 'CREATING'].includes(s)) return IconLoader
  if (s === 'ERROR') return IconAlertTriangle
  if (['CANCELLED', 'CANCEL_REQUESTED'].includes(s)) return IconX
  if (['DONE', 'DONE_WARN'].includes(s)) return IconCheck
  return IconFileText
}
function fmtData(s?: string | null): string {
  if (!s) return '—'
  const d = new Date(s)
  return isNaN(d.getTime()) ? '—' : d.toLocaleString('pt-PT', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' })
}
function fmtDur(ms?: number | null): string {
  if (!ms) return '—'
  const s = Math.floor(ms / 1000)
  return s < 60 ? `${s}s` : `${Math.floor(s / 60)}m ${s % 60}s`
}

async function recarregar() {
  try {
    const r = await listCvJobs()
    jobs.value = r.jobs
    // marca novos concluídos como não vistos para o card refletir atividade fresca
    erro.value = ''
  } catch (e) { erro.value = (e as Error).message }
  loading.value = false
}
defineExpose({ recarregar, abrir: () => { aberto.value = true; recarregar() } })
async function cancelar(j: CvJob) {
  const s = j.status
  if (['DONE', 'DONE_WARN', 'ERROR', 'CANCELLED'].includes(s)) return
  if (!window.confirm(`Cancelar o processamento de "${j.file_name}"?`)) return
  try {
    const res = await cancelCvJob(j.id)
    // cancelamento final (na fila) sai da lista; pedido em processamento termina na próxima etapa
    if (res.status === 'CANCELLED') { try { await archiveCvJob(j.id) } catch { /* silencioso */ } }
    await recarregar()
  } catch (e) { erro.value = (e as Error).message }
}
async function repetir(j: CvJob) {
  if (j.status !== 'ERROR' && j.status !== 'CANCELLED' && j.status !== 'DONE') return
  try { await retryCvJob(j.id); await recarregar() } catch (e) { erro.value = (e as Error).message }
}
async function marcarVisto(j: CvJob) {
  if (j.viewed) return
  try { await markCvJobViewed(j.id); j.viewed = true } catch { /* silencioso */ }
}
function abrirCaso(j: CvJob) {
  if (j.caso_id) emit('open-caso', j.caso_id)
}
function validarJob(j: CvJob) {
  if (j.status === 'DONE' || j.status === 'DONE_WARN') emit('validar', j)
}

// polling ativo enquanto houver atividade; reduz/para quando tudo terminar
function tick() {
  if (!aberto.value && !temAtividade.value && !erro.value) { if (timer) { clearInterval(timer); timer = null }; return }
  recarregar()
}
function startPolling() {
  const intervalo = Number(import.meta.env.VITE_CV_POLL_MS || 5000)
  if (timer) clearInterval(timer)
  timer = setInterval(tick, intervalo)
}
onMounted(() => { recarregar(); startPolling() })
onUnmounted(() => { if (timer) clearInterval(timer) })
watch(() => totais.value.processando + totais.value.fila, () => { if (timer) { clearInterval(timer); startPolling() } })
</script>

<template>
  <div>
    <!-- card compacto — sempre visível para abrir a fila; mostra o que está a processar -->
    <div class="card mb-3" style="border:1px solid #eee;border-radius:.6rem">
      <div class="card-body py-2 d-flex align-items-center gap-2 flex-wrap" style="font-size:.8rem">
        <span v-if="temAtividade" class="spinner-border spinner-border-sm" style="color:#7367f0"></span>
        <span v-else class="sq-muted"><IconCheck :size="15" style="color:#28c76f" /></span>
        <span class="fw-semibold">Processamento de CV</span>
        <span v-if="totais.processando+totais.fila>0" class="sq-badge badge-soft-primary">{{ totais.processando+totais.fila }} ativo(s)</span>
        <span v-if="totais.concluidos" class="sq-badge badge-soft-success">{{ totais.concluidos }} concluído(s)</span>
        <span v-if="totais.erros" class="sq-badge badge-soft-danger">{{ totais.erros }} erro(s)</span>
        <span v-if="totais.cancelados" class="sq-badge badge-soft-secondary">{{ totais.cancelados }} cancelado(s)</span>
        <span v-if="ativoNome" class="fw-medium text-nowrap" style="color:#7367f0;font-size:.78rem">↻ {{ ativoNome }}</span>
        <span v-else-if="jobs.length" class="sq-muted text-nowrap" style="font-size:.75rem">{{ jobs[0].file_name }} · {{ jobs[0].status==='DONE' ? 'concluído' : jobs[0].status==='ERROR' ? 'erro' : jobs[0].status }}</span>
        <button class="btn btn-sm btn-outline-primary ms-auto d-inline-flex align-items-center gap-1" @click="aberto = !aberto">
          <IconFileText :size="14" /> {{ aberto ? 'Fechar fila' : 'Ver fila' }}
        </button>
      </div>
    </div>

    <!-- popup da fila -->
    <div v-if="aberto" class="modal-overlay" @click.self="aberto=false">
      <div class="card" style="max-width:820px;max-height:90vh;overflow:auto">
        <div class="card-header d-flex justify-content-between align-items-center">
          <span class="fw-semibold">Fila de processamento de CVs</span>
          <button class="btn btn-sm btn-close" @click="aberto=false"></button>
        </div>
        <div class="card-body">
          <div v-if="erro" class="alert alert-danger py-2" style="font-size:.8rem">{{ erro }}</div>
          <!-- totais -->
          <div class="row g-2 mb-2">
            <div class="col-6 col-md-3"><div class="border rounded p-2 text-center"><div class="fw-semibold">{{ totais.processando+totais.fila }}</div><div class="sq-muted" style="font-size:.7rem">Em curso</div></div></div>
            <div class="col-6 col-md-3"><div class="border rounded p-2 text-center"><div class="fw-semibold">{{ totais.concluidos }}</div><div class="sq-muted" style="font-size:.7rem">Concluídos</div></div></div>
            <div class="col-6 col-md-3"><div class="border rounded p-2 text-center"><div class="fw-semibold">{{ totais.erros }}</div><div class="sq-muted" style="font-size:.7rem">Erros</div></div></div>
            <div class="col-6 col-md-3"><div class="border rounded p-2 text-center"><div class="fw-semibold">{{ totais.cancelados }}</div><div class="sq-muted" style="font-size:.7rem">Cancelados</div></div></div>
          </div>
          <!-- filtros e pesquisa -->
          <div class="d-flex gap-2 mb-2 flex-wrap">
            <select class="form-select form-select-sm" style="width:auto" v-model="filtro">
              <option value="">Todos</option>
              <option value="QUEUED">Na fila</option>
              <option value="ANALYZING">Em processamento</option>
              <option value="DONE">Concluídos</option>
              <option value="ERROR">Com erro</option>
              <option value="CANCELLED">Cancelados</option>
            </select>
            <input class="form-control form-control-sm" style="max-width:220px" placeholder="Pesquisar ficheiro…" v-model="pesquisa" />
            <button class="btn btn-sm btn-outline-primary ms-auto d-inline-flex align-items-center gap-1" @click="recarregar"><IconRefresh :size="14" /> Atualizar</button>
          </div>
          <!-- lista -->
          <div class="table-responsive">
            <table class="table table-sm align-middle mb-0" style="font-size:.8rem">
              <thead><tr class="sq-muted" style="font-size:.7rem;text-transform:uppercase"><th>Ficheiro</th><th>Estado</th><th>Etapa</th><th>Enviado</th><th>Duração</th><th>Modelo</th><th class="text-end">Ações</th></tr></thead>
              <tbody>
                <tr v-for="j in filtrados" :key="j.id">
                  <td class="text-nowrap">{{ j.file_name }}</td>
                  <td><span class="sq-badge" :class="tone(j.status)">{{ statusLabel(j.status) }}</span></td>
                  <td class="sq-muted">{{ j.etapa }}<span v-if="j.progress!=null" style="font-size:.7rem"> · {{ Math.round(j.progress) }}%</span>
                    <div v-if="j.error_message" class="sq-muted" style="font-size:.7rem;color:#ea5455" :title="j.error_message">{{ j.error_message.slice(0,60) }}</div>
                  </td>
                  <td>{{ fmtData(j.created_at) }}</td>
                  <td>{{ fmtDur(j.duration_ms) }}</td>
                  <td class="sq-muted" style="font-size:.7rem">{{ j.model_ia || '—' }}</td>
                  <td class="text-end text-nowrap">
                    <button v-if="['DONE','DONE_WARN'].includes(j.status)" class="btn btn-sm btn-outline-success me-1" @click="validarJob(j)" title="Revisar e gravar a ficha do candidato (a IA é assistiva — grava só após a tua validação)">Validar ficha</button>
                    <button v-if="['DONE','DONE_WARN'].includes(j.status) && !j.viewed" class="btn btn-sm btn-outline-secondary" @click="marcarVisto(j)" title="Marcar como visto">✓</button>
                    <button v-if="['ERROR','CANCELLED'].includes(j.status)" class="btn btn-sm btn-outline-primary me-1" @click="repetir(j)" title="Tentar novamente">↻</button>
                    <button v-if="ATIVOS.includes(j.status)" class="btn btn-sm btn-outline-danger me-1" @click="cancelar(j)" title="Cancelar">✕</button>
                    <button v-if="j.pessoa_id || j.caso_id" class="btn btn-sm btn-outline-secondary me-1" @click="abrirCaso(j)" title="Abrir candidato">👤</button>
                  </td>
                </tr>
                <tr v-if="!filtrados.length"><td colspan="7" class="text-center sq-muted py-4">Sem trabalhos nesta vista.</td></tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.modal-overlay { position: fixed; inset: 0; background: rgba(15,15,40,.45); display: grid; place-items:center; z-index:1100; padding:1rem; }
</style>