import {API_BASE} from '@/lib/api-base'
// Acesso a ocorrências, ações, eficácia — lógica de negócio crítica vive no PostgreSQL;
// aqui apenas orquestração e leitura/escrita tipada.
import { supabase } from '@/lib/supabase'
import type { QualityOccurrence, QualityAction, OccurrenceType, OccurrenceStatus, ActionStatus, EffectivenessStatus } from '@/types/database'

export interface OccurrenceFilters {
  year?: number | null
  type?: OccurrenceType | '' | null
  origin_id?: string | null
  area_id?: string | null
  responsible_user_id?: string | null
  status?: OccurrenceStatus | '' | null
  tab?: 'open' | 'all' | 'closed'
  search?: string
  date_from?: string | null
  date_to?: string | null
}

export interface OccurrenceRow extends QualityOccurrence {
  quality_origins?: { name: string } | null
  quality_areas?: { name: string } | null
  profiles?: { full_name: string | null } | null
}

const SELECT_BASE = `*,
  quality_origins ( name ),
  quality_areas ( name ),
  profiles:responsible_user_id ( full_name )`

export async function listOccurrences(f: OccurrenceFilters = {}) {
  let q = supabase.from('quality_occurrences').select(SELECT_BASE, { count: 'exact' }).is('cancelled_at',null)

  if (f.year) q = q.eq('year', f.year)
  if (f.type) q = q.eq('type', f.type)
  if (f.origin_id) q = q.eq('origin_id', f.origin_id)
  if (f.area_id) q = q.eq('area_id', f.area_id)
  if (f.responsible_user_id) q = q.eq('responsible_user_id', f.responsible_user_id)
  if (f.date_from) q = q.gte('occurrence_date', f.date_from)
  if (f.date_to) q = q.lte('occurrence_date', f.date_to)

  if (f.status) {
    q = q.eq('status', f.status)
  } else if (f.tab === 'open') {
    q = q.in('status', ['OPEN', 'IN_PROGRESS', 'AWAITING_EFFECTIVENESS'])
  } else if (f.tab === 'closed') {
    q = q.eq('status', 'CLOSED')
  }

  if (f.search) {
    const s = f.search.trim()
    q = q.or(`reference.ilike.%${s}%,description.ilike.%${s}%`)
  }

  q = q.order('occurrence_date', { ascending: false }).limit(500)
  const { data, error, count } = await q
  if (error) throw error
  return { rows: (data ?? []) as OccurrenceRow[], count: count ?? 0 }
}

/**
 * Listagem PAGINADA no servidor para a grelha de ocorrências.
 * Vai buscar apenas a página pedida (offset/limit) e devolve o total via content-range,
 * com ordenação (incl. por relação), pesquisa e filtros todos resolvidos no PostgREST.
 */
export type OccurrenceSortKey = 'reference' | 'occurrence_date' | 'status' | 'type' | 'area' | 'responsible'

export interface OccurrencePageParams extends OccurrenceFilters {
  orderBy?: OccurrenceSortKey
  ascending?: boolean
  offset?: number
  limit?: number
}

/** Converte filtros em URLSearchParams PostgREST (partilhado entre grelha e exportação). */
function buildOccurrenceParams(p: OccurrenceFilters) {
  const params = new URLSearchParams({
    select: 'id,reference,type,description,status,occurrence_date,area_id,origin_id,responsible_user_id,' +
      'quality_origins(name),quality_areas(name),profiles:responsible_user_id(full_name)',
  })
  if (p.year) params.set('year', `eq.${p.year}`)
  if (p.type) params.set('type', `eq.${p.type}`)
  if (p.origin_id) params.set('origin_id', `eq.${p.origin_id}`)
  if (p.area_id) params.set('area_id', `eq.${p.area_id}`)
  if (p.responsible_user_id) params.set('responsible_user_id', `eq.${p.responsible_user_id}`)
  if (p.date_from) params.set('occurrence_date', `gte.${p.date_from}`)
  if (p.date_to) params.set('occurrence_date', `lte.${p.date_to}`)

  if (p.status) params.set('status', `eq.${p.status}`)
  else if (p.tab === 'open') params.set('status', 'in.("OPEN","IN_PROGRESS","AWAITING_EFFECTIVENESS")')
  else if (p.tab === 'closed') params.set('status', 'eq.CLOSED')

  if (p.search?.trim()) {
    const t = p.search.trim().replace(/%/g, '')
    params.set('or', `(reference.ilike.*${t}*,description.ilike.*${t}*)`)
  }
  params.set('cancelled_at','is.null')
  return params
}

async function fetchOccurrencesPage(params: URLSearchParams, offset: number, limit: number) {
  const { data: s } = await supabase.auth.getSession()
  const token = s.session?.access_token
  if (!token) throw new Error('Sessão inválida')
  const url = `${API_BASE}/rest/v1/quality_occurrences?${params.toString()}&offset=${offset}&limit=${limit}`
  const res = await fetch(url, {
    headers: { apikey: import.meta.env.VITE_SUPABASE_ANON_KEY, Authorization: `Bearer ${token}`, Prefer: 'count=exact' },
  })
  if (!res.ok) throw new Error(`Erro ao carregar ocorrências (${res.status})`)
  const data = await res.json()
  const cr = res.headers.get('content-range') || ''
  const m = cr.match(/\/(\d+)$/)
  const total = m ? Number(m[1]) : (data?.length ?? 0)
  return { rows: (data ?? []) as OccurrenceRow[], count: total }
}

export async function listOccurrencesPage(p: OccurrencePageParams = {}) {
  const params = buildOccurrenceParams(p)

  const ORDER: Record<OccurrenceSortKey, string> = {
    reference: 'reference',
    occurrence_date: 'occurrence_date',
    status: 'status',
    type: 'type',
    area: 'quality_areas(name)',
    responsible: 'profiles(full_name)',
  }
  const col = ORDER[p.orderBy ?? 'occurrence_date']
  params.set('order', `${col}.${p.ascending ? 'asc' : 'desc'}`)

  return fetchOccurrencesPage(params, p.offset ?? 0, p.limit ?? 10)
}

/** Exportação integral (relatórios Excel/PDF): busca TODAS as linhas dos filtros, sem paginação. */
export async function fetchAllOccurrences(f: OccurrenceFilters, limit = 5000) {
  const params = buildOccurrenceParams({ ...f, search: f.search || undefined })
  params.set('order', 'occurrence_date.desc')
  const { data: s } = await supabase.auth.getSession()
  const token = s.session?.access_token
  if (!token) throw new Error('Sessão inválida')
  const url = `${API_BASE}/rest/v1/quality_occurrences?${params.toString()}&offset=0&limit=${limit}`
  const res = await fetch(url, {
    headers: { apikey: import.meta.env.VITE_SUPABASE_ANON_KEY, Authorization: `Bearer ${token}`, Prefer: 'count=exact' },
  })
  if (!res.ok) throw new Error(`Erro ao carregar ocorrências (${res.status})`)
  return (await res.json()) as OccurrenceRow[]
}

export async function getOccurrence(id: string): Promise<OccurrenceRow> {
  const { data, error } = await supabase
    .from('quality_occurrences')
    .select(SELECT_BASE)
    .eq('id', id)
    .single()
  if (error) throw error
  return data as OccurrenceRow
}

export async function createOccurrence(input: {
  type: OccurrenceType
  origin_id: string
  area_id: string
  occurrence_date: string
  description: string
  responsible_user_id?: string | null
  cause_analysis?: string | null
}) {
  const { data: userData } = await supabase.auth.getUser()
  const { data, error } = await supabase
    .from('quality_occurrences')
    .insert({ ...input, created_by: userData.user?.id ?? null })
    .select('id, reference')
    .single()
  if (error) throw error
  return data as { id: string; reference: string }
}

export async function updateOccurrence(id: string, patch: Partial<QualityOccurrence>) {
  const { error } = await supabase.from('quality_occurrences').update(patch).eq('id', id)
  if (error) throw error
}

/** Eliminar ocorrência — apenas Quality/Admin (garantido por RLS no servidor). */
export async function deleteOccurrence(id: string) {
  const { error } = await supabase.from('quality_occurrences').delete().eq('id', id)
  if (error) throw error
}

/** Contar dependências de uma ocorrência (ações, anexos, comentários) — para avisar antes de eliminar. */
export async function countOccurrenceDependencies(id: string) {
  const [a, at, c] = await Promise.all([
    supabase.from('quality_actions').select('id', { count: 'exact', head: true }).eq('occurrence_id', id),
    supabase.from('quality_attachments').select('id', { count: 'exact', head: true }).eq('occurrence_id', id),
    supabase.from('quality_comments').select('id', { count: 'exact', head: true }).eq('occurrence_id', id),
  ])
  return {
    actions: a.count ?? 0,
    attachments: at.count ?? 0,
    comments: c.count ?? 0,
  }
}

// ----------------------------- AÇÕES -----------------------------
export async function listActionsByOccurrence(occurrenceId: string): Promise<QualityAction[]> {
  const { data, error } = await supabase
    .from('quality_actions')
    .select('*, profiles:responsible_user_id ( full_name )')
    .eq('occurrence_id', occurrenceId)
    .order('deadline', { ascending: true })
  if (error) throw error
  return (data ?? []) as QualityAction[]
}

export async function createAction(input: {
  occurrence_id: string
  description: string
  responsible_user_id?: string | null
  deadline?: string | null
}) {
  const { data: userData } = await supabase.auth.getUser()
  const { data, error } = await supabase
    .from('quality_actions')
    .insert({ ...input, created_by: userData.user?.id ?? null, status: 'TODO' })
    .select('id, reference')
    .single()
  if (error) throw error
  return data as { id: string; reference: string }
}

export async function updateAction(id: string, patch: Partial<QualityAction>) {
  const { error } = await supabase.from('quality_actions').update(patch).eq('id', id)
  if (error) throw error
}

export async function deleteAction(id: string) {
  const { error } = await supabase.from('quality_actions').delete().eq('id', id)
  if (error) throw error
}

export async function completeAction(id: string) {
  const { error } = await supabase
    .from('quality_actions')
    .update({ status: 'COMPLETED' as ActionStatus, completed_at: new Date().toISOString() })
    .eq('id', id)
  if (error) throw error
}

// ----------------------------- EFICÁCIA -----------------------------
/** Validar eficácia — apenas Qualidade/Admin (garantido por RLS no servidor). */
export async function validateEffectiveness(
  occurrenceId: string,
  result: EffectivenessStatus,
  notes: string,
) {
  const { data: userData } = await supabase.auth.getUser()
  const now = new Date().toISOString()

  if (result === 'EFFECTIVE') {
    const { error } = await supabase
      .from('quality_occurrences')
      .update({
        effectiveness_status: result,
        effectiveness_notes: notes,
        effectiveness_validated_by: userData.user?.id ?? null,
        effectiveness_validated_at: now,
        status: 'CLOSED' as OccurrenceStatus,
        closed_at: now,
      })
      .eq('id', occurrenceId)
    if (error) throw error
  } else {
    // Não eficaz: não encerra, volta a IN_PROGRESS (§34)
    const { error } = await supabase
      .from('quality_occurrences')
      .update({
        effectiveness_status: result,
        effectiveness_notes: notes,
        effectiveness_validated_by: userData.user?.id ?? null,
        effectiveness_validated_at: now,
        status: 'IN_PROGRESS' as OccurrenceStatus,
      })
      .eq('id', occurrenceId)
    if (error) throw error
  }
}

export async function reopenOccurrence(id: string) {
  const { data: userData } = await supabase.auth.getUser()
  const { error } = await supabase
    .from('quality_occurrences')
    .update({
      status: 'IN_PROGRESS' as OccurrenceStatus,
      reopened_at: new Date().toISOString(),
      reopened_by: userData.user?.id ?? null,
      closed_at: null,
    })
    .eq('id', id)
  if (error) throw error
}

// ----------------------------- COMENTÁRIOS / AUDITORIA -----------------------------
export async function listComments(occurrenceId: string) {
  const { data, error } = await supabase
    .from('quality_comments')
    .select('*, profiles:created_by ( full_name, avatar_url )')
    .eq('occurrence_id', occurrenceId)
    .order('created_at', { ascending: false })
  if (error) throw error
  return data ?? []
}

export async function addComment(occurrenceId: string, comment: string) {
  const { data: userData } = await supabase.auth.getUser()
  const { error } = await supabase
    .from('quality_comments')
    .insert({ occurrence_id: occurrenceId, comment, created_by: userData.user?.id ?? null })
  if (error) throw error
}

export async function listAudit(entityType: string, entityId: string) {
  const { data, error } = await supabase
    .from('audit_log')
    .select('*, profiles:user_id ( full_name )')
    .eq('entity_type', entityType)
    .eq('entity_id', entityId)
    .order('created_at', { ascending: false })
    .limit(200)
  if (error) throw error
  return data ?? []
}

// ----------------------------- LISTAS DE APOIO -----------------------------
export async function listAreas() {
  const { data, error } = await supabase.from('quality_areas').select('*').eq('active', true).order('sort_order')
  if (error) throw error
  return data ?? []
}

export async function listOrigins() {
  const { data, error } = await supabase.from('quality_origins').select('*').eq('active', true).order('sort_order')
  if (error) throw error
  return data ?? []
}

export async function listProfiles() {
  const { data, error } = await supabase.from('profiles').select('*').eq('active', true).order('full_name')
  if (error) throw error
  return data ?? []
}

// ----------------------------- COOPILOTO DE QUALIDADE (Fase 4) -----------------------------
// Chama as ferramentas MCP (leitura+escrita) através do endpoint /mcp/tools/call já exposto
// no backend (:3005 via proxy). Reutiliza o token da sessão e RLS das ferramentas.
async function callMcp(name: string, args: Record<string, unknown>): Promise<any> { // eslint-disable-line @typescript-eslint/no-explicit-any
  const { data: s } = await supabase.auth.getSession()
  const token = s.session?.access_token
  if (!token) throw new Error('Sessão inválida')
  const url = `${API_BASE}/mcp/tools/call`
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}`, apikey: import.meta.env.VITE_SUPABASE_ANON_KEY },
    body: JSON.stringify({ name, args }),
  })
  if (!res.ok) throw new Error(`Erro ao contactar o Copiloto (${res.status})`)
  return res.json() // {ok, data} | {ok:false, error}
}

/** Estado operacional de uma NC (plano, ações, encerramento) — tool MCP. */
export async function copilotoEstadoNc(ncRef: string) {
  const r = await callMcp('estado_nao_conformidade', { nc_ref: ncRef })
  return r.ok ? r.data : null
}

/** Gera um rascunho de Plano de Conformidade (NÃO persiste) — tool MCP. */
export async function copilotoProporPlano(ncRef: string, opt?: { titulo?: string; responsavel?: string; acoes?: { titulo?: string; tipo?: string; prioridade?: string; horas_previstas?: number }[] }) {
  const r = await callMcp('propor_plano_conformidade', { nc_ref: ncRef, ...(opt || {}) })
  return r.ok ? r.data : null
}

/** Persiste o plano/acoes da proposta em espera (apenas após confirmação explícita) — tool MCP. */
export async function copilotoConfirmarPlano() {
  const { data: userData } = await supabase.auth.getUser()
  const r = await callMcp('confirmar_plano_conformidade', { usuario_id: userData.user?.id ?? null })
  return r.ok ? r.data : null
}

/** Mostra a proposta de plano em espera — tool MCP. */
export async function copilotoVerProposta() {
  const r = await callMcp('ver_plano_em_espera', {})
  return r.ok ? r.data : null
}

// ----------------------------- PLANOS + WORK LOGS (Fase 4/5) -----------------------------
export interface CompliancePlan {
  id: string; codigo: string | null; titulo: string | null; descricao: string | null
  status: string; progresso: number; versao: number; origem: string | null; sugerido_por_ia: boolean
  esforco_previsto_h: number | null; esforco_real_h: number | null
  data_inicio: string | null; data_prevista_fim: string | null; requer_aprovacao: boolean | null
  responsavel_id: string | null
  aprovador_id: string | null
  aprovado_por: string | null; aprovado_em: string | null
  rejeitado_por: string | null; rejeitado_em: string | null; motivo_rejeicao: string | null
  created_at: string
}

export async function listPlansByOccurrence(occurrenceId: string): Promise<CompliancePlan[]> {
  const { data, error } = await supabase
    .from('quality_compliance_plans')
    .select('*')
    .eq('occurrence_id', occurrenceId)
    .order('created_at', { ascending: false })
  if (error) throw error
  return (data ?? []) as CompliancePlan[]
}

export async function updatePlan(id: string, patch: Partial<CompliancePlan>) {
  const { error } = await supabase.from('quality_compliance_plans').update(patch).eq('id', id)
  if (error) throw error
}

export async function aprovarPlano(id: string, aprovadorUserId: string, papel = 'aprovador') {
  const now = new Date().toISOString()
  const { error } = await supabase.from('quality_compliance_plans').update({
    aprovado_por: aprovadorUserId, aprovado_em: now,
    rejeitado_por: null, rejeitado_em: null, motivo_rejeicao: null,
    status: 'ATIVO',
  }).eq('id', id)
  if (error) throw error
  const { error: e2 } = await supabase.from('quality_plan_approval_events').insert({
    plan_id: id, acao: 'APROVADO', decidido_por: aprovadorUserId, papel, plan_status: 'ATIVO',
  })
  if (e2) throw e2
}

export async function rejeitarPlano(id: string, userId: string, motivo: string, papel = 'aprovador') {
  const now = new Date().toISOString()
  const { error } = await supabase.from('quality_compliance_plans').update({
    rejeitado_por: userId, rejeitado_em: now, motivo_rejeicao: motivo,
    aprovado_por: null, aprovado_em: null,
    status: 'RASCUNHO',
  }).eq('id', id)
  if (error) throw error
  const { error: e2 } = await supabase.from('quality_plan_approval_events').insert({
    plan_id: id, acao: 'REJEITADO', decidido_por: userId, motivo: motivo || null, papel, plan_status: 'RASCUNHO',
  })
  if (e2) throw e2
}

export interface ApprovalEvent {
  id: string; plan_id: string; acao: string
  decidido_por: string | null; decidido_em: string; motivo: string | null
  papel: string | null; plan_status: string | null
  profiles?: { full_name: string | null } | null
}

/** Desaprova um plano já aprovado: limpa a aprovação, volta a estado a aguardar, e regista no histórico. */
export async function desaprovarPlano(id: string, userId: string, motivo: string, papel: string) {
  const { error } = await supabase.from('quality_compliance_plans').update({
    aprovado_por: null, aprovado_em: null,
    status: 'RASCUNHO',
  }).eq('id', id)
  if (error) throw error
  const { error: e2 } = await supabase.from('quality_plan_approval_events').insert({
    plan_id: id, acao: 'DESAPROVADO', decidido_por: userId, motivo: motivo || null, papel,
    plan_status: 'RASCUNHO',
  })
  if (e2) throw e2
}

/** Marca manualmente o estado de aprovação (aprovado/aguarda) — registo manual de validação. */
export async function marcarAprovacaoManual(id: string, userId: string, aprovado: boolean, papel: string) {
  const now = new Date().toISOString()
  const { error } = await supabase.from('quality_compliance_plans').update(
    aprovado
      ? { aprovado_por: userId, aprovado_em: now, rejeitado_por: null, rejeitado_em: null, motivo_rejeicao: null, status: 'ATIVO' }
      : { aprovado_por: null, aprovado_em: null, rejeitado_por: null, rejeitado_em: null, motivo_rejeicao: null, status: 'RASCUNHO' },
  ).eq('id', id)
  if (error) throw error
  const { error: e2 } = await supabase.from('quality_plan_approval_events').insert({
    plan_id: id, acao: 'MARCADO_MANUAL', decidido_por: userId, papel,
    plan_status: aprovado ? 'ATIVO' : 'RASCUNHO',
  })
  if (e2) throw e2
}

export async function listarHistoricoAprovacao(planId: string): Promise<ApprovalEvent[]> {
  const { data, error } = await supabase
    .from('quality_plan_approval_events')
    .select('*, profiles:decidido_por ( full_name )')
    .eq('plan_id', planId)
    .order('decidido_em', { ascending: false })
    .limit(50)
  if (error) throw error
  return (data ?? []) as ApprovalEvent[]
}

export async function createPlan(occurrenceId: string, data: {
  titulo?: string | null; descricao?: string | null; status?: string
  esforco_previsto_h?: number | null; esforco_real_h?: number | null
  data_inicio?: string | null; data_prevista_fim?: string | null
  origem?: string | null; requer_aprovacao?: boolean; aprovador_id?: string | null
}) {
  const { error } = await supabase.from('quality_compliance_plans').insert({
    occurrence_id: occurrenceId,
    titulo: data.titulo ?? null,
    descricao: data.descricao ?? null,
    status: data.status ?? 'RASCUNHO',
    esforco_previsto_h: data.esforco_previsto_h ?? null,
    esforco_real_h: data.esforco_real_h ?? null,
    data_inicio: data.data_inicio ?? null,
    data_prevista_fim: data.data_prevista_fim ?? null,
    origem: data.origem ?? 'manual',
    requer_aprovacao: data.requer_aprovacao ?? false,
    aprovador_id: data.aprovador_id ?? null,
    sugerido_por_ia: false,
    plan_principal: true,
    progresso: 0,
    versao: 1,
    concluido_ai_validado: false,
  })
  if (error) throw error
}

export interface WorkLog {
  id: string; action_id: string; logged_by: string | null; descricao: string | null
  horas: number; minutos: number; percent_antes: number | null; percent_depois: number | null
  bloqueio: string | null; next_step: string | null; created_at: string
  profiles?: { full_name: string | null } | null
}

export async function listWorkLogsByAction(actionId: string): Promise<WorkLog[]> {
  const { data, error } = await supabase
    .from('quality_work_logs')
    .select('*, profiles:logged_by ( full_name )')
    .eq('action_id', actionId)
    .order('created_at', { ascending: true })
  if (error) throw error
  return (data ?? []) as WorkLog[]
}

export async function addWorkLog(input: {
  action_id: string; logged_by?: string | null
  descricao?: string | null; horas?: number; minutos?: number
  percent_depois?: number | null; bloqueio?: string | null; next_step?: string | null
}) {
  const { data: userData } = await supabase.auth.getUser()
  const { error } = await supabase.from('quality_work_logs').insert({
    ...input,
    logged_by: input.logged_by ?? userData.user?.id ?? null,
  })
  if (error) throw error
}
