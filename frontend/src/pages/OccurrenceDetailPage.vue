<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  IconPlus, IconRefresh, IconCheck, IconX, IconArrowBackUp, IconUpload, IconMessageCircle,
  IconClipboardList, IconHistory, IconEye, IconTarget, IconFileText, IconTrash, IconPencil,
} from '@tabler/icons-vue'
import IconActionBtn from '@/components/IconActionBtn.vue'
import {
  getOccurrence, listActionsByOccurrence, listComments, addComment, listAudit,
  createAction, completeAction, updateAction, updateOccurrence, validateEffectiveness, reopenOccurrence,
  deleteAction, deleteOccurrence, countOccurrenceDependencies, listAreas, listOrigins,
  listProfiles, type OccurrenceRow,
  copilotoEstadoNc, copilotoProporPlano, copilotoConfirmarPlano, copilotoVerProposta,
  listPlansByOccurrence, createPlan, updatePlan, aprovarPlano, rejeitarPlano, desaprovarPlano, marcarAprovacaoManual, listarHistoricoAprovacao, listWorkLogsByAction, addWorkLog, type CompliancePlan, type WorkLog, type ApprovalEvent,
} from '@/services/occurrences'
import { supabase } from '@/lib/supabase'
import { useAuthStore } from '@/stores/auth'
import {
  occurrenceStatusLabel, occurrenceTypeBadge, occurrenceStatusBadge, actionStatusBadge,
  actionStatusLabel, actionsProgress, formatDate, formatDateTime, deadlineLabel, deadlineTone, initials,
  auditLines, auditActionLabel, auditEntityLabel,
} from '@/utils/format'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()
const id = route.params.id as string

// id inválido (null, 'null', vazio ou não-UUID) → volta para a lista em vez de crashar
const VALID_ID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
if (!id || id === 'null' || !VALID_ID.test(id)) {
  router.replace('/ocorrencias')
}

const occ = ref<OccurrenceRow | null>(null)
const actions = ref<any[]>([])
const comments = ref<any[]>([])
const audit = ref<any[]>([])
const profiles = ref<any[]>([])
const loading = ref(true)
const error = ref('')
const tab = ref<'overview' | 'plano' | 'actions' | 'evidence' | 'effectiveness' | 'comments' | 'history'>('overview')

// ---- Plano de Conformidade (Fase 4/5) ----
const plans = ref<CompliancePlan[]>([])
const workLogsByAction = ref<Record<string, WorkLog[]>>({})
const selectedPlan = ref<CompliancePlan | null>(null)
const showWorkLogAction = ref<string | null>(null)
const workLogForm = ref<{ descricao: string; horas: number; minutos: number; percent_depois: number | null; bloqueio: string; next_step: string }>({ descricao: '', horas: 0, minutos: 0, percent_depois: null, bloqueio: '', next_step: '' })
const planCarregando = ref(false)
const planFormOpen = ref(false)
const planEditando = ref<CompliancePlan | null>(null)
const planForm = ref({
  titulo: '', descricao: '', status: 'RASCUNHO',
  esforco_previsto_h: null as number | null,
  data_inicio: '' as string, data_prevista_fim: '' as string,
  requer_aprovacao: false,
  aprovador_id: '' as string,
})
const salvarPlanMsg = ref('')
const salvarPlanErro = ref('')
const aprovarMsg = ref('')
const aprovarErro = ref('')
const rejeitarMotivo = ref('')
const rejeitarAberto = ref(false)

function nomePerfil(id: string | null | undefined): string {
  if (!id) return '—'
  return profiles.value.find((p) => p.id === id)?.full_name ?? '—'
}
function nomeAprovador(p: CompliancePlan): string {
  if (p.aprovado_por) return nomePerfil(p.aprovado_por)
  if (p.rejeitado_por) return nomePerfil(p.rejeitado_por)
  return nomePerfil(p.aprovador_id)
}
function aguardaAprovacao(p: CompliancePlan): boolean {
  return !!p.requer_aprovacao && !p.aprovado_por && !p.rejeitado_por && !p.aprovado_em && !p.rejeitado_em
}
async function aprovarPlanoAtual(p: CompliancePlan) {
  if (!auth.profile?.id) { aprovarErro.value = 'Sessão sem utilizador.'; return }
  try {
    const papel = p.aprovador_id && auth.profile.id === p.aprovador_id ? 'aprovador' : 'administrador'
    await aprovarPlano(p.id, auth.profile.id, papel)
    aprovarMsg.value = 'Plano aprovado.'
    await carregarPlano()
  } catch (e) { aprovarErro.value = (e as Error).message }
}
async function rejeitarPlanoAtual(p: CompliancePlan) {
  if (!auth.profile?.id) { aprovarErro.value = 'Sessão sem utilizador.'; return }
  try {
    const papel = p.aprovador_id && auth.profile.id === p.aprovador_id ? 'aprovador' : 'administrador'
    await rejeitarPlano(p.id, auth.profile.id, rejeitarMotivo.value.trim(), papel)
    aprovarMsg.value = 'Plano rejeitado — voltou a Rascunho.'
    rejeitarMotivo.value = ''; rejeitarAberto.value = false
    await carregarPlano()
  } catch (e) { aprovarErro.value = (e as Error).message }
}
// ---- Desaprovar (plano já aprovado) + marcação manual + histórico ----
const desaprovMotivo = ref('')
const desaprovAberto = ref(false)
const marcarManual = ref(false)
const historicoAprov = ref<ApprovalEvent[]>([])
const historicoVisivel = ref(false)

async function desaprovarPlanoAtual(p: CompliancePlan) {
  if (!auth.profile?.id) { aprovarErro.value = 'Sessão sem utilizador.'; return }
  try {
    await desaprovarPlano(p.id, auth.profile.id, desaprovMotivo.value.trim(), 'administrador')
    aprovarMsg.value = 'Plano desaprovado — voltou a aguardar aprovação. Motivo registado no histórico.'
    desaprovMotivo.value = ''; desaprovAberto.value = false
    await carregarPlano()
  } catch (e) { aprovarErro.value = (e as Error).message }
}
async function marcarManualAtual(p: CompliancePlan, aprovado: boolean) {
  if (!auth.profile?.id) { aprovarErro.value = 'Sessão sem utilizador.'; return }
  try {
    await marcarAprovacaoManual(p.id, auth.profile.id, aprovado, 'administrador')
    aprovarMsg.value = aprovado ? 'Plano marcado manualmente como aprovado.' : 'Plano marcado manualmente como a aguardar aprovação.'
    marcarManual.value = false
    await carregarPlano()
  } catch (e) { aprovarErro.value = (e as Error).message }
}
async function mostrarHistorico(p: CompliancePlan) {
  try { historicoAprov.value = await listarHistoricoAprovacao(p.id) } catch (e) { aprovarErro.value = (e as Error).message }
}
function acaoLabel(a: string): string {
  return { APROVADO: 'Aprovado', REJEITADO: 'Rejeitado', DESAPROVADO: 'Desaprovado', MARCADO_MANUAL: 'Marcado manualmente' }[a] || a
}

function abrirNovoPlano() {
  planEditando.value = null
  const ref = occ.value?.reference ?? ''
  planForm.value = { titulo: `Plano de Conformidade — ${ref}`, descricao: `Plano para conduzir a ${ref} até à conformidade.`, status: 'RASCUNHO', esforco_previsto_h: null, data_inicio: '', data_prevista_fim: '', requer_aprovacao: false, aprovador_id: '' }
  planFormOpen.value = true
  salvarPlanMsg.value = ''; salvarPlanErro.value = ''
}
function abrirEditarPlano(p: CompliancePlan) {
  planEditando.value = p
  planForm.value = { titulo: p.titulo ?? '', descricao: p.descricao ?? '', status: p.status || 'RASCUNHO', esforco_previsto_h: p.esforco_previsto_h, data_inicio: p.data_inicio ?? '', data_prevista_fim: p.data_prevista_fim ?? '', requer_aprovacao: p.requer_aprovacao ?? false, aprovador_id: p.aprovador_id ?? '' }
  planFormOpen.value = true
  salvarPlanMsg.value = ''; salvarPlanErro.value = ''
}
async function guardarPlanoManual() {
  salvarPlanErro.value = ''
  if (!planForm.value.titulo.trim()) { salvarPlanErro.value = 'Indica um título para o plano.'; return }
  try {
    if (planEditando.value) {
            await updatePlan(planEditando.value.id, {
              titulo: planForm.value.titulo.trim(), descricao: planForm.value.descricao.trim() || null,
              status: planForm.value.status,
              esforco_previsto_h: planForm.value.esforco_previsto_h,
              data_inicio: planForm.value.data_inicio || null, data_prevista_fim: planForm.value.data_prevista_fim || null,
              requer_aprovacao: planForm.value.requer_aprovacao,
              aprovador_id: planForm.value.aprovador_id || null,
            })
            salvarPlanMsg.value = 'Plano de Conformidade atualizado.'
          } else {
            await createPlan(occ.value!.id, {
        titulo: planForm.value.titulo.trim(), descricao: planForm.value.descricao.trim() || null,
        status: planForm.value.status,
        esforco_previsto_h: planForm.value.esforco_previsto_h,
        data_inicio: planForm.value.data_inicio || null, data_prevista_fim: planForm.value.data_prevista_fim || null,
        requer_aprovacao: planForm.value.requer_aprovacao, origem: 'manual',
        aprovador_id: planForm.value.aprovador_id || null,
      })
      salvarPlanMsg.value = 'Plano de Conformidade criado manualmente.'
    }
    planFormOpen.value = false
    await carregarPlano()
  } catch (e) { salvarPlanErro.value = (e as Error).message }
}
async function eliminarPlano(p: CompliancePlan) {
  if (!confirm(`Eliminar o plano "${p.titulo}"?`)) return
  try {
    const { error } = await supabase.from('quality_compliance_plans').delete().eq('id', p.id)
    if (error) throw error
    salvarPlanMsg.value = 'Plano eliminado.'
    await carregarPlano()
  } catch (e) { salvarPlanErro.value = (e as Error).message }
}

async function carregarPlano() {
  planCarregando.value = true
  try {
    plans.value = await listPlansByOccurrence(id)
    selectedPlan.value = plans.value.find((p) => p.status === 'ATIVO' || p.status === 'EM_VALIDACAO') || plans.value[0] || null
    // carrega work logs das ações do plano
    const logs: Record<string, WorkLog[]> = {}
    for (const a of actions.value.filter((x) => x.plano_id)) {
      logs[a.id] = await listWorkLogsByAction(a.id)
    }
    workLogsByAction.value = logs
  } catch (e) { error.value = (e as Error).message }
  finally { planCarregando.value = false }
}

function formatHoras(h: number | null | undefined): string {
  if (h == null) return '—'
  const m = Math.round((Number(h) % 1) * 60)
  return `${Math.floor(Number(h))}h${m ? ` ${m}m` : ''}`
}

async function guardarWorkLog(a: any) { // eslint-disable-line @typescript-eslint/no-explicit-any
  if (!workLogForm.value.descricao.trim() && !workLogForm.value.horas && !workLogForm.value.minutos) return
  const acaoId = showWorkLogAction.value
  if (!acaoId) return
  try {
    const acrescimo = Number(workLogForm.value.horas) + (Number(workLogForm.value.minutos) || 0) / 60
    const patch: Record<string, unknown> = {}
    if (acrescimo) patch.horas_realizadas = Math.round((Number(a.horas_realizadas || 0) + acrescimo) * 100) / 100
    if (workLogForm.value.percent_depois != null) { patch.percent_execucao = Number(workLogForm.value.percent_depois); patch.progresso_origem = 'manual' }
    // persiste na ação (servidor) + regista o work log
    await updateAction(acaoId, patch)
    await addWorkLog({
      action_id: acaoId,
      descricao: workLogForm.value.descricao || null,
      horas: workLogForm.value.horas || 0,
      minutos: workLogForm.value.minutos || 0,
      percent_depois: workLogForm.value.percent_depois,
      bloqueio: workLogForm.value.bloqueio || null,
      next_step: workLogForm.value.next_step || null,
    })
    workLogForm.value = { descricao: '', horas: 0, minutos: 0, percent_depois: null, bloqueio: '', next_step: '' }
    showWorkLogAction.value = null
    await load()
    await carregarPlano()
  } catch (e) { error.value = (e as Error).message }
}

const ACTION_TYPE_PT: Record<string, string> = {
  CONTENCAO: 'Contenção', CORRETIVA: 'Corretiva', PREVENTIVA: 'Preventiva', MELHORIA: 'Melhoria',
  FORMACAO: 'Formação', ALTERACAO_DOCUMENTAL: 'Alteração documental', ALTERACAO_PROCESSO: 'Alteração de processo',
  VERIFICACAO: 'Verificação', VALIDACAO_EFICACIA: 'Validação de eficácia', OUTRA: 'Outra',
}
const PLAN_STATUS_PT: Record<string, string> = {
  RASCUNHO: 'Rascunho', PROPOSTO: 'Proposto', ATIVO: 'Ativo', BLOQUEADO: 'Bloqueado',
  EM_VALIDACAO: 'Em validação', CONCLUIDO: 'Concluído', CANCELADO: 'Cancelado',
}

// formulário de nova ação
const showActionForm = ref(false)
const newAction = ref({ description: '', responsible_user_id: '' as any, deadline: '' })

const progress = computed(() => actionsProgress(actions.value))

async function load() {
  loading.value = true
  error.value = ''
  try {
    const [o, a, c, au, p] = await Promise.all([
      getOccurrence(id), listActionsByOccurrence(id), listComments(id), listAudit('quality_occurrences', id), listProfiles(),
    ])
    occ.value = o; actions.value = a; comments.value = c; audit.value = au; profiles.value = p
    if (a.some((x) => x.plano_id)) carregarPlano()
  } catch (e) {
    error.value = (e as Error).message
  } finally {
    loading.value = false
  }
}

onMounted(load)

async function submitAction() {
  if (!newAction.value.description.trim()) return
  try {
    await createAction({
      occurrence_id: id,
      description: newAction.value.description,
      responsible_user_id: newAction.value.responsible_user_id || null,
      deadline: newAction.value.deadline || null,
    })
    newAction.value = { description: '', responsible_user_id: '', deadline: '' }
    showActionForm.value = false
    await load()
  } catch (e) { error.value = (e as Error).message }
}

async function doComplete(act: any) {
  try { await completeAction(act.id); await load() }
  catch (e) { error.value = (e as Error).message }
}

async function doReopenAction(act: any) {
  try { await updateAction(act.id, { status: 'TODO' as any, completed_at: null }); await load() }
  catch (e) { error.value = (e as Error).message }
}

const confirmDeleteAction = ref<any | null>(null)
async function doDeleteAction() {
  if (!confirmDeleteAction.value) return
  try {
    await deleteAction(confirmDeleteAction.value.id)
    confirmDeleteAction.value = null
    await load()
  } catch (e) { error.value = (e as Error).message }
}

const confirmDelete = ref(false)
const deleting = ref(false)
const deps = ref<{ actions: number; attachments: number; comments: number } | null>(null)
const depsLoaded = ref(false)

async function openDeleteModal() {
  confirmDelete.value = true
  deleting.value = false
  depsLoaded.value = false
  try {
    deps.value = await countOccurrenceDependencies(id)
  } catch {
    deps.value = null
  }
  depsLoaded.value = true
}

const hasDependencies = computed(() => {
  if (!deps.value) return false
  return deps.value.actions > 0 || deps.value.attachments > 0 || deps.value.comments > 0
})

async function doDelete() {
  deleting.value = true
  try {
    await deleteOccurrence(id)
    router.push('/ocorrencias')
  } catch (e) {
    error.value = (e as Error).message
    deleting.value = false
  }
}

// ---------- Edição da ocorrência ----------
const editOpen = ref(false)
const editForm = ref({ origin_id: '', area_id: '', occurrence_date: '', description: '', cause_analysis: '', responsible_user_id: '' as any })
const savingEdit = ref(false)
const areasList = ref<any[]>([])
const originsList = ref<any[]>([])

async function openEdit() {
  if (!occ.value) return
  if (!areasList.value.length || !originsList.value.length) {
    try {
      const [a, o] = await Promise.all([listAreas(), listOrigins()])
      areasList.value = a; originsList.value = o
    } catch {}
  }
  editForm.value = {
    origin_id: occ.value.origin_id,
    area_id: occ.value.area_id,
    occurrence_date: occ.value.occurrence_date?.slice(0, 10) ?? '',
    description: occ.value.description,
    cause_analysis: occ.value.cause_analysis ?? '',
    responsible_user_id: occ.value.responsible_user_id ?? '',
  }
  editOpen.value = true
}

async function saveEdit() {
  savingEdit.value = true
  try {
    await updateOccurrence(id, {
      origin_id: editForm.value.origin_id,
      area_id: editForm.value.area_id,
      occurrence_date: editForm.value.occurrence_date,
      description: editForm.value.description,
      cause_analysis: editForm.value.cause_analysis || null,
      responsible_user_id: editForm.value.responsible_user_id || null,
    })
    editOpen.value = false
    await load()
    error.value = ''
  } catch (e) {
    error.value = (e as Error).message
  } finally {
    savingEdit.value = false
  }
}

// ---------- Edição de ação ----------
const editActionOpen = ref(false)
const editActionForm = ref({ id: '', description: '', responsible_user_id: '' as any, deadline: '' })

function openEditAction(a: any) {
  editActionForm.value = {
    id: a.id, description: a.description,
    responsible_user_id: a.responsible_user_id ?? '',
    deadline: a.deadline?.slice(0, 10) ?? '',
  }
  editActionOpen.value = true
}

async function saveEditAction() {
  try {
    await updateAction(editActionForm.value.id, {
      description: editActionForm.value.description,
      responsible_user_id: editActionForm.value.responsible_user_id || null,
      deadline: editActionForm.value.deadline || null,
    })
    editActionOpen.value = false
    await load()
  } catch (e) { error.value = (e as Error).message }
}

const effResult = ref<'' | 'EFFECTIVE' | 'NOT_EFFECTIVE'>('')
const effNotes = ref('')

async function doValidate() {
  if (!effResult.value) return
  try {
    await validateEffectiveness(id, effResult.value, effNotes.value)
    await load()
    tab.value = 'overview'
  } catch (e) { error.value = (e as Error).message }
}

async function doReopen() {
  if (!confirm('Reabrir esta ocorrência?')) return
  try { await reopenOccurrence(id); await load() }
  catch (e) { error.value = (e as Error).message }
}

async function addCommentText() {
  if (!commentText.value.trim()) return
  try { await addComment(id, commentText.value); commentText.value = ''; await load() }
  catch (e) { error.value = (e as Error).message }
}
const commentText = ref('')

// -------- Upload (evidência) --------
const uploading = ref(false)
async function uploadEvidence(ev: Event) {
  const file = (ev.target as HTMLInputElement).files?.[0]
  if (!file || !occ.value) return
  uploading.value = true
  try {
    const path = `occurrences/${occ.value.id}/${Date.now()}_${file.name}`
    const { error: upErr } = await supabase.storage.from('quality-evidence').upload(path, file)
    if (upErr) throw upErr
    const { error: insErr } = await supabase.from('quality_attachments').insert({
      occurrence_id: occ.value.id, file_name: file.name, file_path: path, file_type: file.type, file_size: file.size,
      uploaded_by: auth.profile?.id ?? null,
    })
    if (insErr) throw insErr
    await load()
  } finally {
    uploading.value = false
    ;(ev.target as HTMLInputElement).value = ''
  }
}

const evidenceFiles = ref<any[]>([])
onMounted(async () => {
  const { data } = await supabase.from('quality_attachments').select('*').eq('occurrence_id', id)
  evidenceFiles.value = (data ?? []) as any[]
})

async function evidenceUrl(path: string): Promise<string> {
  const { data } = await supabase.storage.from('quality-evidence').createSignedUrl(path, 3600)
  return data?.signedUrl ?? ''
}

const statusColor = computed(() => {
  if (!occ.value) return '#7367f0'
  switch (occ.value.status) {
    case 'OPEN': return '#82828f'
    case 'IN_PROGRESS': return '#ff9f43'
    case 'AWAITING_EFFECTIVENESS': return '#00cfe8'
    default: return '#28c76f'
  }
})

// ---- Copiloto de Qualidade (Fase 4) ----
const copiloto = ref<{ estado?: any; proposta?: any; aAnalisar: boolean }>({ aAnalisar: false }) // eslint-disable-line @typescript-eslint/no-explicit-any
const copilotoErro = ref('')
const copilotoOk = ref('')

async function analisarComIa() {
  if (!occ.value) return
  copiloto.value.aAnalisar = true; copilotoErro.value = ''
  try {
    copiloto.value.estado = await copilotoEstadoNc(occ.value.reference)
  } catch (e) { copilotoErro.value = (e as Error).message }
  finally { copiloto.value.aAnalisar = false }
}

async function gerarPlanoComIa() {
  if (!occ.value) return
  copiloto.value.aAnalisar = true; copilotoErro.value = ''
  try {
    copiloto.value.proposta = await copilotoProporPlano(occ.value.reference)
  } catch (e) { copilotoErro.value = (e as Error).message }
  finally { copiloto.value.aAnalisar = false }
}

async function confirmarPropostaIa() {
  if (!copiloto.value.proposta) return
  copiloto.value.aAnalisar = true; copilotoErro.value = ''
  try {
    const r = await copilotoConfirmarPlano()
    if (r) { copiloto.value.proposta = null; copiloto.value.estado = null; copilotoOk.value = 'Plano de Conformidade criado a partir da proposta gerada pela IA.'; load() }
  } catch (e) { copilotoErro.value = (e as Error).message }
  finally { copiloto.value.aAnalisar = false }
}

async function verPropostaPendente() {
  if (!occ.value) return
  try { copiloto.value.proposta = await copilotoVerProposta() } catch (e) { copilotoErro.value = (e as Error).message }
}
</script>

<template>
  <div v-if="loading" class="sq-card"><div class="sq-skeleton" style="height:300px"></div></div>
  <div v-else-if="!occ" class="sq-card sq-empty">Ocorrência não encontrada</div>
  <template v-else>
    <div v-if="error" class="alert alert-danger mb-3">{{ error }}</div>

    <!-- Cabeçalho -->
    <div class="sq-card mb-3">
      <div class="d-flex justify-content-between align-items-start flex-wrap gap-2">
        <div>
          <div class="d-flex align-items-center gap-2 mb-1">
            <span class="sq-ref" style="font-size:1.2rem">{{ occ.reference }}</span>
            <span class="sq-badge" :class="occurrenceTypeBadge(occ.type)">{{ occ.type === 'NC' ? 'Não Conformidade' : 'Oportunidade de Melhoria' }}</span>
            <span class="sq-badge" :class="occurrenceStatusBadge(occ.status)">{{ occurrenceStatusLabel(occ.status) }}</span>
          </div>
          <div class="sq-muted" style="font-size:.85rem">
            {{ occ.quality_origins?.name }} · {{ occ.quality_areas?.name }} ·
            Responsável: {{ occ.profiles?.full_name ?? '—' }} ·
            Data: {{ formatDate(occ.occurrence_date) }} ·
            Criada por {{ occ.created_by ? '' : 'sistema' }} · {{ formatDateTime(occ.created_at) }}
          </div>
        </div>
        <div class="d-flex gap-2">
          <button v-if="auth.canManage" class="btn btn-outline-primary btn-sm d-flex align-items-center gap-1" @click="openEdit">
            <IconPencil :size="15" /> Editar
          </button>
          <button v-if="occ.status === 'CLOSED' && auth.canManage" class="btn btn-outline-warning btn-sm d-flex align-items-center gap-1" @click="doReopen">
            <IconArrowBackUp :size="15" /> Reabrir
          </button>
          <button v-if="auth.canManage" class="btn btn-outline-danger btn-sm d-flex align-items-center gap-1" @click="openDeleteModal">
            <IconTrash :size="15" /> Eliminar
          </button>
        </div>
      </div>
      <div class="mt-2 sq-progress" style="max-width:340px"><span :style="{ width: progress.pct + '%' }"></span></div>
      <div class="sq-muted mt-1" style="font-size:.8rem">{{ progress.total ? progress.label + ' · ' + progress.pct + '%' : 'Sem ações' }}</div>
    </div>

    <!-- Tabs -->
    <div class="sq-tabs">
      <button class="sq-tab" :class="{active:tab==='overview'}" @click="tab='overview'"><IconEye :size="15" class="me-1 align-text-bottom"/>Visão Geral</button>
      <button class="sq-tab" :class="{active:tab==='plano'}" @click="tab='plano';carregarPlano()"><IconTarget :size="15" class="me-1 align-text-bottom"/>Plano de Conformidade</button>
      <button class="sq-tab" :class="{active:tab==='actions'}" @click="tab='actions'"><IconClipboardList :size="15" class="me-1 align-text-bottom"/>Plano de Ações</button>
      <button class="sq-tab" :class="{active:tab==='evidence'}" @click="tab='evidence'"><IconFileText :size="15" class="me-1 align-text-bottom"/>Evidências</button>
      <button class="sq-tab" :class="{active:tab==='effectiveness'}" @click="tab='effectiveness'"><IconTarget :size="15" class="me-1 align-text-bottom"/>Eficácia</button>
      <button class="sq-tab" :class="{active:tab==='comments'}" @click="tab='comments'"><IconMessageCircle :size="15" class="me-1 align-text-bottom"/>Comentários</button>
      <button class="sq-tab" :class="{active:tab==='history'}" @click="tab='history'"><IconHistory :size="15" class="me-1 align-text-bottom"/>Histórico</button>
    </div>

    <!-- Copiloto de Qualidade -->
    <div class="sq-card mb-3" style="border-left:4px solid #7367f0">
      <div class="d-flex justify-content-between align-items-center flex-wrap gap-2">
        <div>
          <span class="fw-semibold" style="color:#7367f0">🤖 Copiloto de Qualidade</span>
          <span class="sq-muted ms-2" style="font-size:.75rem">Análise assistiva — nunca cria sozinho; propõe e aguarda a tua confirmação.</span>
        </div>
        <div class="d-flex gap-2">
          <button class="btn btn-sm btn-outline-primary" :disabled="copiloto.aAnalisar || occ.status==='CLOSED'" @click="analisarComIa" title="Estado operacional, plano, ações e condições de encerramento">
            <IconEye :size="14" class="me-1" />{{ copiloto.aAnalisar ? 'A analisar…' : 'Analisar com IA' }}
          </button>
          <button class="btn btn-sm" style="background:#7367f0;color:#fff" :disabled="copiloto.aAnalisar || occ.status==='CLOSED' || !!copiloto.proposta" @click="gerarPlanoComIa" title="Gera um rascunho de Plano de Conformidade (não persiste)">
            <IconTarget :size="14" class="me-1" />Gerar Plano com IA
          </button>
        </div>
      </div>
      <div v-if="copilotoErro" class="alert alert-danger py-1 px-2 mt-2 mb-0" style="font-size:.8rem">{{ copilotoErro }}</div>
      <div v-if="copilotoOk" class="alert alert-success py-1 px-2 mt-2 mb-0" style="font-size:.8rem">{{ copilotoOk }}</div>

      <!-- Resultado da análise -->
      <div v-if="copiloto.estado" class="mt-3" style="font-size:.85rem">
        <div v-if="copiloto.estado.plano" class="d-flex align-items-center gap-2 mb-2">
          <span class="badge" style="background:#7367f0">{{ copiloto.estado.plano.status }}</span>
          <span class="fw-semibold">{{ copiloto.estado.plano.titulo }}</span>
          <span class="sq-muted">progresso {{ copiloto.estado.plano.progresso }}%</span>
        </div>
        <div v-else class="sq-muted mb-2">Sem Plano de Conformidade ativo.</div>
        <div v-if="copiloto.estado.ações?.length" class="mb-2">
          <div class="fw-semibold mb-1">Ações ({{ copiloto.estado.ações.length }}):</div>
          <div v-for="a in copiloto.estado.ações.slice(0,8)" :key="a.ref" class="d-flex align-items-center gap-2 mb-1">
            <span class="badge bg-light text-dark">{{ a.ref }}</span>
            <span class="text-truncate" style="max-width:280px">{{ a.título }}</span>
            <span class="badge" :class="a.estado==='COMPLETED'?'bg-success':'bg-secondary'">{{ a.progresso }}%</span>
          </div>
        </div>
        <!-- Condições de encerramento -->
        <div class="p-2 rounded" style="background:rgba(115,103,240,.08)">
          <div class="fw-semibold mb-1" style="color:#7367f0">Encerramento</div>
          <template v-if="copiloto.estado.encerramento?.ok">
            <span class="text-success">✔ {{ copiloto.estado.encerramento.motivo }}</span>
          </template>
          <template v-else>
            <span class="text-danger">✘ {{ copiloto.estado.encerramento?.motivo }}</span>
            <ul v-if="copiloto.estado.encerramento?.pendentes?.length" class="mb-0 mt-1 ps-3" style="font-size:.8rem">
              <li v-for="(p,i) in copiloto.estado.encerramento.pendentes" :key="i">{{ p }}</li>
            </ul>
          </template>
        </div>
      </div>

      <!-- Proposta de plano gerada pela IA (aguarda confirmação) -->
      <div v-if="copiloto.proposta" class="mt-3 p-2 rounded" style="background:#fff7ed;border:1px solid #fed7aa">
        <div class="fw-semibold mb-1" style="color:#c2410c">📝 Proposta gerada pela IA <span class="badge bg-warning text-dark ms-1">aguarda confirmação</span></div>
        <div style="font-size:.85rem">
          <div class="fw-semibold">{{ copiloto.proposta.proposta?.titulo || copiloto.proposta.titulo }}</div>
          <div v-if="copiloto.proposta.ambiguidade" class="text-danger mb-1" style="font-size:.8rem">⚠️ Responsável ambíguo: {{ (copiloto.proposta.ambiguidade.candidatos||[]).join(', ') }} — precisa indicar qual.</div>
          <div class="mb-1"><b>{{ (copiloto.proposta.proposta?.acoes||copiloto.proposta.acoes||[]).length }} ação(ões) proposta(s):</b></div>
          <div v-for="a in (copiloto.proposta.proposta?.acoes||copiloto.proposta.acoes||[]).slice(0,6)" :key="a.titulo" class="ms-2">• {{ a.titulo }} <span class="badge bg-light text-dark ms-1">{{ a.tipo }}</span></div>
          <div class="mt-2 d-flex gap-2">
            <button class="btn btn-sm" style="background:#7367f0;color:#fff" :disabled="copiloto.aAnalisar" @click="confirmarPropostaIa">✔ Confirmar e criar plano</button>
            <button class="btn btn-sm btn-outline-secondary" :disabled="copiloto.aAnalisar" @click="copiloto.proposta=null">Cancelar</button>
          </div>
        </div>
      </div>
    </div>

    <!-- Visão Geral -->
    <div v-if="tab==='overview'" class="sq-card">
      <h6 class="sq-card-title">Descrição</h6>
      <p style="white-space:pre-wrap">{{ occ.description }}</p>
      <h6 class="sq-card-title mt-3">Análise / Causa</h6>
      <p class="sq-muted">{{ occ.cause_analysis || 'Sem análise de causa registada.' }}</p>
    </div>

    <!-- Plano de Conformidade -->
    <div v-if="tab==='plano'" class="sq-card">
      <div class="d-flex justify-content-between align-items-center flex-wrap gap-2 mb-3">
        <h6 class="sq-card-title mb-0">Plano de Conformidade</h6>
        <div v-if="auth.canManage" class="d-flex gap-2">
          <button v-if="plans.length" class="btn btn-sm btn-outline-primary d-inline-flex align-items-center gap-1" @click="abrirEditarPlano(selectedPlan!)">
            <IconPencil :size="14" /> Editar plano
          </button>
          <button v-if="!plans.length" class="btn btn-sm btn-primary d-inline-flex align-items-center gap-1" style="background:#7367f0;border-color:#7367f0" @click="abrirNovoPlano">
            <IconPlus :size="14" /> Criar plano
          </button>
        </div>
      </div>

      <!-- Form manual de criar/editar plano -->
      <div v-if="planFormOpen" class="card border mb-3 p-3" style="background:#f8f9fc">
        <h6 class="fw-semibold mb-2">{{ planEditando ? 'Editar plano' : 'Criar plano manualmente' }}</h6>
        <div class="row g-2">
          <div class="col-12"><input v-model="planForm.titulo" class="form-control form-control-sm" placeholder="Título do plano" /></div>
          <div class="col-12"><textarea v-model="planForm.descricao" class="form-control form-control-sm" rows="2" placeholder="Descrição / objetivo"></textarea></div>
          <div class="col-md-4">
            <select v-model="planForm.status" class="form-select form-select-sm">
              <option value="RASCUNHO">Rascunho</option>
              <option value="PROPOSTO">Proposto</option>
              <option value="ATIVO">Ativo</option>
              <option value="BLOQUEADO">Bloqueado</option>
              <option value="EM_VALIDACAO">Em validação</option>
            </select>
          </div>
          <div class="col-md-4"><input v-model.number="planForm.esforco_previsto_h" type="number" min="0" step="0.5" class="form-control form-control-sm" placeholder="Esforço previsto (h)" /></div>
          <div class="col-md-4"><label class="d-flex align-items-center gap-2 form-check form-switch" style="padding-top:.3rem"><input v-model="planForm.requer_aprovacao" type="checkbox" class="form-check-input" /> Requer aprovação</label></div>
          <div class="col-md-8">
            <label class="sq-muted small d-block">Quem aprova (aprovador designado)</label>
            <select v-model="planForm.aprovador_id" class="form-select form-select-sm" :disabled="!planForm.requer_aprovacao">
              <option value="">— Sem aprovador designado —</option>
              <option v-for="p in profiles" :key="p.id" :value="p.id">{{ p.full_name }}</option>
            </select>
          </div>
          <div class="col-md-6"><label class="sq-muted small d-block">Início</label><PtDateInput v-model="planForm.data_inicio" type="date" class="form-control form-control-sm" /></div>
          <div class="col-md-6"><label class="sq-muted small d-block">Fim previsto</label><PtDateInput v-model="planForm.data_prevista_fim" type="date" class="form-control form-control-sm" /></div>
          <div class="col-12 d-flex gap-2 mt-2">
            <button class="btn btn-sm btn-primary" style="background:#7367f0;border-color:#7367f0" @click="guardarPlanoManual" :disabled="planCarregando">
              <IconCheck :size="14" class="me-1" /> {{ planEditando ? 'Guardar alterações' : 'Criar plano' }}
            </button>
            <button class="btn btn-sm btn-outline-secondary" @click="planFormOpen=false">Cancelar</button>
          </div>
          <div v-if="salvarPlanErro" class="col-12 text-danger small mt-1">{{ salvarPlanErro }}</div>
        </div>
      </div>
      <div v-if="salvarPlanMsg" class="alert alert-success py-2 small mb-3"><IconCheck :size="15" class="me-1" /> {{ salvarPlanMsg }}</div>

      <div v-if="planCarregando" class="sq-muted">A carregar plano…</div>
      <div v-else-if="!plans.length" class="sq-empty">Sem Plano de Conformidade para esta ocorrência.
        <span class="sq-muted">Usa "Criar plano" para criar manualmente ou "Gerar Plano com IA" no topo para uma proposta assistida.</span>
      </div>
      <template v-else-if="selectedPlan">
        <div class="d-flex justify-content-between align-items-center flex-wrap gap-2 mb-2">
          <div>
            <span class="badge" style="background:#7367f0">{{ PLAN_STATUS_PT[selectedPlan.status] || selectedPlan.status }}</span>
            <span class="fw-semibold ms-2">{{ selectedPlan.titulo }}</span>
            <span v-if="selectedPlan.sugerido_por_ia" class="badge bg-warning text-dark ms-1">gerado por IA</span>
            <span v-else class="badge bg-light text-dark ms-1">manual</span>
          </div>
          <div class="d-flex align-items-center gap-2">
            <span class="sq-muted" style="font-size:.8rem">
              {{ formatHoras(selectedPlan.esforco_real_h) }} / {{ formatHoras(selectedPlan.esforco_previsto_h) }}h
            </span>
            <div class="progress" style="width:180px;height:10px"><div class="progress-bar" :style="{width: selectedPlan.progresso+'%', background:'#7367f0'}"></div></div>
            <span class="fw-semibold" style="color:#7367f0">{{ selectedPlan.progresso }}%</span>
            <button v-if="auth.canManage" class="btn btn-sm btn-outline-danger" title="Eliminar plano" @click="eliminarPlano(selectedPlan)"><IconTrash :size="14" /></button>
          </div>
        </div>
        <p class="sq-muted">{{ selectedPlan.descricao }}</p>

        <!-- Fluxo de aprovação -->
        <div v-if="selectedPlan.requer_aprovacao && !selectedPlan.aprovado_por && !selectedPlan.rejeitado_por" class="alert alert-warning py-2 small mb-3 rounded">
          <div class="d-flex align-items-center justify-content-between flex-wrap gap-2">
            <span class="d-flex align-items-center gap-2"><b>🔒 Aguarda aprovação</b> · aprovador designado: <b>{{ nomePerfil(selectedPlan.aprovador_id) }}</b></span>
            <!-- Aprovador designado: botões normais -->
            <span v-if="auth.profile?.id === selectedPlan.aprovador_id" class="d-flex gap-2">
              <button class="btn btn-sm btn-success d-inline-flex align-items-center gap-1" @click="aprovarPlanoAtual(selectedPlan)"><IconCheck :size="14" /> Aprovar</button>
              <button class="btn btn-sm btn-outline-danger" @click="rejeitarAberto=!rejeitarAberto">Rejeitar</button>
            </span>
            <!-- Administrador/Sistema que não é o aprovador designado: botão distinto -->
            <span v-else-if="auth.canManage" class="d-flex gap-2">
              <button class="btn btn-sm d-inline-flex align-items-center gap-1" title="O plano está designado para {{ nomePerfil(selectedPlan.aprovador_id) }}, mas o administrador pode validar em nome do sistema" style="background:#6f42c1;color:#fff;border-color:#6f42c1" @click="aprovarPlanoAtual(selectedPlan)"><IconCheck :size="14" /> Aprovar como administrador</button>
              <button class="btn btn-sm btn-outline-danger" title="Rejeitar como administrador" @click="rejeitarAberto=!rejeitarAberto">Rejeitar como administrador</button>
              <button class="btn btn-sm btn-outline-secondary" title="Marcar manualmente o estado de aprovação" @click="marcarManual=!marcarManual; desaprovAberto=false; rejeitarAberto=false">Marcar manualmente</button>
            </span>
            <span v-else class="d-flex gap-2">
              <button class="btn btn-sm btn-outline-secondary" title="Marcar manualmente o estado de aprovação" @click="marcarManual=!marcarManual; desaprovAberto=false; rejeitarAberto=false">Marcar manualmente</button>
            </span>
          </div>
        </div>
        <div v-else-if="selectedPlan.aprovado_por" class="alert alert-success py-2 small mb-2 rounded">
          <div class="d-flex align-items-center justify-content-between flex-wrap gap-2">
            <span class="d-flex align-items-center gap-2">
              <b>✓ Aprovado por {{ nomePerfil(selectedPlan.aprovado_por) }}</b>
              <span class="sq-muted">{{ selectedPlan.aprovado_em ? ' em ' + formatDateTime(selectedPlan.aprovado_em) : '' }}</span>
              <span v-if="selectedPlan.aprovador_id && selectedPlan.aprovado_por !== selectedPlan.aprovador_id" class="badge" style="background:#eef0ff;color:#4a4587">aprovado como administrador</span>
            </span>
            <span v-if="auth.canManage || auth.profile?.id === selectedPlan.aprovador_id" class="d-flex gap-2">
              <button class="btn btn-sm btn-warning fw-semibold d-inline-flex align-items-center gap-1" title="Desaprovar o plano, registando o motivo no histórico" @click="desaprovAberto=!desaprovAberto">Desaprovar</button>
              <button class="btn btn-sm btn-outline-secondary" @click="marcarManual=!marcarManual; desaprovAberto=false">Marcar manualmente</button>
            </span>
          </div>
        </div>
        <div v-if="desaprovAberto" class="card border mb-2 p-2">
          <div class="row g-2 align-items-end">
            <div class="col"><textarea v-model="desaprovMotivo" class="form-control form-control-sm" rows="2" placeholder="Motivo da desaprovação (fica no histórico)"></textarea></div>
            <div class="col-auto"><button class="btn btn-sm btn-warning fw-semibold" @click="desaprovarPlanoAtual(selectedPlan)" :disabled="!desaprovMotivo.trim()"><IconX :size="14" class="me-1" /> Confirmar desaprovação</button></div>
          </div>
        </div>
        <div v-if="marcarManual" class="card border mb-2 p-2">
          <div class="d-flex align-items-center gap-2 flex-wrap" style="font-size:.8rem">
            <span class="fw-semibold">Marcar manualmente o estado de aprovação:</span>
            <button class="btn btn-sm btn-success d-inline-flex align-items-center gap-1" @click="marcarManualAtual(selectedPlan, true)"><IconCheck :size="14" /> Aprovado</button>
            <button class="btn btn-sm btn-outline-danger" @click="marcarManualAtual(selectedPlan, false)">Aguarda aprovação</button>
          </div>
        </div>
        <div class="mb-2">
          <button class="btn btn-sm btn-link p-0" @click="mostrarHistorico(selectedPlan); historicoVisivel = !historicoVisivel"><IconHistory :size="14" class="me-1" /> {{ historicoVisivel ? 'Ocultar' : 'Ver' }} histórico de aprovação</button>
          <div v-if="historicoVisivel && historicoAprov.length" class="border rounded p-2 mt-1" style="background:#f8f9fc;font-size:.78rem">
            <div v-for="h in historicoAprov" :key="h.id" class="d-flex align-items-start gap-2 py-1">
              <span class="badge" :class="h.acao==='APROVADO'?'bg-success':h.acao==='REJEITADO'||h.acao==='DESAPROVADO'?'bg-danger':'bg-secondary'">{{ acaoLabel(h.acao) }}</span>
              <span>{{ h.profiles?.full_name || nomePerfil(h.decidido_por) }}</span>
              <span class="sq-muted">{{ formatDateTime(h.decidido_em) }}</span>
              <span v-if="h.papel" class="sq-muted">({{ h.papel }})</span>
              <span v-if="h.motivo" class="sq-muted">— {{ h.motivo }}</span>
            </div>
            <div v-if="!historicoAprov.length" class="sq-muted">Sem registos de aprovação.</div>
          </div>
        </div>
        <div v-if="selectedPlan.rejeitado_por" class="alert alert-danger py-2 small mb-3 rounded">
          <b>✕ Rejeitado por {{ nomePerfil(selectedPlan.rejeitado_por) }}</b>
          <span v-if="selectedPlan.rejeitado_em" class="sq-muted"> em {{ formatDateTime(selectedPlan.rejeitado_em) }}</span>
          <span v-if="selectedPlan.motivo_rejeicao" class="d-block sq-muted">Motivo: {{ selectedPlan.motivo_rejeicao }}</span>
        </div>
        <div v-if="rejeitarAberto" class="card border mb-3 p-2">
          <div class="row g-2 align-items-end">
            <div class="col"><textarea v-model="rejeitarMotivo" class="form-control form-control-sm" rows="2" placeholder="Motivo da rejeição (obrigatório)"></textarea></div>
            <div class="col-auto"><button class="btn btn-sm btn-danger" @click="rejeitarPlanoAtual(selectedPlan)" :disabled="!rejeitarMotivo.trim()"><IconX :size="14" class="me-1" /> Confirmar rejeição</button></div>
          </div>
        </div>
        <div v-if="aprovarMsg" class="alert alert-success py-2 small mb-3"><IconCheck :size="15" class="me-1" /> {{ aprovarMsg }}</div>
        <div v-if="aprovarErro" class="alert alert-danger py-2 small mb-3">{{ aprovarErro }}</div>

        <!-- Ações do plano -->
        <div class="fw-semibold mb-2">Ações do plano</div>
        <div v-if="!actions.filter(x=>x.plano_id).length" class="sq-empty sq-muted" style="padding:.6rem">Sem ações associadas — usa o separador "Plano de Ações" para adicionar e depois liga-as ao plano.</div>
        <div v-for="a in actions.filter(x=>x.plano_id)" :key="a.id" class="border rounded p-2 mb-2">
          <div class="d-flex justify-content-between align-items-center flex-wrap gap-2">
            <div class="d-flex align-items-center gap-2">
              <span class="badge bg-light text-dark">{{ a.reference }}</span>
              <span v-if="a.tipo" class="badge" style="background:#f0eeff;color:#4a4587">{{ ACTION_TYPE_PT[a.tipo] || a.tipo }}</span>
              <span class="fw-medium">{{ a.titulo || a.description }}</span>
            </div>
            <div class="d-flex align-items-center gap-2">
              <span v-if="a.deadline" class="sq-muted" style="font-size:.75rem">prazo {{ formatDate(a.deadline) }}</span>
              <span class="badge" :class="a.status==='COMPLETED'?'bg-success':a.status==='BLOCKED'?'bg-danger':'bg-secondary'">{{ actionStatusLabel(a.status) }}</span>
              <span style="font-size:.8rem"><b>{{ a.percent_execucao }}%</b></span>
              <span class="sq-muted" style="font-size:.75rem">{{ formatHoras(a.horas_realizadas) }}/{{ formatHoras(a.horas_previstas) }}h</span>
              <button class="btn btn-sm btn-outline-primary" @click="showWorkLogAction = showWorkLogAction===a.id?null:a.id">Registo de trabalho</button>
            </div>
          </div>
          <div v-if="a.bloqueio_motivo" class="text-danger mt-1" style="font-size:.8rem">⛔ Bloqueada: {{ a.bloqueio_motivo }}</div>

          <!-- Work log form -->
          <div v-if="showWorkLogAction===a.id" class="mt-2 p-2" style="background:#f8f9fc;border-radius:.4rem">
            <div class="row g-2">
              <div class="col-12"><input class="form-control form-control-sm" placeholder="Trabalho realizado" v-model="workLogForm.descricao" /></div>
              <div class="col-3"><input class="form-control form-control-sm" type="number" min="0" step="0.5" placeholder="Horas" v-model.number="workLogForm.horas" /></div>
              <div class="col-3"><input class="form-control form-control-sm" type="number" min="0" placeholder="Min" v-model.number="workLogForm.minutos" /></div>
              <div class="col-3"><input class="form-control form-control-sm" type="number" min="0" max="100" placeholder="% agora" v-model.number="workLogForm.percent_depois" /></div>
              <div class="col-3"><button class="btn btn-sm btn-primary w-100" @click="guardarWorkLog(a)">Guardar</button></div>
            </div>
          </div>

          <!-- work logs registados -->
          <div v-if="workLogsByAction[a.id]?.length" class="mt-2">
            <div v-for="w in workLogsByAction[a.id]" :key="w.id" class="d-flex align-items-start gap-2" style="font-size:.78rem">
              <span class="sq-muted">{{ formatDateTime(w.created_at) }}</span>
              <span>{{ w.descricao || '—' }}</span>
              <span class="badge bg-light text-dark">{{ formatHoras(w.horas) }}</span>
              <span v-if="w.percent_depois!=null" class="sq-muted">→ {{ w.percent_depois }}%</span>
            </div>
          </div>
        </div>
      </template>
    </div>

    <!-- Plano de Ações -->
    <div v-if="tab==='actions'" class="sq-card">
      <div class="d-flex justify-content-between align-items-center mb-3">
        <h6 class="sq-card-title mb-0">{{ progress.label }} · {{ progress.pct }}%</h6>
        <button v-if="auth.canManage || auth.role==='action_owner'" class="btn btn-primary btn-sm d-flex align-items-center gap-1" style="background:#7367f0;border-color:#7367f0" @click="showActionForm=!showActionForm">
          <IconPlus :size="15" /> Nova ação
        </button>
      </div>

      <div v-if="showActionForm" class="card border mb-3 p-3">
        <div class="row g-2">
          <div class="col-12"><textarea v-model="newAction.description" class="form-control" rows="2" placeholder="Descrição da ação"></textarea></div>
          <div class="col-md-6">
            <select v-model="newAction.responsible_user_id" class="form-select">
              <option :value="''">Sem responsável</option>
              <option v-for="p in profiles" :value="p.id" :key="p.id">{{ p.full_name }}</option>
            </select>
          </div>
          <div class="col-md-4"><PtDateInput v-model="newAction.deadline" type="date" class="form-control" /></div>
          <div class="col-md-2"><button class="btn btn-success w-100" @click="submitAction">Guardar</button></div>
        </div>
      </div>

      <table class="sq-table">
        <thead><tr><th>Ref</th><th>Descrição</th><th>Responsável</th><th>Prazo</th><th>Estado</th><th style="width:110px;min-width:110px;text-align:center">Ações</th></tr></thead>
        <tbody>
          <tr v-for="a in actions" :key="a.id">
            <td class="sq-ref">{{ a.reference }}</td>
            <td>{{ a.description }}</td>
            <td>{{ a.profiles?.full_name ?? '—' }}</td>
            <td>
              <span class="sq-badge" :class="deadlineTone(a.deadline, a.status==='COMPLETED') === 'overdue' ? 'badge-soft-danger' : deadlineTone(a.deadline, a.status==='COMPLETED') === 'today' ? 'badge-soft-warning' : a.status==='COMPLETED' ? 'badge-soft-success' : 'badge-soft-secondary'">
                {{ deadlineLabel(a.deadline, a.status==='COMPLETED') }}
              </span>
            </td>
            <td><span class="sq-badge" :class="actionStatusBadge(a.status)">{{ actionStatusLabel(a.status) }}</span></td>
            <td style="width:110px;min-width:110px;text-align:center;overflow:visible">
              <div class="d-inline-flex gap-1" style="overflow:visible">
                <IconActionBtn v-if="auth.canManage" icon="pencil" variant="primary" label="Editar ação" tip="top" @click="openEditAction(a)"/>
                <IconActionBtn v-if="a.status !== 'COMPLETED' && (auth.role==='action_owner' || auth.canManage)" icon="check" variant="success" label="Concluir" tip="top" @click="doComplete(a)"/>
                <IconActionBtn v-if="a.status === 'COMPLETED' && auth.canManage" icon="refresh" variant="secondary" label="Reabrir ação" tip="top" @click="doReopenAction(a)"/>
                <IconActionBtn v-if="auth.canManage" icon="trash" variant="danger" label="Eliminar ação" tip="top" @click="confirmDeleteAction = a"/>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
      <div v-if="!actions.length" class="sq-empty">
        <p class="mb-1 fw-semibold" style="color:var(--sq-heading)">Ainda não existem ações</p>
        <p class="sq-muted" style="font-size:.85rem">Cria a primeira ação para iniciar o tratamento desta ocorrência.</p>
      </div>
    </div>

    <!-- Evidências -->
    <div v-if="tab==='evidence'" class="sq-card">
      <div class="d-flex justify-content-between align-items-center mb-3">
        <h6 class="sq-card-title mb-0">Evidências</h6>
        <label class="btn btn-primary btn-sm d-flex align-items-center gap-1" style="background:#7367f0;border-color:#7367f0;cursor:pointer">
          <IconUpload :size="15" /> {{ uploading ? 'A enviar…' : 'Enviar ficheiro' }}
          <input type="file" style="display:none" :disabled="uploading" @change="uploadEvidence" />
        </label>
      </div>
      <table class="sq-table">
        <thead><tr><th>Ficheiro</th><th>Tipo</th><th>Tamanho</th><th>Enviado</th></tr></thead>
        <tbody>
          <tr v-for="f in evidenceFiles" :key="f.id">
            <td class="sq-ref">{{ f.file_name }}</td>
            <td class="sq-muted">{{ f.file_type || '—' }}</td>
            <td class="sq-muted">{{ (f.file_size / 1024).toFixed(0) }} KB</td>
            <td class="sq-muted">{{ formatDateTime(f.created_at) }}</td>
          </tr>
        </tbody>
      </table>
      <div v-if="!evidenceFiles.length" class="sq-empty">Sem evidências anexadas.</div>
    </div>

    <!-- Eficácia -->
    <div v-if="tab==='effectiveness'" class="sq-card">
      <div v-if="occ.status === 'AWAITING_EFFECTIVENESS'" class="alert alert-info d-flex align-items-center gap-2">
        <IconTarget :size="18" /> Validação da eficácia necessária — todas as ações estão concluídas.
      </div>

      <div v-if="occ.effectiveness_status" class="mb-3">
        <h6 class="sq-card-title">Resultado da validação</h6>
        <p>
          <span class="sq-badge" :class="occ.effectiveness_status==='EFFECTIVE' ? 'badge-soft-success' : 'badge-soft-danger'">
            {{ occ.effectiveness_status === 'EFFECTIVE' ? 'Eficaz' : 'Não eficaz' }}
          </span>
        </p>
        <p style="white-space:pre-wrap">{{ occ.effectiveness_notes }}</p>
        <p class="sq-muted" style="font-size:.85rem">
          Validado por {{ occ.effectiveness_validated_by ? 'utilizador' : '—' }} · {{ formatDateTime(occ.effectiveness_validated_at) }}
        </p>
      </div>

      <div v-if="occ.status === 'AWAITING_EFFECTIVENESS' && auth.canValidateEffectiveness" class="border rounded p-3">
        <h6 class="sq-card-title">Validar e encerrar</h6>
        <select v-model="effResult" class="form-select mb-2">
          <option value="">— Seleciona o resultado —</option>
          <option value="EFFECTIVE">Eficaz</option>
          <option value="NOT_EFFECTIVE">Não eficaz</option>
        </select>
        <textarea v-model="effNotes" class="form-control mb-2" rows="2" placeholder="Observações"></textarea>
        <button class="btn btn-success" @click="doValidate" :disabled="!effResult">
          <IconCheck :size="15" class="me-1 align-text-bottom" /> Validar eficácia e encerrar
        </button>
      </div>

      <div v-if="occ.status !== 'AWAITING_EFFECTIVENESS'">
        <p class="sq-muted">A validação de eficácia fica disponível quando todas as ações estiverem concluídas.</p>
      </div>
    </div>

    <!-- Comentários -->
    <div v-if="tab==='comments'" class="sq-card">
      <div class="d-flex gap-2 mb-3">
        <input v-model="commentText" class="form-control" placeholder="Escreve um comentário…" @keyup.enter="addCommentText" />
        <button class="btn btn-primary" style="background:#7367f0;border-color:#7367f0" @click="addCommentText">Enviar</button>
      </div>
      <ul class="sq-timeline">
        <li v-for="c in comments" :key="c.id">
          <span class="sq-tl-dot"></span>
          <div class="d-flex gap-2 align-items-center mb-1">
            <span class="sq-avatar" style="width:26px;height:26px;font-size:.65rem">{{ initials(c.profiles?.full_name) }}</span>
            <span class="fw-semibold" style="font-size:.85rem;color:var(--sq-heading)">{{ c.profiles?.full_name ?? 'Utilizador' }}</span>
            <span class="sq-muted" style="font-size:.75rem">{{ formatDateTime(c.created_at) }}</span>
          </div>
          <p style="white-space:pre-wrap">{{ c.comment }}</p>
        </li>
      </ul>
      <div v-if="!comments.length" class="sq-empty">Sem comentários.</div>
    </div>

    <!-- Histórico (leitura humana, nunca JSON bruto) -->
    <div v-if="tab==='history'" class="sq-card">
      <ul class="sq-timeline">
        <li v-for="h in audit" :key="h.id">
          <span class="sq-tl-dot"></span>
          <div class="d-flex align-items-center gap-2 flex-wrap">
            <span class="fw-semibold" style="color:var(--sq-heading)">{{ auditActionLabel(h.action) }}</span>
            <span class="sq-badge badge-soft-secondary">{{ auditEntityLabel(h.entity_type) }}</span>
          </div>
          <div class="sq-muted" style="font-size:.8rem;margin-bottom:.4rem">
            <span class="sq-avatar" style="width:22px;height:22px;font-size:.6rem;display:inline-grid;vertical-align:middle">{{ initials(h.profiles?.full_name) }}</span>
            {{ h.profiles?.full_name || 'Sistema' }} · {{ formatDateTime(h.created_at) }}
          </div>
          <div v-if="auditLines(h.changed_fields).length" style="background:var(--sq-bg);border:1px solid var(--sq-border);border-radius:.4rem;padding:.6rem .8rem">
            <div v-for="l in auditLines(h.changed_fields)" :key="l.field" class="d-flex gap-2 align-items-baseline" style="font-size:.84rem">
              <span class="sq-muted" style="min-width:140px">{{ l.field }}:</span>
              <span>{{ l.from || '—' }}</span>
              <IconArrowBackUp :size="13" class="sq-muted" />
              <span class="fw-semibold" style="color:var(--sq-heading)">{{ l.to || '—' }}</span>
            </div>
          </div>
        </li>
      </ul>
      <div v-if="!audit.length" class="sq-empty">Sem histórico de alterações.</div>
    </div>

    <!-- Modal de edição da ocorrência -->
    <div v-if="editOpen" class="modal d-block" tabindex="-1" style="background:rgba(0,0,0,.45)">
      <div class="modal-dialog modal-dialog-centered modal-lg">
        <div class="modal-content" style="border-radius:.75rem">
          <div class="modal-header">
            <h5 class="modal-title">Editar ocorrência {{ occ?.reference }}</h5>
            <button type="button" class="btn-close" @click="editOpen = false"></button>
          </div>
          <div class="modal-body">
            <div class="row g-3">
              <div class="col-md-6">
                <label class="form-label">Origem</label>
                <select v-model="editForm.origin_id" class="form-select">
                  <option v-for="o in originsList" :value="o.id" :key="o.id">{{ o.name }}</option>
                </select>
              </div>
              <div class="col-md-6">
                <label class="form-label">Área / Processo</label>
                <select v-model="editForm.area_id" class="form-select">
                  <option v-for="a in areasList" :value="a.id" :key="a.id">{{ a.name }}</option>
                </select>
              </div>
              <div class="col-md-6">
                <label class="form-label">Data</label>
                <PtDateInput v-model="editForm.occurrence_date" type="date" class="form-control" />
              </div>
              <div class="col-md-6">
                <label class="form-label">Responsável</label>
                <select v-model="editForm.responsible_user_id" class="form-select">
                  <option :value="''">Sem responsável</option>
                  <option v-for="p in profiles" :value="p.id" :key="p.id">{{ p.full_name }}</option>
                </select>
              </div>
              <div class="col-12">
                <label class="form-label">Descrição</label>
                <textarea v-model="editForm.description" class="form-control" rows="3"></textarea>
              </div>
              <div class="col-12">
                <label class="form-label">Análise / Causa</label>
                <textarea v-model="editForm.cause_analysis" class="form-control" rows="2"></textarea>
              </div>
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-outline-secondary" @click="editOpen = false">Cancelar</button>
            <button class="btn btn-primary" style="background:#7367f0;border-color:#7367f0" :disabled="savingEdit" @click="saveEdit">
              {{ savingEdit ? 'A guardar…' : 'Guardar alterações' }}
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Modal de edição de ação -->
    <div v-if="editActionOpen" class="modal d-block" tabindex="-1" style="background:rgba(0,0,0,.45)">
      <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content" style="border-radius:.75rem">
          <div class="modal-header">
            <h5 class="modal-title">Editar ação</h5>
            <button type="button" class="btn-close" @click="editActionOpen = false"></button>
          </div>
          <div class="modal-body">
            <div class="mb-3">
              <label class="form-label">Descrição</label>
              <textarea v-model="editActionForm.description" class="form-control" rows="2"></textarea>
            </div>
            <div class="row g-2">
              <div class="col-md-6">
                <label class="form-label">Responsável</label>
                <select v-model="editActionForm.responsible_user_id" class="form-select">
                  <option :value="''">Sem responsável</option>
                  <option v-for="p in profiles" :value="p.id" :key="p.id">{{ p.full_name }}</option>
                </select>
              </div>
              <div class="col-md-6">
                <label class="form-label">Prazo</label>
                <PtDateInput v-model="editActionForm.deadline" type="date" class="form-control" />
              </div>
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-outline-secondary" @click="editActionOpen = false">Cancelar</button>
            <button class="btn btn-primary" style="background:#7367f0;border-color:#7367f0" @click="saveEditAction">Guardar</button>
          </div>
        </div>
      </div>
    </div>

    <!-- Modal de confirmação de eliminação de ação -->
    <div v-if="confirmDeleteAction" class="modal d-block" tabindex="-1" style="background:rgba(0,0,0,.45)">
      <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content" style="border-radius:.75rem">
          <div class="modal-header"><h5 class="modal-title">Eliminar ação</h5><button type="button" class="btn-close" @click="confirmDeleteAction = null"></button></div>
          <div class="modal-body">
            <p class="mb-0">Tens a certeza que queres eliminar a ação <strong>{{ confirmDeleteAction.reference }}</strong>?</p>
          </div>
          <div class="modal-footer">
            <button class="btn btn-outline-secondary" @click="confirmDeleteAction = null">Cancelar</button>
            <button class="btn btn-danger" @click="doDeleteAction"><IconTrash :size="15" class="me-1 align-text-bottom" /> Sim, eliminar</button>
          </div>
        </div>
      </div>
    </div>

    <!-- Modal de confirmação de eliminação (com proteção de associações) -->
    <div v-if="confirmDelete" class="modal d-block" tabindex="-1" style="background:rgba(0,0,0,.45)">
      <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content" style="border-radius:.75rem">
          <div class="modal-header">
            <h5 class="modal-title">Eliminar ocorrência</h5>
            <button type="button" class="btn-close" @click="confirmDelete = false"></button>
          </div>
          <div class="modal-body">
            <template v-if="!depsLoaded">
              <p class="sq-muted mb-0">A verificar associações…</p>
            </template>
            <template v-else-if="hasDependencies">
              <div class="alert alert-warning d-flex gap-2 align-items-start mb-2">
                <IconX :size="18" class="mt-1" style="color:#ff9f43" />
                <div>
                  <strong>Não é possível eliminar</strong> — esta ocorrência tem associações:
                  <ul class="mb-0 mt-1" style="font-size:.85rem">
                    <li v-if="deps && deps.actions > 0">{{ deps.actions }} ação(ões) no plano de ações</li>
                    <li v-if="deps && deps.attachments > 0">{{ deps.attachments }} evidência(s)</li>
                    <li v-if="deps && deps.comments > 0">{{ deps.comments }} comentário(s)</li>
                  </ul>
                </div>
              </div>
              <p class="sq-muted mb-0" style="font-size:.85rem">
                Elimina primeiro as associações ou reabre a ocorrência se necessário.
              </p>
            </template>
            <template v-else>
              <p class="mb-1">Tens a certeza que queres eliminar a ocorrência <strong>{{ occ.reference }}</strong>?</p>
              <p class="sq-muted mb-0" style="font-size:.85rem">Esta operação não pode ser anulada.</p>
            </template>
          </div>
          <div class="modal-footer">
            <button class="btn btn-outline-secondary" @click="confirmDelete = false">{{ hasDependencies ? 'Fechar' : 'Cancelar' }}</button>
            <button v-if="!hasDependencies" class="btn btn-danger" :disabled="deleting" @click="doDelete">
              <IconTrash :size="15" class="me-1 align-text-bottom" /> {{ deleting ? 'A eliminar…' : 'Sim, eliminar' }}
            </button>
          </div>
        </div>
      </div>
    </div>
  </template>
</template>