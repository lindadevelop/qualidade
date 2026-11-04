import {API_BASE} from '@/lib/api-base'
// services/lifecycle.ts — LifeCycle RH: candidaturas, vagas, tarefas.
// Núcleo P0 (B01/B02/B03): modelo de dados com LifeCycle ID, estados e fila única.
import { supabase } from '@/lib/supabase'

export interface LifecycleVaga {
  id: string; reference: string; titulo: string; departamento?: string | null
  funcao?: string | null; local?: string | null; tipo?: string | null
  motivo?: string | null; data_desejada?: string | null
  estado?: string | null; aprovado_em?: string | null; created_at?: string | null
}
export interface LifecycleCaso {
  id: string; reference: string; vaga_id?: string | null
  pessoa_id?: string | null
  nome: string; email?: string | null; telefone?: string | null
  origem?: string | null; fonte?: string | null
  tipo?: string | null; estado?: string | null
  cv_url?: string | null; consentimento?: boolean; score?: number | null
  decisao_triagem?: string | null; motivo_encerramento?: string | null
  data_entrada?: string | null; funcao?: string | null; equipa?: string | null
  dados?: Record<string, unknown>; created_at?: string | null
  tipo_vinculo?: string | null; estado_admissao?: string | null
  ready_day1_flag?: boolean; ready_day1_em?: string | null
  data_saida?: string | null; motivo_saida?: string | null
  estado_offboarding?: string | null; offboarding_em?: string | null; offboarding_concluido_em?: string | null
  dedup_hash?: string | null; duplicado_de?: string | null; aviso_duplicado?: boolean
}
export interface LifecycleTarefa {
  id: string; caso_id: string; titulo: string; descricao?: string | null
  responsavel?: string | null; sector?: string | null; due_date?: string | null
  status?: string | null; sla_atraso?: boolean; created_at?: string | null
  gate?: string | null; depends_on?: string | null; sla_ms?: number | null
  completed_at?: string | null
}
export type LifecycleCasoRow = LifecycleCaso & { lifecycle_vagas?: Pick<LifecycleVaga,'reference'|'titulo'>|null } & { lifecycle_pessoas?: { cv_ultima_url?: string | null; nome_completo?: string | null } | null }

const CASOS_SELECT = 'id,reference,pessoa_id,vaga_id,nome,email,telefone,origem,fonte,tipo,estado,cv_url,consentimento,score,decisao_triagem,motivo_encerramento,data_entrada,funcao,equipa,dados,created_at,lifecycle_vagas(reference,titulo),lifecycle_pessoas(cv_ultima_url,nome_completo)'

// ---- Catálogo de tarefas de admissão A01-A20 (sec. 4.6.2 do relatório) ----
export const ADMISSAO_TAREFAS: { a: string; titulo: string; sector: string; gate: 'P0' | 'P1' | 'CONDICIONAL'; dias_antes?: number }[] = [
  { a: 'A01', titulo: 'Confirmar decisão de admissão e condições contratuais', sector: 'lider', gate: 'P0', dias_antes: 14 },
  { a: 'A02', titulo: 'Enviar Ficha de Identificação v4 + pedido documental único (admissão e seguro)', sector: 'rh', gate: 'P0', dias_antes: 12 },
  { a: 'A03', titulo: 'Recolher Ficha de Identificação preenchida e anexos obrigatórios', sector: 'rh', gate: 'P0', dias_antes: 8 },
  { a: 'A04', titulo: 'Validar identidade, dados pessoais e documentação', sector: 'rh', gate: 'P0', dias_antes: 6 },
  { a: 'A05', titulo: 'Registar e validar condições finais de contrato e remuneração', sector: 'rh', gate: 'P0', dias_antes: 5 },
  { a: 'A06', titulo: 'Acionar admissão na Segurança Social / Census', sector: 'rh', gate: 'P0', dias_antes: 4 },
  { a: 'A07', titulo: 'Criar/atualizar ficha de funcionário no PHC (sem redigitação)', sector: 'enterprise-phc', gate: 'P0', dias_antes: 3 },
  { a: 'A08', titulo: 'Validar dados complementares no PHC', sector: 'enterprise-phc', gate: 'P0', dias_antes: 2 },
  { a: 'A09', titulo: 'Preparar contrato e descritivo de funções', sector: 'rh', gate: 'P0', dias_antes: 2 },
  { a: 'A10', titulo: 'Criar acessos, utilizador, rede e equipamentos', sector: 'sistemas', gate: 'P0', dias_antes: 3 },
  { a: 'A11', titulo: 'Preparar Welcome Kit', sector: 'comunicacao', gate: 'P1', dias_antes: 1 },
  { a: 'A12', titulo: 'Iniciar integração de Comunicação', sector: 'comunicacao', gate: 'P1', dias_antes: 2 },
  { a: 'A13', titulo: 'Agendar consulta de Medicina / HST', sector: 'rh', gate: 'P0', dias_antes: 4 },
  { a: 'A14', titulo: 'Enviar pedido de Seguro de Saúde Montepio', sector: 'rh', gate: 'P0', dias_antes: 0 },
  { a: 'A15', titulo: 'Acionar Seguro de Estágio (se aplicável)', sector: 'rh', gate: 'CONDICIONAL', dias_antes: 0 },
  { a: 'A16', titulo: 'Registar incentivo de recomendação (se aplicável)', sector: 'financeiro', gate: 'CONDICIONAL' },
  { a: 'A17', titulo: 'Notificar equipa / Welcome', sector: 'lider', gate: 'P1', dias_antes: 1 },
  { a: 'A18', titulo: 'Agendar acolhimento e almoço de indução', sector: 'rh', gate: 'P1', dias_antes: 0 },
  { a: 'A19', titulo: 'Preparar documentos e materiais para Day 1', sector: 'rh', gate: 'P0', dias_antes: 0 },
  { a: 'A20', titulo: 'Gate READY FOR DAY 1 (todas as tarefas P0 concluídas ou exceção)', sector: 'rh', gate: 'P0', dias_antes: 0 },
]

export const SECTOR_LABEL: Record<string, string> = {
  rh: 'RH / Talento', lider: 'Líder / Direção', sistemas: 'Sistemas', comunicacao: 'Comunicação',
  logistica: 'Logística', financeiro: 'Financeiro', 'enterprise-phc': 'Enterprise / PHC',
}

// ---- Fase 1/3: ficha de pessoa (Pessoa vs Candidatura) + CV ----
export interface LifecyclePessoa {
  id: string; nome_completo: string; nome_preferido?: string | null
  email?: string | null; telefone?: string | null
  linkedin?: string | null; github?: string | null; portfolio?: string | null
  website?: string | null; email_alternativo?: string | null; telefone_alternativo?: string | null
  data_nascimento?: string | null; nacionalidade?: string | null; pais_residencia?: string | null
  distrito?: string | null; concelho?: string | null; localidade?: string | null; codigo_postal?: string | null; morada?: string | null
  area_profissional?: string | null; senioridade?: string | null; situacao_atual?: string | null
  prazo_pre_aviso?: string | null; tipo_vinculo_pretendido?: string | null
  disponibilidade_geo?: string | null; disponibilidade_desloc?: string | null; disponibilidade_viagem?: string | null; disponibilidade_mudar?: string | null
  carta_conducao?: string | null; viatura_propria?: string | null; autorizado_trabalhar_pt?: string | null
  objetivos_profissionais?: string | null; setores?: unknown[] | null; pontos_fortes?: unknown[] | null
  funcoes_pretendidas?: unknown[] | null; areas_pretendidas?: unknown[] | null
  expectativa_salarial?: number | null; moeda?: string | null; periodicidade_salarial?: string | null
  beneficios?: string | null; horario?: string | null; regime_pretendido?: string | null
  localizacao_pretendida?: string | null; contrato_pretendido?: string | null
  notas_internas?: string | null; info_em_falta?: string | null
  resumo_original?: string | null; resumo_gerado_ia?: string | null
  competencias_principais?: unknown[] | null; areas_experiencia?: unknown[] | null
  anos_experiencia?: number | null; titulo_atual?: string | null; empresa_atual?: string | null
  disponibilidade_inicio?: string | null; regime?: string | null
  estados_ficha?: string | null; cv_hash?: string | null; cv_ultima_url?: string | null
  created_at?: string | null; updated_at?: string | null
}
export interface LifecycleCandidato {
  pessoa?: LifecyclePessoa | null
  experiencias?: Record<string, unknown>[]
  formacoes?: Record<string, unknown>[]
  competencias?: Record<string, unknown>[]
  idiomas?: Record<string, unknown>[]
  certificacoes?: Record<string, unknown>[]
  projetos?: Record<string, unknown>[]
  referencias?: Record<string, unknown>[]
}
export type LifecyclePessoaRow = LifecyclePessoa

const PESSOA_SELECT = 'id,nome_completo,nome_preferido,email,telefone,linkedin,github,portfolio,website,email_alternativo,telefone_alternativo,data_nascimento,nacionalidade,pais_residencia,distrito,concelho,localidade,codigo_postal,morada,area_profissional,senioridade,situacao_atual,prazo_pre_aviso,tipo_vinculo_pretendido,disponibilidade_geo,disponibilidade_desloc,disponibilidade_viagem,disponibilidade_mudar,carta_conducao,viatura_propria,autorizado_trabalhar_pt,objetivos_profissionais,setores,pontos_fortes,funcoes_pretendidas,areas_pretendidas,expectativa_salarial,moeda,periodicidade_salarial,beneficios,horario,regime_pretendido,localizacao_pretendida,contrato_pretendido,notas_internas,info_em_falta,resumo_original,resumo_gerado_ia,competencias_principais,areas_experiencia,anos_experiencia,titulo_atual,empresa_atual,disponibilidade_inicio,regime,estado_ficha,cv_hash,cv_ultima_url,created_at,updated_at'

export async function listPessoas(): Promise<LifecyclePessoa[]> {
  const { data, error } = await supabase.from('lifecycle_pessoas').select(PESSOA_SELECT).order('nome_completo')
  if (error) throw error
  return (data ?? []) as LifecyclePessoa[]
}
export async function getPessoa(id: string): Promise<LifecyclePessoa | null> {
  const { data, error } = await supabase.from('lifecycle_pessoas').select(PESSOA_SELECT).eq('id', id).maybeSingle()
  if (error) throw error
  return (data ?? null) as LifecyclePessoa | null
}
// ---- ficha 360º: registos repetíveis por pessoa ----
const FILHAS = ['lifecycle_experiencias', 'lifecycle_formacoes', 'lifecycle_competencias', 'lifecycle_idiomas', 'lifecycle_certificacoes', 'lifecycle_projetos', 'lifecycle_referencias'] as const
export type TabelaFilha = typeof FILHAS[number]
export async function listarFilhos(tabela: TabelaFilha, pessoaId: string): Promise<Record<string, unknown>[]> {
  const { data, error } = await supabase.from(tabela).select('*').eq('pessoa_id', pessoaId).order('created_at', { ascending: false })
  if (error) throw error
  return (data ?? []) as Record<string, unknown>[]
}
export async function criarFilho(tabela: TabelaFilha, pessoaId: string, campos: Record<string, unknown>): Promise<Record<string, unknown>> {
  const { data, error } = await supabase.from(tabela).insert({ ...campos, pessoa_id: pessoaId }).select().single()
  if (error) throw error
  return data as Record<string, unknown>
}
export async function atualizarFilho(tabela: TabelaFilha, id: string, campos: Record<string, unknown>): Promise<Record<string, unknown>> {
  const { data, error } = await supabase.from(tabela).update(campos).eq('id', id).select().single()
  if (error) throw error
  return data as Record<string, unknown>
}
export async function removerFilho(tabela: TabelaFilha, id: string) {
  const { error } = await supabase.from(tabela).delete().eq('id', id)
  if (error) throw error
}
export async function carregarCandidatoCompleto(pessoaId: string): Promise<LifecycleCandidato> {
  const [pessoa, experiencias, formacoes, competencias, idiomas, certificacoes, projetos, referencias] = await Promise.all([
    getPessoa(pessoaId),
    listarFilhos('lifecycle_experiencias', pessoaId),
    listarFilhos('lifecycle_formacoes', pessoaId),
    listarFilhos('lifecycle_competencias', pessoaId),
    listarFilhos('lifecycle_idiomas', pessoaId),
    listarFilhos('lifecycle_certificacoes', pessoaId),
    listarFilhos('lifecycle_projetos', pessoaId),
    listarFilhos('lifecycle_referencias', pessoaId),
  ])
  return { pessoa, experiencias, formacoes, competencias, idiomas, certificacoes, projetos, referencias }
}
export async function upsertPessoa(p: Partial<LifecyclePessoa>): Promise<LifecyclePessoa> {
  const { data, error } = await supabase.from('lifecycle_pessoas').upsert(p).select(PESSOA_SELECT).single()
  if (error) throw error
  return data as LifecyclePessoa
}
export async function updateCasoPessoa(casoId: string, pessoaId: string) {
  const { error } = await supabase.from('lifecycle_casos').update({ pessoa_id: pessoaId }).eq('id', casoId)
  if (error) throw error
}
/** Cria uma candidatura (caso) associada a uma ficha de pessoa já gravada, para aparecer na grelha.
 *  Idempotente e sem duplicados: devolve o já existente se houver caso com esta pessoa OU com o
 *  mesmo email (ou telefone) em estado ativo — atualiza o CV nesse caso em vez de criar outro. */
export async function criarCasoDePessoa(p: Partial<LifecyclePessoa> & { id?: string }): Promise<LifecycleCaso> {
  const em = (p.email || '').trim().toLowerCase()
  const te = (p.telefone || '').trim()
  const nome = (p.nome_completo || p.nome_preferido || 'Candidato').trim()
  // 1) caso para a mesma pessoa
  if (p.id) {
    const { data: porPessoa } = await supabase.from('lifecycle_casos').select('*').eq('pessoa_id', p.id).limit(1)
    if (porPessoa && (porPessoa as unknown as LifecycleCaso[]).length) return (porPessoa as unknown as LifecycleCaso[])[0]
  }
  // 2) dedup por email/telefone contra casos ATIVOS (não reabre recusados/encerrados)
  const or: string[] = []
  if (em) or.push(`email.ilike.${em}`)
  if (te) or.push(`telefone.ilike.${te}`)
  if (or.length) {
    const { data: dup } = await supabase.from('lifecycle_casos')
      .select('*')
      .or(or.join(','))
      .not('estado', 'in', '("NAO_SELECIONADO","ENCERRADO","CANCELADO")')
      .limit(1)
    if (dup && (dup as unknown as LifecycleCaso[]).length) {
      const existente = (dup as unknown as LifecycleCaso[])[0]
      // atualiza o caso existente com o CV e a referência à ficha (se ainda não tiver)
      const patch: Record<string, unknown> = {}
      if (p.cv_ultima_url && !existente.cv_url) patch.cv_url = p.cv_ultima_url
      if (p.id && !existente.pessoa_id) patch.pessoa_id = p.id
      if (Object.keys(patch).length) await supabase.from('lifecycle_casos').update(patch).eq('id', existente.id)
      return { ...existente, ...patch }
    }
  }
  const ref = `LCY-${new Date().getFullYear()}-${Date.now().toString().slice(-6)}`
  const payload: Record<string, unknown> = {
    reference: ref,
    pessoa_id: p.id || null,
    nome, email: p.email || null, telefone: p.telefone || null,
    origem: 'espontanea', fonte: 'CV', estado: 'NA_FILA',
    consentimento: true,  // ficha criada a partir do CV importado pelo utilizador
    cv_url: p.cv_ultima_url || null,
    dedup_hash: (em || te || nome).toLowerCase(),
  }
  const { data, error } = await supabase.from('lifecycle_casos').insert(payload).select().single()
  if (error) throw error
  return data as LifecycleCaso
}

// ---- upload + processamento de CV (storage 3003 / cv 3006 via proxy 8000) ----
const API = `${(API_BASE as string) || ''}`
export async function uploadCv(file: File): Promise<{ path: string; hash: string; size: number }> {
  const res = await authenticatedFetch(`${API}/storage/v1/object/cv`, {
    method: 'POST', headers: { 'Content-Type': 'application/pdf' }, body: file,
  })
  if (!res.ok) {
    const e = await res.json().catch(() => ({}))
    throw new Error((e as any).error || 'Erro ao enviar o CV.') // eslint-disable-line @typescript-eslint/no-explicit-any
  }
  return res.json()
}
export async function extractCvText(documentPath: string): Promise<{ text: string; has_text: boolean; pages: number; ocr_used: boolean }> {
  const res = await authenticatedFetch(`${API}/cv/extract`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ document_path: documentPath }),
  })
  if (!res.ok) {
    const e = await res.json().catch(() => ({}))
    throw new Error((e as any).error || 'Erro ao extrair o texto do CV.') // eslint-disable-line @typescript-eslint/no-explicit-any
  }
  return res.json()
}
export async function analyzeCvText(text: string, documentPath?: string, onProgress?: (elapsedMs: number) => void): Promise<any> { // eslint-disable-line @typescript-eslint/no-explicit-any
  // assíncrono: cria job e faz polling até concluir (não bloqueia o HTTP a 5 min)
  const res = await authenticatedFetch(`${API}/cv/analyze`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ text, document_path: documentPath || null }),
  })
  if (!res.ok) {
    const e = await res.json().catch(() => ({}))
    throw new Error((e as any).error || 'O Ollama não aceitou o pedido.') // eslint-disable-line @typescript-eslint/no-explicit-any
  }
  const job = await res.json()
  if (!job.job_id) throw new Error('Sem job_id na resposta.')
  // polling até done/error (até ~15 min)
  const t0 = Date.now()
  for (;;) {
    const r = await authenticatedFetch(`${API}${job.status_url}`)
    const st = await r.json()
    if (st.state === 'done') return st
    if (st.state === 'error') throw new Error(st.error || 'Erro do Ollama ao analisar o CV.')
    onProgress?.(st.elapsed_ms ?? Date.now() - t0)
    await new Promise((r2) => setTimeout(r2, 8000))   // polling 8s
  }
}

// ---- Fase 4: comparação explicável com a vaga ----
// sessão partilhada do último CV processado (texto + análise) para a avaliação
let _cvSession: { text: string; analysis: any } | null = null // eslint-disable-line @typescript-eslint/no-explicit-any
export function setCvSession(s: { text: string; analysis: any } | null) { _cvSession = s } // eslint-disable-line @typescript-eslint/no-explicit-any
export function getCvSession() { return _cvSession }
export async function matchCvVaga(text: string, analysis: any, vaga: { titulo: string; requisitos?: any; descricao?: string | null }, onProgress?: (ms: number) => void): Promise<any> {
  const res = await authenticatedFetch(`${API}/cv/match`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ text, analysis: analysis || null, vaga }),
  })
  if (!res.ok) {
    const e = await res.json().catch(() => ({}))
    throw new Error((e as any).error || 'Erro ao iniciar a comparação.') // eslint-disable-line @typescript-eslint/no-explicit-any
  }
  const job = await res.json()
  if (!job.job_id) throw new Error('Sem job_id na resposta.')
  const t0 = Date.now()
  for (;;) {
    const r = await authenticatedFetch(`${API}${job.status_url}`)
    const st = await r.json()
    if (st.state === 'done') return st
    if (st.state === 'error') throw new Error(st.error || 'Erro do Ollama na comparação.')
    onProgress?.(st.elapsed_ms ?? Date.now() - t0)
    await new Promise((r2) => setTimeout(r2, 8000))
  }
}
// guarda/atualiza a avaliação no histórico da candidatura
export async function saveAvaliacao(casoId: string, vagaId: string | null, dados: Record<string, unknown>) {
  const payload = {
    caso_id: casoId,
    vaga_id: vagaId || null,
    score_global: dados.score_global ?? null,
    score_requisitos: dados.score_requisitos ?? null,
    score_preferenciais: dados.score_preferenciais ?? null,
    score_competencias: dados.score_competencias ?? null,
    score_experiencia: dados.score_experiencia ?? null,
    score_formacao: dados.score_formacao ?? null,
    score_idiomas: dados.score_idiomas ?? null,
    score_disponibilidade: dados.score_disponibilidade ?? null,
    razao: dados.razao ?? [],
    competencias_encontradas: dados.competencias_encontradas ?? [],
    competencias_em_falta: dados.competencias_em_falta ?? [],
    alertas: dados.alertas ?? [],
    perguntas_entrevista: dados.perguntas_entrevista ?? [],
    recomendacao_ia: dados.recomendacao_ia ?? null,
    decisao_humana: null,
    modelo_ia: dados.modelo_ia || null,
    prompt_version: dados.prompt_version || null,
  }
  const { data, error } = await supabase.from('lifecycle_avaliacoes').upsert(payload, { onConflict: 'caso_id,vaga_id' }).select().maybeSingle()
  if (error) throw error
  return data
}
export async function listAvaliacoes(casoId: string): Promise<any[]> {
  const { data, error } = await supabase.from('lifecycle_avaliacoes').select('*').eq('caso_id', casoId)
  if (error) throw error
  return (data ?? []) as any[]
}
export async function listAvaliacoesAll(): Promise<Record<string, unknown>[]> {
  const { data, error } = await supabase.from('lifecycle_avaliacoes').select('*').order('created_at', { ascending: false }).limit(500)
  if (error) throw error
  return (data ?? []) as Record<string, unknown>[]
}

// ---- Fila persistente de processamento de CVs ----
export interface CvJob {
  id: string; company_id?: string | null; user_id?: string | null
  file_name: string; file_path: string; file_hash?: string | null; file_size?: number | null; file_mime?: string | null
  status: string; etapa: string; progress?: number | null; attempt?: number | null
  submitted_at?: string | null; queued_at?: string | null; started_at?: string | null; finished_at?: string | null; duration_ms?: number | null
  model_ia?: string | null; prompt_version?: string | null
  caso_id?: string | null; pessoa_id?: string | null; vaga_id?: string | null
  extracted_text?: string | null; analysis_json?: any | null // eslint-disable-line @typescript-eslint/no-explicit-any
  duplicated_of?: string | null; error_message?: string | null
  cancel_requested_at?: string | null; cancelled_at?: string | null; viewed?: boolean | null
  arquivado_at?: string | null
  created_at?: string | null
}
export async function listCvJobs(status?: string): Promise<{ jobs: CvJob[]; total: number }> {
  const { data: { session } } = await supabase.auth.getSession()
  const r = await authenticatedFetch(`${API}/cv/queue${status ? `?status=${encodeURIComponent(status)}` : ''}`, { headers: { Authorization: `Bearer ${session?.access_token || ''}` } })
  if (!r.ok) throw new Error('Falha ao listar a fila de CV.')
  return r.json()
}
export async function enqueueCv(p: { file_name: string; file_path: string; file_hash?: string; file_size?: number; caso_id?: string | null; vaga_id?: string | null }): Promise<{ job_id: string; status: string; duplicado_envio?: boolean }> {
  const { data: { session } } = await supabase.auth.getSession()
  const r = await authenticatedFetch(`${API}/cv/queue`, { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${session?.access_token || ''}` }, body: JSON.stringify(p) })
  if (!r.ok) { const e = await r.json().catch(() => ({})); throw new Error((e as any).error || 'Falha ao enfileirar o CV.') } // eslint-disable-line @typescript-eslint/no-explicit-any
  return r.json()
}
export async function getCvJob(id: string): Promise<CvJob> {
  const { data: { session } } = await supabase.auth.getSession()
  const r = await authenticatedFetch(`${API}/cv/queue/${id}`, { headers: { Authorization: `Bearer ${session?.access_token || ''}` } })
  if (!r.ok) throw new Error('Falha ao obter o trabalho.')
  return r.json()
}
export async function cancelCvJob(id: string): Promise<{ ok: boolean; status: string }> {
  const { data: { session } } = await supabase.auth.getSession()
  const r = await authenticatedFetch(`${API}/cv/queue/${id}?action=cancel`, { method: 'POST', headers: { Authorization: `Bearer ${session?.access_token || ''}` } })
  if (!r.ok) throw new Error('Falha ao cancelar.')
  return r.json()
}
export async function retryCvJob(id: string): Promise<{ ok: boolean; status: string }> {
  const { data: { session } } = await supabase.auth.getSession()
  const r = await authenticatedFetch(`${API}/cv/queue/${id}?action=retry`, { method: 'POST', headers: { Authorization: `Bearer ${session?.access_token || ''}` } })
  if (!r.ok) throw new Error('Falha ao repetir.')
  return r.json()
}
export async function markCvJobViewed(id: string) {
  const { data: { session } } = await supabase.auth.getSession()
  await authenticatedFetch(`${API}/cv/queue/${id}?action=view`, { method: 'POST', headers: { Authorization: `Bearer ${session?.access_token || ''}` } })
}
export async function archiveCvJob(id: string) {
  const { data: { session } } = await supabase.auth.getSession()
  await authenticatedFetch(`${API}/cv/queue/${id}?action=archive`, { method: 'POST', headers: { Authorization: `Bearer ${session?.access_token || ''}` } })
}

// ---- Catálogo de tarefas de offboarding (sec. 4.8) ----
export const OFFBOARDING_TAREFAS: { titulo: string; sector: string; gate: 'P0' | 'P1' }[] = [
  { titulo: 'Registar motivo e data de saída', sector: 'rh', gate: 'P0' },
  { titulo: 'Preparar documentos de cessação/rescisão', sector: 'rh', gate: 'P0' },
  { titulo: 'Cancelar/desativar acessos e utilizador', sector: 'sistemas', gate: 'P0' },
  { titulo: 'Devolução de equipamento e ativos', sector: 'logistica', gate: 'P0' },
  { titulo: 'Cancelar benefícios e seguros associados', sector: 'rh', gate: 'P0' },
  { titulo: 'Realizar entrevista de saída', sector: 'rh', gate: 'P1' },
  { titulo: 'Cancelar/acertar comunicações e alertas internos', sector: 'comunicacao', gate: 'P1' },
  { titulo: 'Encerrar caso e arquivo final', sector: 'rh', gate: 'P0' },
]

/** Gera as tarefas de offboarding de um caso; idempotente. */
export async function gerarTarefasOffboarding(casoId: string) {
  const { data: exist } = await supabase.from('lifecycle_tarefas').select('titulo').eq('caso_id', casoId)
  const titulos = new Set((exist ?? []).map((t: { titulo: string }) => t.titulo))
  const novos: Partial<LifecycleTarefa>[] = []
  for (const t of OFFBOARDING_TAREFAS) {
    if (titulos.has(t.titulo)) continue
    novos.push({ caso_id: casoId, titulo: t.titulo, sector: t.sector, gate: t.gate })
  }
  if (novos.length) {
    const { error } = await supabase.from('lifecycle_tarefas').insert(novos)
    if (error) throw error
  }
  return novos.length
}

/** Calcula due_date relativa à data de entrada (dias_antes); sem data de entrada => null. */
function duePara(entrada: string | null | undefined, diasAntes: number): string | null {
  if (!entrada) return null
  try {
    const d = new Date(entrada)
    if (isNaN(d.getTime())) return null
    d.setDate(d.getDate() - (diasAntes || 0))
    return d.toISOString().slice(0, 10)
  } catch { return null }
}

/** Gera o lote de tarefas A01-A20 para um caso de admissão; idempotente (não duplica). */
export async function gerarTarefasAdmissao(casoId: string, dataEntrada?: string | null) {
  const { data: exist } = await supabase.from('lifecycle_tarefas').select('titulo').eq('caso_id', casoId)
  const titulos = new Set((exist ?? []).map((t: { titulo: string }) => t.titulo))
  const novos: Partial<LifecycleTarefa>[] = []
  for (const t of ADMISSAO_TAREFAS) {
    if (titulos.has(t.titulo)) continue
    novos.push({ caso_id: casoId, titulo: t.titulo, sector: t.sector, gate: t.gate, due_date: duePara(dataEntrada, t.dias_antes ?? 0) })
  }
  if (novos.length) {
    const { error } = await supabase.from('lifecycle_tarefas').insert(novos)
    if (error) throw error
  }
  return novos.length
}

export async function listVagas(): Promise<LifecycleVaga[]> {
  const { data, error } = await supabase.from('lifecycle_vagas').select('*').order('created_at', { ascending: false })
  if (error) throw error
  return (data ?? []) as LifecycleVaga[]
}
export async function createVaga(p: Partial<LifecycleVaga>): Promise<LifecycleVaga> {
  const { data, error } = await supabase.from('lifecycle_vagas').insert(p).select().single()
  if (error) throw error
  return data
}
export async function updateVaga(id: string, p: Partial<LifecycleVaga>): Promise<LifecycleVaga> {
  const { data, error } = await supabase.from('lifecycle_vagas').update(p).eq('id', id).select().single()
  if (error) throw error
  return data
}
export async function deleteVaga(id: string): Promise<void> {
  const { error } = await supabase.from('lifecycle_vagas').delete().eq('id', id)
  if (error) throw error
}
export async function listCasos(filters?: { estado?: string; search?: string }): Promise<LifecycleCasoRow[]> {
  let q = supabase.from('lifecycle_casos').select(CASOS_SELECT).order('created_at', { ascending: false })
  if (filters?.estado) q = q.eq('estado', filters.estado)
  if (filters?.search) q = q.or(`nome.ilike.%${filters.search}%,reference.ilike.%${filters.search}%`)
  const { data, error } = await q
  if (error) throw error
  return ((data ?? []) as unknown) as LifecycleCasoRow[]
}
export async function createCaso(p: Partial<LifecycleCaso>): Promise<{ caso: LifecycleCaso; duplicado?: LifecycleCaso }> {
  // gera LifeCycle ID (LCY-<ano>-<timestamp>); consentimento obrigatório p/ reter dados
  const ref = `LCY-${new Date().getFullYear()}-${Date.now().toString().slice(-6)}`
  // B09 - deduplicação: email ou telefone iguais a candidatura pré-existente ativa
  const em = (p.email || '').trim().toLowerCase()
  const te = (p.telefone || '').trim()
  let dup: LifecycleCaso | null = null
  if (em || te) {
    const or: string[] = []
    if (em) or.push(`email.ilike.${em}`)
    if (te) or.push(`telefone.ilike.${te}`)
    if (or.length) {
      const { data } = await supabase.from('lifecycle_casos')
        .select('id,reference,nome,email,telefone,estado')
        .or(or.join(','))
        .not('estado', 'in', '("NAO_SELECIONADO","ENCERRADO")')
        .limit(1)
      if (data && (data as unknown as LifecycleCaso[]).length) {
        dup = ((data as unknown) as LifecycleCaso[])[0]
      }
    }
  }
  const dedupHash = em && te ? `${em}|${te}` : (em || te || p.nome || '').toLowerCase()
  const payload: Record<string, unknown> = { reference: ref, ...p, dedup_hash: dedupHash, aviso_duplicado: !!dup }
  if (dup) payload.duplicado_de = dup.id
  const { data, error } = await supabase.from('lifecycle_casos').insert(payload).select().single()
  if (error) throw error
  return { caso: data, duplicado: dup ?? undefined }
}
export async function updateCaso(id: string, patch: Partial<LifecycleCaso>) {
  const { data, error } = await supabase.from('lifecycle_casos').update(patch).eq('id', id).select().single()
  if (error) throw error
  return data
}
export async function listTarefas(casoId: string): Promise<LifecycleTarefa[]> {
  const { data, error } = await supabase.from('lifecycle_tarefas').select('*').eq('caso_id', casoId).order('created_at')
  if (error) throw error
  return (data ?? []) as LifecycleTarefa[]
}
export async function createTarefa(p: Partial<LifecycleTarefa>): Promise<LifecycleTarefa> {
  const { data, error } = await supabase.from('lifecycle_tarefas').insert(p).select().single()
  if (error) throw error
  return data
}
export async function setTarefaStatus(id: string, status: 'TODO' | 'IN_PROGRESS' | 'COMPLETED') {
  const { error } = await supabase.from('lifecycle_tarefas')
    .update({ status, completed_at: status === 'COMPLETED' ? new Date().toISOString() : null })
    .eq('id', id)
  if (error) throw error
}
export async function setCasoDataEntrada(id: string, dataEntrada: string | null, tipoVinculo: string | null) {
  const { error } = await supabase.from('lifecycle_casos')
    .update({ data_entrada: dataEntrada, tipo_vinculo: tipoVinculo })
    .eq('id', id)
  if (error) throw error
}

// ---- B11 - Comunicações E01-E12 (evidência de envio por caso) ----
export const COMUNICACOES: { ref: string; tipo: string; destino: string; template: string }[] = [
  { ref: 'E01', tipo: 'email', destino: 'candidato', template: 'Ficha de Identificação v4 + pedido documental único (admissão + seguro)' },
  { ref: 'E02', tipo: 'tarefa', destino: 'interna', template: 'Admissão — workflow/tarefas (RH, líder, direção)' },
  { ref: 'E03', tipo: 'email', destino: 'externo', template: 'Admissão SS/Census' },
  { ref: 'E04', tipo: 'integracao', destino: 'phc', template: 'Criação de dados PHC (ficha de funcionário)' },
  { ref: 'E05', tipo: 'tarefa', destino: 'sistemas-logistica', template: 'Novo colaborador — OPERACIONAL (acessos, rede, equipamentos)' },
  { ref: 'E06', tipo: 'tarefa', destino: 'comunicacao', template: 'Integração — tarefa interna' },
  { ref: 'E07', tipo: 'email', destino: 'equipa', template: 'Welcome a novo colega' },
  { ref: 'E08', tipo: 'email', destino: 'montepio', template: 'Seguro de Saúde Montepio (após pack documental completo)' },
  { ref: 'E09', tipo: 'email', destino: 'seguradora-estagio', template: 'Seguro de Estágio ATIVAR (condicional)' },
  { ref: 'E10', tipo: 'email', destino: 'hst', template: 'Dados para agendamento de consulta HST' },
  { ref: 'E11', tipo: 'email', destino: 'financeiro-rh', template: 'Incentivo à Atração e Fidelização (condicional)' },
  { ref: 'E12', tipo: 'notificacao', destino: 'rh-lider', template: 'Confirmação Ready for Day 1' },
]
export async function listComunicacoes(casoId?: string): Promise<Record<string, unknown>[]> {
  let q = supabase.from('lifecycle_comunicacoes').select('*').order('created_at', { ascending: false }).limit(100)
  if (casoId) q = supabase.from('lifecycle_comunicacoes').select('*').eq('caso_id', casoId).order('created_at', { ascending: false })
  const { data, error } = await q
  if (error) throw error
  return (data ?? []) as Record<string, unknown>[]
}
export async function registarComunicacao(input: { caso_id: string; ref: string; tipo: string; destino?: string; template?: string; estado?: string }) {
  const { data, error } = await supabase.from('lifecycle_comunicacoes')
    .insert({ ...input, estado: input.estado || 'PENDENTE' })
    .select().single()
  if (error) throw error
  return data
}

// ---- B12 - Protocolo de estágio: tarefas específicas ----
export const ESTAGIO_TAREFAS: { titulo: string; sector: string; gate: 'P0' | 'P1' | 'CONDICIONAL' }[] = [
  { titulo: 'Validar elegibilidade e disponibilidade do estágio', sector: 'rh', gate: 'P0' },
  { titulo: 'Preparar e aprovar o protocolo de estágio', sector: 'rh', gate: 'P0' },
  { titulo: 'Enviar protocolo à instituição/estagiário', sector: 'rh', gate: 'P1' },
  { titulo: 'Recolher assinatura e arquivar protocolo', sector: 'rh', gate: 'P1' },
  { titulo: 'Acionar seguro de estágio (condicional)', sector: 'rh', gate: 'CONDICIONAL' },
]
export async function gerarTarefasEstagio(casoId: string) {
  const { data: exist } = await supabase.from('lifecycle_tarefas').select('titulo').eq('caso_id', casoId)
  const titulos = new Set((exist ?? []).map((t: { titulo: string }) => t.titulo))
  const novos: Partial<LifecycleTarefa>[] = []
  for (const t of ESTAGIO_TAREFAS) {
    if (titulos.has(t.titulo)) continue
    novos.push({ caso_id: casoId, titulo: t.titulo, sector: t.sector, gate: t.gate })
  }
  if (novos.length) { const { error } = await supabase.from('lifecycle_tarefas').insert(novos); if (error) throw error }
  return novos.length
}

// ---- B11 - Fechar vaga: recusa automática das restantes candidaturas ativas ----
export async function fecharVaga(vagaId: string) {
  await supabase.from('lifecycle_vagas').update({ estado: 'ENCERRADA' }).eq('id', vagaId)
  const { data } = await supabase.from('lifecycle_casos').select('id,reference').eq('vaga_id', vagaId)
  const ativos = (data ?? []) as { id: string }[]
  for (const c of ativos) {
    await supabase.from('lifecycle_casos')
      .update({ estado: 'NAO_SELECIONADO', motivo_encerramento: 'Vaga encerrada' })
      .eq('id', c.id)
      .not('estado', 'in', '("SELECIONADO","NAO_SELECIONADO","ENCERRADO","PRE_ADMISSAO")')
  }
  return ativos.length
}

export const CASO_STATUS: { value: string; label: string; tone: string }[] = [
  { value: 'CANDIDATURA_RECEBIDA', label: 'Recebida', tone: 'secondary' },
  { value: 'NA_FILA', label: 'Na fila', tone: 'secondary' },
  { value: 'EM_TRIAGEM', label: 'Em triagem', tone: 'info' },
  { value: 'ENTREVISTA', label: 'Entrevista', tone: 'warning' },
  { value: 'SELECIONADO', label: 'Selecionado', tone: 'success' },
  { value: 'NAO_SELECIONADO', label: 'Não selecionado', tone: 'danger' },
  { value: 'PRE_ADMISSAO', label: 'Pré-admissão', tone: 'info' },
  { value: 'ADMISSAO_EM_PREPARACAO', label: 'Em preparação', tone: 'warning' },
  { value: 'READY_DAY1', label: 'Ready for Day 1', tone: 'success' },
  { value: 'ATIVO', label: 'Ativo', tone: 'success' },
  { value: 'OFFBOARDING', label: 'Offboarding', tone: 'danger' },
  { value: 'ENCERRADO', label: 'Encerrado', tone: 'secondary' },
]
export function casoStatusLabel(v?: string | null) { return CASO_STATUS.find(s => s.value === v)?.label ?? v ?? '—' }
export function casoStatusTone(v?: string | null) { return CASO_STATUS.find(s => s.value === v)?.tone ?? 'secondary' }

// ---- B10 - análise / distribuicão por estado ----
export interface EstadoCount { estado: string; total: number }
export async function distribuicaoEstados(): Promise<EstadoCount[]> {
  const { data, error } = await supabase.from('lifecycle_casos').select('estado')
  if (error) throw error
  const m = new Map<string, number>()
  for (const r of (data ?? []) as { estado?: string }[]) {
    const k = r.estado || 'S/ESTADO'
    m.set(k, (m.get(k) || 0) + 1)
  }
  return [...m.entries()].map(([estado, total]) => ({ estado, total })).sort((a, b) => b.total - a.total)
}
export async function casosPorVaga(): Promise<{ vaga_id: string | null; total: number }[]> {
  const { data, error } = await supabase.from('lifecycle_casos').select('vaga_id')
  if (error) throw error
  const m = new Map<string, number>()
  for (const r of (data ?? []) as { vaga_id?: string | null }[]) {
    const k = r.vaga_id || 'SEM_VAGA'
    m.set(k, (m.get(k) || 0) + 1)
  }
  return [...m.entries()].map(([vaga_id, total]) => ({ vaga_id: vaga_id === 'SEM_VAGA' ? 'SEM_VAGA' : vaga_id, total }))
}

// ---- B16 - métricas operacionais ----
export async function metricas(): Promise<{ media_aging_dias: number; pct_p0_concluidas: number; pct_automatizado: number }> {
  const { data: casos } = await supabase.from('lifecycle_casos').select('created_at,estado')
  const { data: tareas } = await supabase.from('lifecycle_tarefas').select('status,gate')
  const now = Date.now()
  let sumAge = 0, nAge = 0
  for (const c of (casos ?? []) as { created_at?: string; estado?: string }[]) {
    if (c.created_at && !['ENCERRADO', 'NAO_SELECIONADO'].includes(c.estado || '')) {
      sumAge += (now - new Date(c.created_at).getTime()) / 86400000; nAge++
    }
  }
  const tAll = (tareas ?? []) as { status?: string; gate?: string }[]
  const p0 = tAll.filter(t => t.gate === 'P0')
  const p0Done = p0.filter(t => t.status === 'COMPLETED').length
  const fechados = (casos ?? [] as { estado?: string }[]).filter(c => ['ENCERRADO', 'NAO_SELECIONADO'].includes(c.estado || '')).length
  const nCasos = (casos ?? []).length
  return {
    media_aging_dias: nAge ? Math.round(sumAge / nAge) : 0,
    pct_p0_concluidas: p0.length ? Math.round((p0Done / p0.length) * 100) : 0,
    pct_automatizado: nCasos ? Math.round((fechados / nCasos) * 100) : 0,
  }
}

// ---- Fase 5: entrevistas ----
export interface LifecycleEntrevista {
  id: string
  caso_id: string
  tipo: string
  data_hora: string | null
  duracao_min: number | null
  local_ou_ligacao: string | null
  entrevistadores: unknown[]
  guiao: string | null
  criterios: unknown[]
  classificacao_geral: number | null
  notas_privadas: string | null
  parecer: string | null
  proximos_passos: string | null
  criado_por: string | null
  criado_em: string
}
export async function listarEntrevistas(casoId: string): Promise<LifecycleEntrevista[]> {
  const { data, error } = await supabase.from('lifecycle_entrevistas').select('*').eq('caso_id', casoId).order('data_hora', { ascending: false })
  if (error) throw error
  return (data ?? []) as LifecycleEntrevista[]
}
export async function salvarEntrevista(ent: Partial<LifecycleEntrevista>) {
  const { data, error } = await supabase.from('lifecycle_entrevistas').upsert(ent).select().maybeSingle()
  if (error) throw error
  return data
}
export async function eliminarEntrevista(id: string) {
  const { error } = await supabase.from('lifecycle_entrevistas').delete().eq('id', id)
  if (error) throw error
}
export async function poolTalento(q?: string): Promise<LifecycleCasoRow[]> {
  let s = supabase.from('lifecycle_casos').select(CASOS_SELECT)
  if (q && q.trim()) {
    s = s.or(`nome.ilike.%${q}%,funcao.ilike.%${q}%,equipa.ilike.%${q}%`)
  }
  const r = await s.order('created_at', { ascending: false }).limit(200)
  if (r.error) throw r.error
  return ((r.data ?? []) as unknown) as LifecycleCasoRow[]
}

// ---- aprovar vaga (passa de APROVACAO_PENDENTE -> APROVADA) ----
export async function aprovarVaga(id: string) {
  const { error } = await supabase.from('lifecycle_vagas')
    .update({ estado: 'APROVADA', aprovado_em: new Date().toISOString() })
    .eq('id', id)
  if (error) throw error
}

// ---- Fase 6: relatórios (export CSV) e RGPD ----
export function downloadCsv(filename: string, headers: string[], rows: (string | number | null)[][]) {
  const esc = (v: string | number | null) => {
    const s = v == null ? '' : String(v)
    return /[";\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s
  }
  const csv = [headers, ...rows].map(r => r.map(esc).join(';')).join('\n')
  const blob = new Blob(['\ufeff' + csv], { type: 'text/csv;charset=utf-8' })
  const a = document.createElement('a')
  a.href = URL.createObjectURL(blob)
  a.download = filename
  a.click()
  URL.revokeObjectURL(a.href)
}
// Tabelas com dados pessoais do LifeCycle, incl. pessoa. Escritas só por Quality/Admin/Management.
const RGPD_TABELAS: Record<string, string[]> = {
  lifecycle_casos: ['nome', 'email', 'telefone', 'equipa', 'funcao'],
  lifecycle_pessoas: ['nome', 'email', 'telefone', 'morada', 'nif', 'nacionalidade'],
  lifecycle_entrevistas: ['notas_privadas', 'entrevistadores'],
}
export async function anonimizarPessoaRgpd(pessoaId: string, casoId: string | null) {
  // Remove dados pessoais identificáveis (retém estatística agregada e o histórico estrutural).
  const [{ error: e1 }, { error: e2 }] = await Promise.all([
    supabase.from('lifecycle_pessoas').update({
      nome: 'Pessoa anonimizada (RGPD)',
      email: null, telefone: null, morada: null, nif: null, nacionalidade: null,
      // texto de análise não guardado aqui; o CV raw é candidato a apagar pela storage
    }).eq('id', pessoaId),
    casoId ? supabase.from('lifecycle_casos').update({
      nome: 'Candidato anonimizado', email: null, telefone: null,
    }).eq('id', casoId) : Promise.resolve({ error: null }),
  ])
  if (e1) throw e1
  if (e2) throw e2
}
export async function apagarCasoRgpd(casoId: string) {
  // Apagamento total do caso (cascades: tarefas, comunicações, avaliações, entrevistas).
  const { error } = await supabase.from('lifecycle_casos').delete().eq('id', casoId)
  if (error) throw error
}
async function authenticatedFetch(url: string, options: RequestInit = {}) {
 const {data:{session}}=await supabase.auth.getSession()
 const headers=new Headers(options.headers)
 if(session)headers.set('Authorization', `Bearer ${session.access_token}`)
 const selected=localStorage.getItem('samsys-qualidade:active-organization-id')
 if(selected)headers.set('x-organization-id',selected)
 return fetch(url,{...options,headers})
}
