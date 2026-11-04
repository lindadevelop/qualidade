<script setup lang="ts">
import {datePT} from '@/domain/dates'
import {API_BASE} from '@/lib/api-base'

import PageHeader from '@/components/PageHeader.vue'
import { computed, onMounted, nextTick, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import VueApexCharts from 'vue3-apexcharts'
import {
  IconSend, IconRobot, IconSparkles, IconRefresh, IconAlertTriangle, IconCheck,
} from '@tabler/icons-vue'
import { supabase } from '@/lib/supabase'
import { useAuthStore } from '@/stores/auth'

const router = useRouter()
const auth = useAuthStore()

const AI_URL = `${(API_BASE as string) || ''}/ai`

interface AiResult {
  kind: 'kpi' | 'chart' | 'list' | 'text'
  title?: string
  value?: number
  answer?: string
  labels?: string[]
  values?: number[]
  total?: number
  rows?: { id: string; reference: string; type: string; status: string; area?: string | null; origin?: string | null; responsible?: string | null; occurrence_date?: string; url?: string }[]
}

interface Msg {
  role: 'user' | 'assistant'
  text: string
  result?: AiResult | null
  links?: { id: string; display: string; url: string }[]
  suggestions?: string[]
  error?: boolean
}

const messages = ref<Msg[]>([])
const input = ref('')
const busy = ref(false)
const history = ref<{ role: string; content: string }[]>([])
const aiStatus = ref<{ available: boolean; modelAvailable: boolean; model?: string; reason?: string | null } | null>(null)
const listRef = ref<HTMLElement | null>(null)
const readyToast = ref<string>('')   // toast "terminou" (dismissable)

const SUGGESTIONS = [
  'Quantas ocorrências estão abertas?',
  'Resumo de hoje',
  'Ocorrências críticas',
  'Principais áreas',
  'Tempo médio de resolução',
  'Problemas mais frequentes',
]

// ---- persistência da conversa em background (sair e voltar) ----
function storageKey() {
  return `samsys-qualidade:ai-chat:${auth.profile?.id ?? auth.profile?.email ?? 'anon'}`
}
function persist() {
  try {
    localStorage.setItem(storageKey(), JSON.stringify({ messages: messages.value, history: history.value, pending: busy.value ? pendingQuestion.value : '' }))
  } catch { /* sem quota */ }
}
function loadPersisted() {
  try {
    const raw = localStorage.getItem(storageKey())
    if (!raw) return null
    const d = JSON.parse(raw)
    return d
  } catch { return null }
}
function clearPersisted() {
  try { localStorage.removeItem(storageKey()) } catch { /* ignore */ }
}

const restoreRef = ref<{ messages: Msg[]; history: { role: string; content: string }[]; pending: string } | null>(loadPersisted())
let restored = false
const pendingQuestion = ref('')

// persiste continuamente (mensagens, histórico e pergunta pendente) para retomar em background
watch([messages, busy, pendingQuestion], () => { if (restored) persist() }, { deep: true })

function restoreConversation() {
  const d = restoreRef.value
  if (!d || !d.messages?.length) return
  // restaura sempre a conversa guardada (texto, KPI, gráficos, erros)
  messages.value = d.messages
  history.value = d.history ?? []
  if (d.pending) pendingQuestion.value = d.pending
}

onMounted(async () => {
  restoreConversation()
  restored = true
  try {
    const r = await fetch(`${AI_URL}/status`)
    aiStatus.value = await r.json()
  } catch { aiStatus.value = { available: false, modelAvailable: false, reason: 'Sem ligação' } }
  if (messages.value.length === 0) {
    messages.value = [{
      role: 'assistant',
      text: 'Olá! Sou o Assistente de Ocorrências. Pergunte-me qualquer coisa sobre os dados das NC/OM — contagens, listas, estatísticas ou evolução.',
      suggestions: SUGGESTIONS.slice(0, 3),
    }]
  }
  // pergunta pendente -> re-emite automaticamente (o servidor continua em background)
  if (pendingQuestion.value) {
    const p = pendingQuestion.value
    pendingQuestion.value = ''
    await ask(p, true)   // reemissão: a mensagem do user já está restaurada
  }
})

const isDark = computed(() => document.documentElement.getAttribute('data-bs-theme') === 'dark')
const chartText = computed(() => isDark.value ? '#b7b9d0' : '#5d596c')

async function scrollDown() {
  await nextTick()
  listRef.value?.scrollTo({ top: listRef.value.scrollHeight, behavior: 'smooth' })
}

async function ask(text?: string, reemit = false) {
  const q = (text ?? input.value).trim()
  if (!q || busy.value) return
  input.value = ''
  if (!reemit) messages.value.push({ role: 'user', text: q })  // na reemissão a msg user já está restaurada
  busy.value = true
  pendingQuestion.value = q   // registada como pendente (continua em background ao sair)
  await scrollDown()

  try {
    const { data: session } = await supabase.auth.getSession()
    const token = session.session?.access_token
    const res = await fetch(`${AI_URL}/chat`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: JSON.stringify({ message: q, history: history.value.slice(-6) }),
    })
    const data = await res.json()
    messages.value.push({
      role: 'assistant',
      text: data.answer || 'Sem resposta.',
      result: data.data ?? null,
      links: data.links ?? [],
      suggestions: data.suggestions ?? [],
      error: !!data.error,
    })
    history.value.push({ role: 'user', content: q }, { role: 'assistant', content: data.answer || '' })
    notifyReady()
  } catch (e) {
    messages.value.push({
      role: 'assistant',
      text: 'O Assistente IA está temporariamente indisponível. Tenta novamente.',
      error: true,
    })
  } finally {
    busy.value = false
    pendingQuestion.value = ''   // concluída
    persist()
    await scrollDown()
  }
}

// --- notificação quando o processamento termina (para retomar em background) ---
function notifyReady() {
  const txt = 'O Assistente IA terminou de processar o teu pedido.'
  // aviso visual na própria página (dismissable) + título da aba
  readyToast.value = txt
  try { document.title = '✓ Assistente IA pronto' } catch { /* ignore */ }
  // Notification nativa do browser (funciona mesmo noutra aba/página)
  try {
    if (typeof window !== 'undefined' && 'Notification' in window) {
      if (Notification.permission === 'granted') {
        new Notification('Assistente IA pronto', { body: txt, icon: '/favicon.svg' })
      } else if (Notification.permission !== 'denied') {
        Notification.requestPermission().then((p) => {
          if (p === 'granted') new Notification('Assistente IA pronto', { body: txt, icon: '/favicon.svg' })
        })
      }
    }
  } catch { /* sem suporte */ }
}

function newConversation() {
  messages.value = [{
    role: 'assistant',
    text: 'Nova conversa iniciada. Em que posso ajudar?',
    suggestions: SUGGESTIONS.slice(0, 3),
  }]
  history.value = []
  clearPersisted()
}

function statusBadge(s: string) {
  switch (s) {
    case 'OPEN': return 'badge-soft-secondary'
    case 'IN_PROGRESS': return 'badge-soft-warning'
    case 'AWAITING_EFFECTIVENESS': return 'badge-soft-info'
    case 'CLOSED': return 'badge-soft-success'
    default: return 'badge-soft-secondary'
  }
}
function statusLabel(s: string) {
  return { OPEN: 'Aberta', IN_PROGRESS: 'Em curso', AWAITING_EFFECTIVENESS: 'A aguardar eficácia', CLOSED: 'Encerrada' }[s] ?? s
}
</script>

<template>
  <div>
    <div class="d-flex justify-content-between align-items-end flex-wrap gap-2 mb-2">
      <div>
        <PageHeader><template #title><IconSparkles :size="22" style="color:#7367f0" /> Assistente de Ocorrências</template><template #breadcrumb>Pergunte qualquer coisa sobre os dados das ocorrências.</template></PageHeader>
      </div>
      <div class="d-flex align-items-center gap-2">
        <span v-if="aiStatus" class="sq-badge" :class="aiStatus.available && aiStatus.modelAvailable ? 'badge-soft-success' : 'badge-soft-danger'">
          <IconAlertTriangle v-if="!aiStatus.available || !aiStatus.modelAvailable" :size="13" />
          {{ aiStatus.available && aiStatus.modelAvailable ? 'Ollama disponível' : (aiStatus.reason || 'Indisponível') }}
        </span>
        <button class="btn btn-outline-secondary btn-sm d-flex align-items-center gap-1" @click="newConversation">
          <IconRefresh :size="15" /> Nova conversa
        </button>
      </div>
    </div>

    <div v-if="readyToast" class="alert alert-success d-flex align-items-center gap-2 mb-3" style="border-radius:.6rem">
      <IconCheck :size="18" />
      <span class="flex-grow-1">{{ readyToast }}</span>
      <button type="button" class="btn-close" aria-label="Fechar" @click="readyToast = ''"></button>
    </div>

    <div class="sq-card d-flex flex-column" style="height:calc(100vh - 230px);min-height:420px">
      <!-- conversa -->
      <div ref="listRef" class="flex-grow-1" style="overflow-y:auto;padding:.25rem">
        <div v-for="(m, i) in messages" :key="i" class="mb-3" :class="m.role === 'user' ? 'text-end' : ''">
          <div class="d-flex gap-2" :class="m.role === 'user' ? 'justify-content-end' : ''">
            <span v-if="m.role === 'assistant'" class="sq-avatar" style="background:rgba(115,103,240,.12);flex:0 0 32px">
              <IconRobot :size="17" style="color:#7367f0" />
            </span>
            <div style="max-width:78%">
              <div class="px-3 py-2" :style="{
                background: m.role === 'user' ? 'linear-gradient(135deg,#7367f0,#8e7bff)' : 'var(--sq-bg)',
                color: m.role === 'user' ? '#fff' : 'var(--sq-text)',
                borderRadius: '.6rem', whiteSpace: 'pre-wrap', textAlign: 'left'
              }">
                {{ m.text }}
              </div>

              <!-- KPI -->
              <div v-if="m.result && m.result.kind === 'kpi'" class="sq-card mt-2 text-center" style="display:inline-block;min-width:160px">
                <div class="sq-kpi-value">{{ m.result.value }}</div>
                <div class="sq-kpi-label">{{ m.result.title }}</div>
              </div>

              <!-- gráfico -->
              <div v-if="m.result && m.result.kind === 'chart'" class="sq-card mt-2" style="max-width:560px">
                <VueApexCharts type="bar" height="240"
                  :options="{ chart: { toolbar: { show: false }, foreColor: chartText }, colors: ['#7367f0'],
                    plotOptions: { bar: { borderRadius: 4, horizontal: true, barHeight: '60%' } },
                    xaxis: { labels: { style: { colors: chartText } } },
                    yaxis: { labels: { style: { colors: chartText } } },
                    dataLabels: { enabled: true } }"
                  :series="[{ name: 'Ocorrências', data: m.result.values }]" />
                <div class="sq-muted" style="font-size:.78rem">{{ m.result.labels?.join(' · ') }}</div>
              </div>

              <!-- lista -->
              <div v-if="m.result && m.result.kind === 'list' && m.result.rows?.length" class="sq-card mt-2" style="max-width:620px">
                <div class="table-responsive">
                  <table class="sq-table">
                    <thead><tr><th>Ref</th><th>Tipo</th><th>Área</th><th>Estado</th><th>Data</th></tr></thead>
                    <tbody>
                      <tr v-for="r in m.result.rows.slice(0, 10)" :key="r.id" style="cursor:pointer" @click="router.push(r.url || '/ocorrencias/' + r.id)">
                        <td class="sq-ref">{{ r.reference }}</td>
                        <td><span class="sq-badge" :class="r.type === 'NC' ? 'badge-soft-danger' : 'badge-soft-primary'">{{ r.type }}</span></td>
                        <td>{{ r.area || '—' }}</td>
                        <td><span class="sq-badge" :class="statusBadge(r.status)">{{ statusLabel(r.status) }}</span></td>
                        <td class="sq-muted">{{ datePT(r.occurrence_date) }}</td>
                      </tr>
                    </tbody>
                  </table>
                </div>
                <div v-if="m.result.rows.length > 10" class="sq-muted mt-1" style="font-size:.78rem">
                  ... e mais {{ m.result.rows.length - 10 }} ocorrência(s). Abre "Todas as Ocorrências" para ver a lista completa.
                </div>
              </div>

              <!-- sugestões -->
              <div v-if="m.suggestions?.length" class="mt-2 d-flex flex-wrap gap-1">
                <button v-for="s in m.suggestions" :key="s" class="btn btn-sm btn-outline-secondary" @click="ask(s)">{{ s }}</button>
              </div>
            </div>
          </div>
        </div>

        <div v-if="busy" class="d-flex gap-2 align-items-center sq-muted">
          <span class="sq-avatar" style="background:rgba(115,103,240,.12)"><IconRobot :size="17" style="color:#7367f0" /></span>
          <span class="spinner-border spinner-border-sm" role="status"></span> A analisar os dados…
        </div>
      </div>

      <!-- input -->
      <div class="d-flex gap-2 pt-2" style="border-top:1px solid var(--sq-border)">
        <input v-model="input" class="form-control" placeholder="Pergunte sobre as suas ocorrências…"
               @keyup.enter="ask()" :disabled="busy" />
        <button class="btn btn-primary d-flex align-items-center gap-1" style="background:#7367f0;border-color:#7367f0" :disabled="busy || !input.trim()" @click="ask()">
          <IconSend :size="16" /> Enviar
        </button>
      </div>

      <!-- sugestões iniciais -->
      <div v-if="messages.length <= 1" class="d-flex flex-wrap gap-1 mt-2">
        <button v-for="s in SUGGESTIONS" :key="s" class="btn btn-sm btn-outline-primary" @click="ask(s)">{{ s }}</button>
      </div>
    </div>
  </div>
</template>