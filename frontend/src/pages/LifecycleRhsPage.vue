<script setup lang="ts">
import {datePT} from '@/domain/dates'
import {supabase} from '@/lib/supabase'
import { ref, onMounted, computed } from 'vue'
import {
  listVagas, createVaga, listCasos, createCaso, updateCaso,
  listTarefas, createTarefa, setTarefaStatus, setCasoDataEntrada,
  gerarTarefasAdmissao, gerarTarefasOffboarding, gerarTarefasEstagio,
  listComunicacoes, registarComunicacao, COMUNICACOES, fecharVaga,
  updateVaga, deleteVaga,
  distribuicaoEstados, casosPorVaga, metricas, poolTalento,
  casoStatusLabel, casoStatusTone, SECTOR_LABEL, CASO_STATUS,
} from '@/services/lifecycle'
import type { EstadoCount } from '@/services/lifecycle'
import type {
  LifecycleVaga, LifecycleCasoRow, LifecycleTarefa,
} from '@/services/lifecycle'
import CandidateCvPanel from '@/components/CandidateCvPanel.vue'
import CvQueuePanel from '@/components/CvQueuePanel.vue'
import CandidateWizard from '@/components/CandidateWizard.vue'
import CandidateCvView from '@/components/CandidateCvView.vue'
import { IconUpload, IconScale, IconCalendarEvent, IconFileText, IconSearch, IconFilter, IconLayoutGrid, IconFileDownload } from '@tabler/icons-vue'

const tab = ref<'fila' | 'vagas' | 'nova' | 'analise' | 'pool'>('fila')
const casos = ref<LifecycleCasoRow[]>([])
const vagas = ref<LifecycleVaga[]>([])
const vagaSearch = ref('')
const vagaSortKey = ref<'titulo' | 'referencia' | 'departamento' | 'estado'>('referencia')
const vagaSortDir = ref<'asc' | 'desc'>('asc')
const vagasFiltradas = computed(() => {
  let m = vagas.value
  const s = vagaSearch.value.trim().toLowerCase()
  if (s) m = m.filter(v => (v.titulo || '').toLowerCase().includes(s) || (v.reference || '').toLowerCase().includes(s) || (v.departamento || '').toLowerCase().includes(s) || (v.funcao || '').toLowerCase().includes(s))
  const dir = vagaSortDir.value === 'asc' ? 1 : -1
  return [...m].sort((a, b) => {
    const av = (vagaSortKey.value === 'titulo' ? a.titulo : vagaSortKey.value === 'departamento' ? a.departamento : vagaSortKey.value === 'estado' ? a.estado : a.reference) || ''
    const bv = (vagaSortKey.value === 'titulo' ? b.titulo : vagaSortKey.value === 'departamento' ? b.departamento : vagaSortKey.value === 'estado' ? b.estado : b.reference) || ''
    return av.localeCompare(bv, 'pt') * dir
  })
})
function alternarVagaSort(col: 'titulo' | 'referencia' | 'departamento' | 'estado') {
  if (vagaSortKey.value === col) vagaSortDir.value = vagaSortDir.value === 'asc' ? 'desc' : 'asc'
  else { vagaSortKey.value = col; vagaSortDir.value = 'asc' }
}
const loading = ref(false)
const error = ref('')
const search = ref('')
const sucessMsg = ref('')
const filtroEstado = ref('')
const filtroVaga = ref('')
const filtrosAbertos = ref(false)
const filtrosAtivos = computed(() => {
  let n = 0
  if (filtroEstado.value) n++
  if (filtroVaga.value) n++
  if (search.value.trim()) n++
  return n
})
function limparFiltros() { filtroEstado.value = ''; filtroVaga.value = ''; search.value = ''; page.value = 1 }
const ordenarPor = ref<'created_at' | 'nome' | 'estado'>('created_at')
const ordemDir = ref<'asc' | 'desc'>('desc')
const page = ref(1)
const pageSize = ref(10)

const filtered = computed(() => {
  let m = casos.value
  if (search.value.trim()) {
    const s = search.value.trim().toLowerCase()
    m = m.filter(c => (c.nome || '').toLowerCase().includes(s) || (c.reference || '').toLowerCase().includes(s) || (c.email || '').toLowerCase().includes(s) || (c.funcao || '').toLowerCase().includes(s))
  }
  if (filtroEstado.value) m = m.filter(c => c.estado === filtroEstado.value)
  if (filtroVaga.value) m = m.filter(c => (c.vaga_id || '') === filtroVaga.value)
  // ordenação
  const dir = ordemDir.value === 'asc' ? 1 : -1
  return [...m].sort((a, b) => {
    if (ordenarPor.value === 'nome') return (a.nome || '').localeCompare(b.nome || '', 'pt') * dir
    if (ordenarPor.value === 'estado') return ((a.estado || '').localeCompare(b.estado || '', 'pt')) * dir
    return ((a.created_at || '').localeCompare(b.created_at || '')) * dir
  })
})
const paginado = computed(() => {
  const inicio = (page.value - 1) * pageSize.value
  return filtered.value.slice(inicio, inicio + pageSize.value)
})
const totalPaginas = computed(() => Math.max(1, Math.ceil(filtered.value.length / pageSize.value)))
function mudarPagina(p: number) { page.value = Math.min(totalPaginas.value, Math.max(1, p)) }
function alternarOrdenacao(col: 'created_at' | 'nome' | 'estado') {
  if (ordenarPor.value === col) ordemDir.value = ordemDir.value === 'asc' ? 'desc' : 'asc'
  else { ordenarPor.value = col; ordemDir.value = col === 'nome' || col === 'estado' ? 'asc' : 'desc' }
  page.value = 1
}
function setFiltroEstado() { page.value = 1; load() }
const ESTADOS_DISPONIVEIS = ['NA_FILA', 'EM_TRIAGEM', 'ENTREVISTA', 'SELECIONADO', 'PRE_ADMISSAO', 'READY_DAY1', 'ATIVO', 'OFFBOARDING', 'NAO_SELECIONADO', 'ENCERRADO']
const kpis = computed(() => {
  const total = casos.value.length
  const aberto = casos.value.filter(c => !['SELECIONADO', 'NAO_SELECIONADO', 'ATIVO', 'ENCERRADO'].includes(c.estado || '')).length
  const aEntrevista = casos.value.filter(c => c.estado === 'ENTREVISTA').length
  const sel00 = casos.value.filter(c => c.estado === 'SELECIONADO').length
  const emOff = casos.value.filter(c => c.estado === 'OFFBOARDING').length
  const encerrados = casos.value.filter(c => c.estado === 'ENCERRADO').length
  return { total, aberto, aEntrevista, sel: sel00, emOff, encerrados }
})
function idade(c: { created_at?: string | null }): string {
  if (!c.created_at) return '—'
  const d = (Date.now() - new Date(c.created_at).getTime()) / 86400000
  const n = Math.floor(d)
  return n < 1 ? '<1d' : `${n}d`
}
async function openProtectedCv(c:any) {
 const url=cvUrl(c);if(!url)return;if(new URL(url,window.location.origin).origin!==window.location.origin){window.open(url,'_blank','noopener,noreferrer');return;}
 try {const {data:{session}}=await supabase.auth.getSession();const response=await fetch(url,{headers:{Authorization:`Bearer ${session?.access_token}`}});if(!response.ok)throw new Error('Sem acesso ao CV.');const blob=URL.createObjectURL(await response.blob());const a=document.createElement('a');a.href=blob;a.download='CV.pdf';a.click();setTimeout(()=>URL.revokeObjectURL(blob),1000)}catch(e){alert((e as Error).message)}
}
// URL do CV do candidato: privilegia o cv_url do caso, senão o da pessoa associada.
// Os paths de storage (/storage/v1/object/...) são relativos — prefixar com a base da API.
function cvUrl(c: LifecycleCasoRow): string | null {
  const raw = c.cv_url || c.lifecycle_pessoas?.cv_ultima_url || null
  if (!raw) return null
  const base = (import.meta as unknown as { env?: Record<string,string> }).env?.VITE_SUPABASE_URL || ''
  return raw.startsWith('/') ? (base ? base + raw : raw) : raw
}

// ---- nova candidatura ----
const novo = ref({ nome: '', email: '', telefone: '', vaga_id: '', origem: 'vaga', fonte: 'portal', consentimento: false })
const novoErro = ref('')
async function submeterCandidatura() {
  novoErro.value = ''; sucessMsg.value = ''
  if (!novo.value.nome.trim()) { novoErro.value = 'Nome é obrigatório.'; return }
  if (!novo.value.consentimento) { novoErro.value = 'É necessário o consentimento para tratar os dados da candidatura.'; return }
  loading.value = true
  try {
    const r = await createCaso({
      nome: novo.value.nome.trim(), email: novo.value.email.trim() || null,
      telefone: novo.value.telefone.trim() || null,
      vaga_id: novo.value.vaga_id || null,
      origem: novo.value.origem, fonte: novo.value.fonte,
      tipo: 'recrutamento', consentimento: true,
      estado: 'NA_FILA',
    })
    if (r.duplicado) {
      sucessMsg.value = `Candidatura recebida (${r.caso.reference}). ⚠️ Possível duplicado de ${r.duplicado.reference || 'candidatura prévia'} — sinalizada.`
    } else {
      sucessMsg.value = 'Candidatura recebida com LifeCycle ID atribuído.'
    }
    novo.value = { nome: '', email: '', telefone: '', vaga_id: '', origem: 'vaga', fonte: 'portal', consentimento: false }
    await load()
    tab.value = 'fila'
  } catch (e) { novoErro.value = (e as Error).message || 'Erro ao submeter candidatura.' }
  finally { loading.value = false }
}

// ---- nova vaga ----
const vaga = ref({ titulo: '', departamento: '', funcao: '', tipo: 'colaborador', motivo: '' })
const vagaErro = ref('')
const vagaEditandoId = ref<string | null>(null)
async function criarVaga() {
  vagaErro.value = ''
  if (!vaga.value.titulo.trim()) { vagaErro.value = 'Título da vaga é obrigatório.'; return }
  loading.value = true
  try {
    if (vagaEditandoId.value) {
      await updateVaga(vagaEditandoId.value, { ...vaga.value, motivo: vaga.value.motivo || null })
      sucessMsg.value = `Vaga atualizada.`
      vagaEditandoId.value = null
    } else {
      const ano = new Date().getFullYear()
      const ref = `VG-${ano}-${Date.now().toString().slice(-4)}`
      await createVaga({ reference: ref, ...vaga.value, motivo: vaga.value.motivo || null, estado: 'APROVADA' })
      sucessMsg.value = `Vaga ${ref} criada.`
    }
    vaga.value = { titulo: '', departamento: '', funcao: '', tipo: 'colaborador', motivo: '' }
    await load()
  } catch (e) { vagaErro.value = (e as Error).message || 'Erro.' }
  finally { loading.value = false }
}
function cancelarEdicaoVaga() {
  vagaEditandoId.value = null
  vaga.value = { titulo: '', departamento: '', funcao: '', tipo: 'colaborador', motivo: '' }
  vagaErro.value = ''
}
function editarUmaVaga(v: { id: string; titulo?: string | null; departamento?: string | null; funcao?: string | null; tipo?: string | null; motivo?: string | null }) {
  vagaEditandoId.value = v.id
  vaga.value = {
    titulo: v.titulo || '', departamento: v.departamento || '', funcao: v.funcao || '',
    tipo: v.tipo === 'estagio' ? 'estagio' : 'colaborador', motivo: v.motivo || '',
  }
  window.scrollTo({ top: 0, behavior: 'smooth' })
}
async function eliminarUmaVaga(v: { id: string; reference?: string | null; titulo?: string | null }) {
  const ok = window.confirm(`Eliminar a vaga ${v.reference || ''} "${v.titulo || ''}"? Esta ação não se pode desfazer.`)
  if (!ok) return
  loading.value = true
  try {
    await deleteVaga(v.id)
    sucessMsg.value = `Vaga ${v.reference || ''} eliminada.`
    if (vagaEditandoId.value === v.id) { vagaEditandoId.value = null; vaga.value = { titulo: '', departamento: '', funcao: '', tipo: 'colaborador', motivo: '' } }
    await load()
  } catch (e) { vagaErro.value = (e as Error).message || 'Erro ao eliminar.' }
  finally { loading.value = false }
}
const vagaEstadoLabel: Record<string, string> = {
  APROVADA: 'Aprovada', APROVACAO_PENDENTE: 'Aprovação pendente', ENCERRADA: 'Encerrada',
  CRIAÇÃO: 'Criação', CRIADA: 'Criada', ATIVA: 'Ativa', PENDENTE: 'Pendente', REJEITADA: 'Rejeitada', CANCELADA: 'Cancelada',
}

// mudar estado de um caso na fila
async function moverCaso(c: LifecycleCasoRow, estado: string) {
  await updateCaso(c.id, { estado })
  c.estado = estado
  sucessMsg.value = `${c.reference} → ${casoStatusLabel(estado)}`
}
// detalhe: tarefas do caso
const detalhe = ref<LifecycleCasoRow | null>(null)
const tarefas = ref<LifecycleTarefa[]>([])
const novaTarefa = ref('')
const comunicacoes = ref<Record<string, unknown>[]>([])

// ficha de pessoa + CV (Fase 1/3)
const cvPanel = ref(false)
const cvPanelCaso = ref<LifecycleCasoRow | null>(null)
const cvPanelPessoaId = ref<string | null>(null)
function abrirCvPanel() {
  if (detalhe.value) { cvPanelCaso.value = detalhe.value; cvPanelPessoaId.value = (detalhe.value as any)?.pessoa_id || null; cvPanel.value = true }
}
function abrirCvPanelCaso(c: LifecycleCasoRow) {
  cvPanelCaso.value = c
  cvPanelPessoaId.value = (c as any)?.pessoa_id || null
  cvPanel.value = true
  if (!detalhe.value) detalhe.value = c
}
function fecharCvPanel() { cvPanel.value = false; cvPanelCaso.value = null; cvPanelPessoaId.value = null }
// wizard de ficha 360º (ecrã completo)
const wizardAberto = ref(false)
function abrirWizardFicha() {
  if (detalhe.value) {
    wizardPessoaId.value = (detalhe.value as any)?.pessoa_id || null // eslint-disable-line @typescript-eslint/no-explicit-any
    wizardAberto.value = true
  }
}
const wizardPessoaId = ref<string | null>(null)
function fecharWizard() { wizardAberto.value = false; wizardPessoaId.value = null }
function wizardGravado(_p: unknown) { wizardAberto.value = false; wizardPessoaId.value = null; sucessMsg.value = 'Ficha 360º gravada.'; load() }
// pré-visualização profissional da ficha + exportação PDF
const cvViewAberto = ref(false)
function abrirCvView() {
  if (detalhe.value) {
    cvViewPessoaId.value = (detalhe.value as any)?.pessoa_id || null // eslint-disable-line @typescript-eslint/no-explicit-any
    if (!cvViewPessoaId.value) { sucessMsg.value = 'Este candidato ainda não tem ficha de pessoa — cria primeiro (Ficha ou Importar CV).'; return }
    cvViewAberto.value = true
  }
}
const cvViewPessoaId = ref<string | null>(null)
function importarCvTopo() {
  cvPanelCaso.value = null      // sem caso: cria apenas a ficha/pessoa nova
  cvPanel.value = true
}
// Abre o painel de ficha com uma análise já processada pela fila (job DONE) — sem re-analisar.
const validarJobDados = ref<{ analise: any; texto: string; file_path: string; job_id: string | null } | null>(null) // eslint-disable-line @typescript-eslint/no-explicit-any
function validarCvFila(job: any) { // eslint-disable-line @typescript-eslint/no-explicit-any
  validarJobDados.value = { analise: job.analysis_json, texto: job.extracted_text || '', file_path: job.file_path || '', job_id: job.id || null }
  cvPanelCaso.value = null
  cvPanel.value = true
}
function fecharValidarFila() {
  validarJobDados.value = null
  cvPanel.value = false
}
async function abrirCasoDaFila(casoId: string) {
  try {
    const { listCasos } = await import('@/services/lifecycle')
    const todos = await listCasos()
    const c = todos.find((x) => x.id === casoId)
    if (c) abrirDetalhe(c)
  } catch { /* silencioso */ }
}
const cvQueueRef = ref<InstanceType<typeof CvQueuePanel> | null>(null)
function cvQueued(jobInfo: string) {
  cvPanel.value = false
  cvPanelCaso.value = null
  const n = jobInfo.startsWith('batch:') ? Number(jobInfo.slice(6)) || 0 : 1
  sucessMsg.value = `${n} CV(s) adicionado(s) à fila. O processamento continuará em segundo plano — acompanha o estado no card "Processamento de CV".`
  // refresca e abre a fila para ver os jobs a processar
  setTimeout(() => { try { cvQueueRef.value?.recarregar() } catch { /* silencioso */ } }, 400)
}
async function cvSalvoTopo(pessoa?: any) { // eslint-disable-line @typescript-eslint/no-explicit-any
  const jobIdValidado = validarJobDados.value?.job_id || null
  cvPanel.value = false
  cvPanelCaso.value = null
  validarJobDados.value = null
  try {
    // o "Importar CV no topo" cria a ficha; sem caso associado, cria também a candidatura p/ a grelha
    if (pessoa && pessoa.id) { await criarCasoDePessoa(pessoa as never) }
    // ficha validada: o job sai da fila (arquivado) para não voltar a aparecer
    if (jobIdValidado) { try { await archiveCvJob(jobIdValidado) } catch { /* silencioso */ } }
    sucessMsg.value = 'Ficha criada a partir do CV' + (pessoa && pessoa.id ? ' e candidatura adicionada à fila.' : '.')
  } catch (e) {
    sucessMsg.value = ((e as Error).message || 'Erro ao criar a candidatura.') + ' A ficha foi gravada.'
  }
  await load()
}
async function cvSalvo() {
  cvPanel.value = false
  cvPanelCaso.value = null
  sucessMsg.value = 'Ficha de pessoa gravada e associada à candidatura.'
  await load()
  if (detalhe.value) {
    const { listCasos } = await import('@/services/lifecycle')
    const todos = await listCasos()
    detalhe.value = todos.find(c => c.id === detalhe.value?.id) ?? detalhe.value
  }
}

// ---- Fase 4: avaliação vs vaga ----
import { matchCvVaga, saveAvaliacao, listAvaliacoes, getCvSession, listarEntrevistas, salvarEntrevista, eliminarEntrevista, downloadCsv, anonimizarPessoaRgpd, apagarCasoRgpd, criarCasoDePessoa, archiveCvJob } from '@/services/lifecycle'
const avaliacao = ref<any>(null) // eslint-disable-line @typescript-eslint/no-explicit-any
const avaliando = ref(false)
const avaliacaoErro = ref('')
async function avaliarVsVaga() {
  if (!detalhe.value) return
  avaliacaoErro.value = ''
  const vaga = vagas.value.find(v => v.id === detalhe.value?.vaga_id) || vagas.value[0]
  if (!vaga) { avaliacaoErro.value = 'Sem vaga para comparar.'; return }
  const sess = getCvSession()
  if (!sess || !sess.text) { avaliacaoErro.value = 'Importa primeiro o CV desta candidatura (ou preenche a ficha com o CV) para a IA poder comparar.'; return }
  avaliando.value = true
  try {
    const r = await matchCvVaga(sess.text, sess.analysis, { titulo: vaga.titulo, requisitos: (vaga as any).requisitos, descricao: (vaga as any).motivo || null },
      (ms) => { avaliacao.value = { progresso: ms } })
    avaliacao.value = { ...r.data, progresso: null }
    await saveAvaliacao(detalhe.value.id, vaga.id || null, { ...r.data, modelo_ia: r.model, prompt_version: r.prompt_version })
    sucessMsg.value = 'Avaliação comparativa gerada.'
  } catch (e) {
    avaliacaoErro.value = (e as Error).message || 'Erro na avaliação.'
  } finally { avaliando.value = false }
}
async function abrirDetalhe(c: LifecycleCasoRow) {
  detalhe.value = c
  tarefas.value = await listTarefas(c.id)
  comunicacoes.value = await listComunicacoes(c.id)
}
function fecharDetalhe() { detalhe.value = null; tarefas.value = []; comunicacoes.value = [] }
async function adicionarTarefa() {
  if (!detalhe.value || !novaTarefa.value.trim()) return
  await createTarefa({ caso_id: detalhe.value.id, titulo: novaTarefa.value.trim(), sector: 'rh' })
  tarefas.value = await listTarefas(detalhe.value.id)
  novaTarefa.value = ''
}

// ---- Fase 5: entrevistas ----
import type { LifecycleEntrevista } from '@/services/lifecycle'
const entrevistas = ref<LifecycleEntrevista[]>([])
const showEntrevistas = ref(false)
const novaEntrevista = ref<Partial<LifecycleEntrevista>>({ tipo: 'entrevista', entrevistadores: [], criterios: [], classificacao_geral: null })
const editandoEntrevistaId = ref<string | null>(null)
async function carregarEntrevistas() {
  if (!detalhe.value) return
  entrevistas.value = await listarEntrevistas(detalhe.value.id)
}
function abrirEntrevistas() {
  editandoEntrevistaId.value = null
  novaEntrevista.value = { tipo: 'entrevista', entrevistadores: [], criterios: [], classificacao_geral: null }
  showEntrevistas.value = true
  carregarEntrevistas()
}
function editarEntrevista(e: LifecycleEntrevista) {
  editandoEntrevistaId.value = e.id
  novaEntrevista.value = { ...e, entrevistadores: [...(e.entrevistadores || [])], criterios: [...(e.criterios || [])] }
}
async function guardarEntrevista() {
  if (!detalhe.value) return
  const ent = { ...novaEntrevista.value }
  if (editandoEntrevistaId.value) ent.id = editandoEntrevistaId.value
  ent.caso_id = detalhe.value.id
  await salvarEntrevista(ent)
  sucessMsg.value = 'Entrevista registada.'
  abrirEntrevistas()
}
async function removerEntrevista(e: LifecycleEntrevista) {
  await eliminarEntrevista(e.id)
  carregarEntrevistas()
}
function addEntrevistador() { if (!novaEntrevista.value.entrevistadores) novaEntrevista.value.entrevistadores = []; (novaEntrevista.value.entrevistadores as string[]).push('') }
function addCriterio() { if (!novaEntrevista.value.criterios) novaEntrevista.value.criterios = []; (novaEntrevista.value.criterios as unknown[]).push({ criterio: '', classificacao: null }) }

// ---- Fase 6: relatórios (export CSV) e RGPD ----
async function exportarCasosCsv() {
  try {
    const todos = await listCasos()
    downloadCsv(`candidaturas_${new Date().toISOString().slice(0, 10)}.csv`,
      ['Referência', 'Nome', 'Função', 'Estado', 'Vaga', 'Criado em'],
      todos.map(c => [c.reference, c.nome, c.funcao || '', casoStatusLabel(c.estado), c.lifecycle_vagas?.titulo || 'Espontânea', c.created_at ? new Date(c.created_at).toLocaleDateString('pt-PT') : '']))
    sucessMsg.value = 'CSV de candidaturas exportado.'
  } catch (e) { sucessMsg.value = (e as Error).message || 'Erro no export de candidaturas.' }
}
async function exportarAvaliacoesCsv() {
  try {
    const { listAvaliacoesAll } = await import('@/services/lifecycle')
    const avs = await listAvaliacoesAll()
    downloadCsv(`avaliacoes_${new Date().toISOString().slice(0, 10)}.csv`,
      ['Caso', 'Global', 'Requisitos', 'Preferenciais', 'Competências', 'Experiência', 'Formação', 'Idiomas', 'Recomendação IA', 'Decisão humana'],
      avs.map((a: any) => [a.vaga_id || a.caso_id, a.score_global, a.score_requisitos, a.score_preferenciais, a.score_competencias, a.score_experiencia, a.score_formacao, a.score_idiomas, a.recomendacao_ia || '', a.decisao_humana || ''])) // eslint-disable-line @typescript-eslint/no-explicit-any
    sucessMsg.value = 'CSV de avaliações exportado.'
  } catch (e) { sucessMsg.value = (e as Error).message || 'Erro no export de avaliações.' }
}
async function anonimizarCandidato() {
  if (!detalhe.value) return
  if (!window.confirm('Anonimizar esta ficha? Remove dados pessoais (nome, email, telefone…). Irreversível.')) return
  try {
    const pessoaId = (detalhe.value as any)?.pessoa_id || '' // eslint-disable-line @typescript-eslint/no-explicit-any
    await anonimizarPessoaRgpd(pessoaId, detalhe.value.id)
    sucessMsg.value = 'Ficha anonimizada (RGPD).'
    await load()
  } catch (e) { sucessMsg.value = (e as Error).message || 'Erro na anonimização.' }
}
async function apagarCandidato() {
  if (!detalhe.value) return
  if (!window.confirm('Apagar toda esta candidatura e histórico? Esta ação é IRREVERSÍVEL.')) return
  try {
    await apagarCasoRgpd(detalhe.value.id)
    sucessMsg.value = 'Candidatura apagada (direito ao esquecimento).'
    fecharDetalhe()
    await load()
  } catch (e) { sucessMsg.value = (e as Error).message || 'Erro no apagamento.' }
}

// ---- admissão / Ready for Day 1 ----
const dataEntrada = ref('')
const tipoVinculo = ref('colaborador')
const gerando = ref(false)

const p0Pendentes = computed(() => tarefas.value.filter(t => t.gate === 'P0' && t.status !== 'COMPLETED').length)
const completas = computed(() => tarefas.value.filter(t => t.status === 'COMPLETED').length)
const readyPronto = computed(() => tarefas.value.length > 0 && p0Pendentes.value === 0)

async function definirAdmissao() {
  if (!detalhe.value) return
  await setCasoDataEntrada(detalhe.value.id, dataEntrada.value || null, tipoVinculo.value)
  await updateCaso(detalhe.value.id, { estado: 'PRE_ADMISSAO', estado_admissao: 'EM_PREPARACAO' })
  detalhe.value.data_entrada = dataEntrada.value || null
  detalhe.value.estado = 'PRE_ADMISSAO'
  detalhe.value.estado_admissao = 'EM_PREPARACAO'
  sucessMsg.value = 'Admissão em preparação. Gera as tarefas A01-A20 para seguires o gate.'
}
async function gerarTarefas() {
  if (!detalhe.value) return
  gerando.value = true
  try {
    const n = await gerarTarefasAdmissao(detalhe.value.id, detalhe.value.data_entrada)
    tarefas.value = await listTarefas(detalhe.value.id)
    sucessMsg.value = n ? `${n} tarefas de admissão criadas.` : 'Tarefas já existentes (sem duplicar).'
  } finally { gerando.value = false }
}
async function alternarTarefa(t: LifecycleTarefa) {
  const novoStatus = t.status === 'COMPLETED' ? 'TODO' : 'COMPLETED'
  await setTarefaStatus(t.id, novoStatus)
  if (detalhe.value) tarefas.value = await listTarefas(detalhe.value.id)
}
async function marcarReady() {
  if (!detalhe.value || !readyPronto.value) return
  await updateCaso(detalhe.value.id, { estado: 'READY_DAY1', estado_admissao: 'READY_DAY1', ready_day1_flag: true, ready_day1_em: new Date().toISOString() })
  detalhe.value.estado = 'READY_DAY1'
  detalhe.value.ready_day1_flag = true
  sucessMsg.value = `${detalhe.value.reference} → READY FOR DAY 1`
}

// ---- offboarding ----
const dataSaida = ref('')
const motivoSaida = ref('')
const offGerando = ref(false)
const offReady = computed(() => tarefas.value.filter(t => t.gate === 'P0' && t.status !== 'COMPLETED').length === 0)

async function iniciarOffboarding() {
  if (!detalhe.value) return
  await updateCaso(detalhe.value.id, {
    estado: 'OFFBOARDING', estado_offboarding: 'EM_CURSO',
    data_saida: dataSaida.value || null, motivo_saida: motivoSaida.value || null,
    offboarding_em: new Date().toISOString(),
  })
  detalhe.value.estado = 'OFFBOARDING'; detalhe.value.estado_offboarding = 'EM_CURSO'
  detalhe.value.data_saida = dataSaida.value || null; detalhe.value.motivo_saida = motivoSaida.value || null
  const n = await gerarTarefasOffboarding(detalhe.value.id)
  tarefas.value = await listTarefas(detalhe.value.id)
  sucessMsg.value = n ? `Offboarding iniciado. ${n} tarefas de saída criadas.` : 'Offboarding em curso (tarefas já existentes).'
}
async function encerrarOffboarding() {
  if (!detalhe.value || !offReady.value) return
  await updateCaso(detalhe.value.id, {
    estado: 'ENCERRADO', estado_offboarding: 'CONCLUIDO',
    offboarding_concluido_em: new Date().toISOString(),
  })
  detalhe.value.estado = 'ENCERRADO'; detalhe.value.estado_offboarding = 'CONCLUIDO'
  sucessMsg.value = `${detalhe.value.reference} → caso encerrado.`
}

// ---- B12 - protocolo de estágio ----
async function gerarEstagio() {
  if (!detalhe.value) return
  const n = await gerarTarefasEstagio(detalhe.value.id)
  await updateCaso(detalhe.value.id, { tipo: 'estagio', tipo_vinculo: 'estagio' })
  detalhe.value.tipo = 'estagio'; detalhe.value.tipo_vinculo = 'estagio'
  tarefas.value = await listTarefas(detalhe.value.id)
  sucessMsg.value = n ? `Percurso de estágio ativo (${n} tarefas de protocolo).` : 'Protocolo de estágio já gerado.'
}

// ---- B11 - comunicação ----
async function dispararComunicacao(ref: string) {
  if (!detalhe.value) return
  const c = COMUNICACOES.find(x => x.ref === ref)
  await registarComunicacao({ caso_id: detalhe.value.id, ref, tipo: c?.tipo || 'email', destino: c?.destino, template: c?.template, estado: 'ENVIADO' })
  comunicacoes.value = await listComunicacoes(detalhe.value.id)
  sucessMsg.value = `${ref} registado como enviado (evidência ligada a ${detalhe.value.reference}).`
}

// ---- B11 - fechar vaga ----
async function fecharUmaVaga(v: { id: string; reference?: string | null; titulo?: string | null }) {
  const afetados = await fecharVaga(v.id)
  sucessMsg.value = `Vaga ${v.reference || ''} encerrada. ${afetados} candidatura(s) recusada(s) automaticamente.`
  await load()
}

async function load() {
  loading.value = true; error.value = ''
  try {
    const [c, v] = await Promise.all([listCasos(), listVagas()])
    casos.value = c; vagas.value = v
  } catch (e) { error.value = (e as Error).message || 'Falha ao carregar.' }
  finally { loading.value = false }
}

// ---- B10 - análise ----
const distEstados = ref<EstadoCount[]>([])
const distVagas = ref<{ vaga_id: string | null; total: number }[]>([])
const met = ref<{ media_aging_dias: number; pct_p0_concluidas: number; pct_automatizado: number } | null>(null)
async function carregarAnalise() {
  loading.value = true
  try {
    const [de, dv, mt] = await Promise.all([distribuicaoEstados(), casosPorVaga(), metricas()])
    distEstados.value = de; distVagas.value = dv; met.value = mt
  } catch (e) { error.value = (e as Error).message || 'Falha na análise.' }
  finally { loading.value = false }
}
const maxDist = computed(() => Math.max(1, ...distEstados.value.map(d => d.total)))
const nomeVaga = (id: string | null) => id === 'SEM_VAGA' ? 'Espontâneas' : (vagas.value.find(v => v.id === id)?.titulo || '—')

// ---- B15 - pool de talento ----
const pool = ref<LifecycleCasoRow[]>([])
const poolQ = ref('')
async function carregarPool() {
  loading.value = true
  try { pool.value = await poolTalento(poolQ.value) }
  catch (e) { error.value = (e as Error).message || 'Falha no pool.' }
  finally { loading.value = false }
}
onMounted(load)
</script>

<template>
  <div>
    <div class="d-flex align-items-center justify-content-between mb-3">
      <div>
        <h4 class="mb-0">LifeCycle RH</h4>
        <p class="sq-muted mb-0" style="font-size:.85rem">Ciclo de vida do colaborador · P0 (B01–B03)</p>
      </div>
      <div class="d-flex gap-2">
              <button class="btn btn-outline-secondary btn" :class="tab==='fila'&&'text-primary'" @click="tab='fila';load()">Fila</button>
              <button class="btn btn-outline-secondary btn" :class="tab==='vagas'&&'text-primary'" @click="tab='vagas';load()">Vagas</button>
              <button class="btn btn-outline-secondary btn" :class="tab==='analise'&&'text-primary'" @click="tab='analise';carregarAnalise()">Análise</button>
              <button class="btn btn-outline-secondary btn" :class="tab==='pool'&&'text-primary'" @click="tab='pool';carregarPool()">Pool de talento</button>
              <button class="btn btn-primary" @click="tab='nova'">+ Nova candidatura</button>
              <button class="btn btn-success d-inline-flex align-items-center gap-1" @click="importarCvTopo">
                <IconUpload :size="15" /> Importar CV
              </button>
            </div>
    </div>

    <div v-if="error" class="alert alert-danger py-2" style="font-size:.85rem">{{ error }}</div>
    <div v-if="sucessMsg" class="alert alert-success py-2" style="font-size:.85rem">{{ sucessMsg }}</div>

    <!-- KPIs -->
    <div class="row g-3 mb-3">
          <div class="col-6 col-md-2"><div class="card card"><div class="card-body"><div class="sq-kpi-value">{{ kpis.total }}</div><div class="sq-muted">Casos</div></div></div></div>
          <div class="col-6 col-md-2"><div class="card card"><div class="card-body"><div class="sq-kpi-value">{{ kpis.aberto }}</div><div class="sq-muted">Em curso</div></div></div></div>
          <div class="col-6 col-md-2"><div class="card card"><div class="card-body"><div class="sq-kpi-value">{{ kpis.aEntrevista }}</div><div class="sq-muted">Entrevista</div></div></div></div>
          <div class="col-6 col-md-2"><div class="card card"><div class="card-body"><div class="sq-kpi-value">{{ kpis.sel }}</div><div class="sq-muted">Selecionados</div></div></div></div>
          <div class="col-6 col-md-2"><div class="card card"><div class="card-body"><div class="sq-kpi-value">{{ kpis.emOff }}</div><div class="sq-muted">Offboarding</div></div></div></div>
          <div class="col-6 col-md-2"><div class="card card"><div class="card-body"><div class="sq-kpi-value">{{ kpis.encerrados }}</div><div class="sq-muted">Encerrados</div></div></div></div>
        </div>

    <!-- Fila de processamento de CV (card + popup, não bloqueante) -->
    <CvQueuePanel ref="cvQueueRef" @validar="validarCvFila" @open-caso="abrirCasoDaFila" />

    <!-- FILA -->
    <div v-if="tab==='fila'">
      <div class="card card">
        <div class="card-body">
          <div class="d-flex justify-content-between align-items-center gap-2 mb-2">
            <div class="d-flex align-items-center gap-2">
              <span class="fw-semibold">Fila única de candidaturas</span>
              <span class="sq-badge badge-soft-secondary">{{ filtered.length }}</span>
            </div>
            <div class="d-flex gap-2 align-items-center">
              <div class="position-relative">
                <IconSearch :size="15" class="position-absolute" style="top:50%;left:9px;transform:translateY(-50%);color:var(--sq-muted)" />
                <input class="form-control form-control-sm" style="max-width:190px;padding-left:30px" placeholder="Pesquisar nome, cargo, email…" v-model="search" @input="page=1" />
              </div>
              <button class="btn btn-sm" :class="filtrosAbertos || filtrosAtivos ? 'btn-primary' : 'btn-outline-primary'" @click="filtrosAbertos = !filtrosAbertos" title="Abrir/fechar filtros">
                <IconFilter :size="14" /> Filtros
                <span v-if="filtrosAtivos" class="badge rounded-pill" :class="filtrosAbertos ? 'text-bg-light' : 'text-bg-danger'" style="font-size:.65rem">{{ filtrosAtivos }}</span>
              </button>
              <button v-if="filtrosAtivos" class="btn btn-sm btn-link text-danger p-0" @click="limparFiltros" title="Limpar filtros e pesquisa">Limpar</button>
            </div>
          </div>
          <transition name="sqfade">
          <div v-if="filtrosAbertos" class="border rounded p-2 mb-2 d-flex gap-2 flex-wrap align-items-end" style="background:var(--sq-bg)">
            <div>
              <label class="sq-muted d-block mb-1" style="font-size:.72rem">Estado</label>
              <select class="form-select form-select-sm" style="min-width:170px" v-model="filtroEstado" @change="page=1">
                <option value="">Todos os estados</option>
                <option v-for="e in ESTADOS_DISPONIVEIS" :key="e" :value="e">{{ casoStatusLabel(e) }}</option>
              </select>
            </div>
            <div>
              <label class="sq-muted d-block mb-1" style="font-size:.72rem">Vaga</label>
              <select class="form-select form-select-sm" style="min-width:210px" v-model="filtroVaga" @change="page=1">
                <option value="">Todas as vagas</option>
                <option v-for="v in vagas" :key="v.id" :value="v.id">{{ v.titulo }}</option>
              </select>
            </div>
            <button v-if="filtrosAtivos" class="btn btn-sm btn-outline-danger" @click="limparFiltros">✕ Limpar</button>
          </div>
          </transition>
          <div class="table-responsive">
            <table class="table table-hover align-middle" style="font-size:.9rem">
              <thead><tr class="sq-muted" style="font-size:.75rem;text-transform:uppercase">
                <th class="text-nowrap" title="Ordenar por ID" style="cursor:pointer" @click="alternarOrdenacao('created_at')">Id. {{ ordenarPor==='created_at' ? (ordemDir==='asc'?'▲':'▼') : '' }}</th>
                <th class="text-nowrap" title="Ordenar por nome" style="cursor:pointer" @click="alternarOrdenacao('nome')">Nome {{ ordenarPor==='nome' ? (ordemDir==='asc'?'▲':'▼') : '' }}</th>
                <th>Vaga</th><th>Origem</th><th>Idade</th>
                <th class="text-nowrap" title="Ordenar por estado" style="cursor:pointer" @click="alternarOrdenacao('estado')">Estado {{ ordenarPor==='estado' ? (ordemDir==='asc'?'▲':'▼') : '' }}</th>
                <th>CV</th><th class="text-end">Ações</th>
              </tr></thead>
              <tbody>
                <tr v-for="c in paginado" :key="c.id" @click="abrirDetalhe(c)" style="cursor:pointer">
                  <td class="text-nowrap">{{ c.reference }}</td>
                  <td class="fw-medium">{{ c.nome }}</td>
                  <td>{{ c.lifecycle_vagas?.titulo || '—' }}</td>
                  <td>{{ c.origem === 'espontanea' ? 'Espontânea' : 'Vaga' }}</td>
                  <td><span class="sq-muted" style="font-size:.8rem">{{ idade(c) }}</span></td>
                  <td><span class="sq-badge" :class="`badge-soft-${casoStatusTone(c.estado)}`">{{ casoStatusLabel(c.estado) }}</span></td>
                  <td class="text-center">
                    <a v-if="!!cvUrl(c)" :href="cvUrl(c) || undefined" @click.stop.prevent="openProtectedCv(c)" class="btn btn-sm btn-link p-0 d-inline-flex align-items-center gap-1" title="Abrir CV em nova aba"><IconFileText :size="15" /> CV</a>
                    <span v-else class="sq-muted" style="font-size:.75rem">—</span>
                  </td>
                  <td class="text-end" @click.stop>
                    <button class="btn btn-sm btn-outline-primary me-1 d-inline-flex align-items-center gap-1" @click="abrirCvPanelCaso(c)" title="Importar CV: escolhe o PDF e a ficha é preenchida com os dados extraídos (revisão antes de gravar)">
<IconUpload :size="14" /> Importar CV</button>
                    <button v-if="!['ENTREVISTA','SELECIONADO','NAO_SELECIONADO'].includes(c.estado||'')" class="btn btn-sm btn-outline-primary me-1" @click="moverCaso(c,'EM_TRIAGEM')">Triagem</button>
                    <button v-if="c.estado==='EM_TRIAGEM'" class="btn btn-sm btn-outline-primary me-1" @click="moverCaso(c,'ENTREVISTA')">Entrevista</button>
                    <button v-if="['EM_TRIAGEM','ENTREVISTA','NA_FILA','CANDIDATURA_RECEBIDA'].includes(c.estado||'')" class="btn btn-sm btn-outline-primary me-1" @click="moverCaso(c,'SELECIONADO')">Selecionar</button>
                    <button v-if="['NA_FILA','EM_TRIAGEM','ENTREVISTA'].includes(c.estado||'')" class="btn btn-sm text-danger" @click="moverCaso(c,'NAO_SELECIONADO')">Recusar</button>
                  </td>
                </tr>
                <tr v-if="!filtered.length"><td colspan="6" class="text-center sq-muted py-4">Sem candidaturas.</td></tr>
              </tbody>
            </table>
          </div>
          <div class="d-flex justify-content-between align-items-center mt-2" style="font-size:.8rem">
            <span class="sq-muted">{{ filtered.length }} candidatura(s)</span>
            <div class="d-flex gap-1 align-items-center">
              <button class="btn btn-sm btn-outline-secondary" :disabled="page<=1" @click="mudarPagina(page-1)">‹</button>
              <select class="form-select form-select-sm" style="width:auto" :value="String(page)" @change="page=Number(($event.target as HTMLSelectElement).value)">
                <option v-for="p in totalPaginas" :key="p" :value="String(p)">{{ p }}</option>
              </select>
              <span class="sq-muted">/ {{ totalPaginas }}</span>
              <button class="btn btn-sm btn-outline-secondary" :disabled="page>=totalPaginas" @click="mudarPagina(page+1)">›</button>
              <select class="form-select form-select-sm ms-2" style="width:auto" v-model.number="pageSize" @change="page=1">
                <option :value="10">10</option><option :value="25">25</option><option :value="50">50</option>
              </select>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- VAGAS -->
    <div v-if="tab==='vagas'">
      <div class="card card mb-3">
        <div class="card-body">
          <span class="fw-semibold">{{ vagaEditandoId ? 'Editar vaga' : 'Nova vaga' }}</span>
          <div class="row g-2 mt-2">
            <div class="col-12 col-md-4"><input class="form-control" placeholder="Título (ex.: Desenvolvedor)" v-model="vaga.titulo" /></div>
            <div class="col-6 col-md-2"><input class="form-control" placeholder="Departamento" v-model="vaga.departamento" /></div>
            <div class="col-6 col-md-2"><input class="form-control" placeholder="Função" v-model="vaga.funcao" /></div>
            <div class="col-6 col-md-2">
              <select class="form-select" v-model="vaga.tipo"><option value="colaborador">Colaborador</option><option value="estagio">Estágio</option></select>
            </div>
            <div class="col-6 col-md-2"><input class="form-control" placeholder="Motivo" v-model="vaga.motivo" /></div>
          </div>
          <div v-if="vagaErro" class="text-danger mt-2" style="font-size:.8rem">{{ vagaErro }}</div>
          <div class="mt-2 d-flex gap-2">
            <button class="btn btn-primary" :disabled="loading" @click="criarVaga">{{ vagaEditandoId ? 'Guardar alterações' : 'Criar vaga' }}</button>
            <button v-if="vagaEditandoId" class="btn btn-outline-secondary" :disabled="loading" @click="cancelarEdicaoVaga">Cancelar edição</button>
          </div>
        </div>
      </div>
      <div class="card card">
        <div class="card-body">
          <div class="d-flex justify-content-between align-items-center flex-wrap gap-2 mb-2">
            <span class="fw-semibold">{{ vagasFiltradas.length }} vaga(s)</span>
            <input class="form-control form-control-sm" style="max-width:220px" placeholder="Pesquisar vaga…" v-model="vagaSearch" />
          </div>
          <div class="table-responsive">
            <table class="table table-hover align-middle" style="font-size:.9rem">
              <thead><tr class="sq-muted" style="font-size:.75rem;text-transform:uppercase">
                <th class="text-nowrap" title="Ordenar por referência" style="cursor:pointer" @click="alternarVagaSort('referencia')">Referência {{ vagaSortKey==='referencia' ? (vagaSortDir==='asc'?'▲':'▼') : '' }}</th>
                <th class="text-nowrap" title="Ordenar por título" style="cursor:pointer" @click="alternarVagaSort('titulo')">Título {{ vagaSortKey==='titulo' ? (vagaSortDir==='asc'?'▲':'▼') : '' }}</th>
                <th>Departamento</th><th>Tipo</th>
                <th class="text-nowrap" title="Ordenar por estado" style="cursor:pointer" @click="alternarVagaSort('estado')">Estado {{ vagaSortKey==='estado' ? (vagaSortDir==='asc'?'▲':'▼') : '' }}</th>
                <th class="text-end">Ações</th>
              </tr></thead>
              <tbody>
                <tr v-for="v in vagasFiltradas" :key="v.id" :class="vagaEditandoId===v.id&&'table-active'">
                  <td>{{ v.reference }}</td><td class="fw-medium">{{ v.titulo }}</td><td>{{ v.departamento||'—' }}</td><td>{{ v.tipo==='estagio'?'Estágio':'Colaborador' }}</td><td><span class="badge" :class="v.estado==='ENCERRADA'?'bg-danger':'bg-secondary'" style="font-weight:500;text-transform:capitalize">{{ vagaEstadoLabel[(v.estado || '') as string] || v.estado || '—' }}</span></td>
                  <td class="text-end text-nowrap">
                      <button class="btn btn-sm btn-outline-primary" @click="editarUmaVaga(v)" title="Editar esta vaga">✎ Editar</button>
                      <button v-if="v.estado!=='ENCERRADA'" class="btn btn-sm btn-outline-warning ms-1" @click="fecharUmaVaga(v)" title="Encerrar vaga e recusar automaticamente as candidaturas ativas">Fechar</button>
                      <button v-if="v.estado!=='ENCERRADA'" class="btn btn-sm btn-outline-danger ms-1" @click="eliminarUmaVaga(v)" title="Eliminar definitivamente esta vaga">🗑</button>
                    </td>
                </tr>
                <tr v-if="!vagasFiltradas.length"><td colspan="6" class="text-center sq-muted py-4">Sem vagas.</td></tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>

    <!-- ANÁLISE (B10) -->
    <div v-if="tab==='analise'">
      <div class="d-flex justify-content-end mb-2 gap-2">
        <button class="btn btn-sm btn-outline-primary" @click="exportarCasosCsv">Exportar candidaturas (CSV)</button>
        <button class="btn btn-sm btn-outline-primary" @click="exportarAvaliacoesCsv">Exportar avaliações (CSV)</button>
      </div>
      <div class="row g-3 mb-3">
        <div class="col-md-4"><div class="card card"><div class="card-body">
          <div class="sq-kpi-value">{{ met?.media_aging_dias ?? '—' }} d</div>
          <div class="sq-muted">Aging médio (encaminhamento)</div>
        </div></div></div>
        <div class="col-md-4"><div class="card card"><div class="card-body">
          <div class="sq-kpi-value">{{ met?.pct_p0_concluidas ?? '—' }}%</div>
          <div class="sq-muted">Tarefas P0 concluídas</div>
        </div></div></div>
        <div class="col-md-4"><div class="card card"><div class="card-body">
          <div class="sq-kpi-value">{{ met?.pct_automatizado ?? '—' }}%</div>
          <div class="sq-muted">Processo concluído (automação)</div>
        </div></div></div>
      </div>
      <div class="row g-3">
        <div class="col-md-7"><div class="card card"><div class="card-body">
          <div class="fw-semibold mb-2" style="font-size:.85rem">Distribuição por estado</div>
          <div v-for="d in distEstados" :key="d.estado" class="mb-1">
            <div class="d-flex justify-content-between" style="font-size:.75rem">
              <span>{{ casoStatusLabel(d.estado) }}</span><span class="fw-medium">{{ d.total }}</span>
            </div>
            <div class="progress" style="height:8px"><div class="progress-bar" :style="{width:(d.total/maxDist*100)+'%'}" style="background:var(--sq-primary)"></div></div>
          </div>
        </div></div></div>
        <div class="col-md-5"><div class="card card"><div class="card-body">
          <div class="fw-semibold mb-2" style="font-size:.85rem">Candidaturas por vaga</div>
          <table class="table table-sm align-middle mb-0">
            <tbody>
              <tr v-for="(d, di) in distVagas" :key="String(d.vaga_id ?? 'sv') + di">
                <td style="font-size:.78rem">{{ nomeVaga(d.vaga_id) }}</td><td class="text-end fw-medium">{{ d.total }}</td>
              </tr>
            </tbody>
          </table>
        </div></div></div>
      </div>
    </div>

    <!-- POOL DE TALENTO (B15) -->
    <div v-if="tab==='pool'">
      <div class="card card"><div class="card-body">
        <div class="d-flex gap-2 mb-3">
          <input v-model="poolQ" type="text" class="form-control form-control-sm" placeholder="Pesquisar por nome, função, competência…" @keyup.enter="carregarPool">
          <button class="btn btn-primary btn-sm" @click="carregarPool">Pesquisar</button>
        </div>
        <div class="table-responsive">
          <table class="table table-sm align-middle mb-0">
            <thead><tr class="sq-muted" style="font-size:.72rem;text-transform:uppercase"><th>ID</th><th>Nome</th><th>Função/Equipa</th><th>Estado</th></tr></thead>
            <tbody>
              <tr v-for="p in pool" :key="p.id">
                <td style="font-size:.78rem">{{ p.reference }}</td>
                <td class="fw-medium" style="font-size:.8rem">{{ p.nome }}</td>
                <td style="font-size:.78rem">{{ p.funcao || p.equipa || '—' }}</td>
                <td><span class="sq-badge" :class="'badge-soft-'+casoStatusTone(p.estado)">{{ casoStatusLabel(p.estado) }}</span></td>
              </tr>
              <tr v-if="!pool.length"><td colspan="4" class="text-center sq-muted py-4">Sem resultados no pool de talento.</td></tr>
            </tbody>
          </table>
        </div>
      </div></div>
    </div>

    <!-- NOVA CANDIDATURA -->
    <div v-if="tab==='nova'">
      <div class="card card" style="max-width:680px">
        <div class="card-body">
          <span class="fw-semibold">Receber candidatura</span>
          <p class="sq-muted" style="font-size:.8rem">Cria um caso com LifeCycle ID. Os dados ficam estruturados e entram na fila única.</p>
          <div class="row g-2 mt-2">
            <div class="col-12 col-md-6"><input class="form-control" placeholder="Nome completo *" v-model="novo.nome" /></div>
            <div class="col-12 col-md-6"><input class="form-control" placeholder="Email" v-model="novo.email" /></div>
            <div class="col-12 col-md-6"><input class="form-control" placeholder="Telefone" v-model="novo.telefone" /></div>
            <div class="col-12 col-md-6">
              <select class="form-select" v-model="novo.vaga_id">
                <option value="">— Espontânea —</option>
                <option v-for="v in vagas" :key="v.id" :value="v.id">{{ v.reference }} · {{ v.titulo }}</option>
              </select>
            </div>
            <div class="col-6 col-md-3"><select class="form-select" v-model="novo.origem"><option value="vaga">Vaga</option><option value="espontanea">Espontânea</option></select></div>
            <div class="col-6 col-md-3"><select class="form-select" v-model="novo.fonte"><option value="portal">Portal</option><option value="linkedin">LinkedIn</option><option value="recomendacao">Recomendação</option><option value="outro">Outro</option></select></div>
            <div class="col-12">
              <div class="form-check mt-1">
                <input class="form-check-input" type="checkbox" v-model="novo.consentimento" id="cons" />
                <label class="form-check-label" for="cons" style="font-size:.8rem">A pessoa autoriza o tratamento dos seus dados de candidatura (obrigatório).</label>
              </div>
            </div>
          </div>
          <div v-if="novoErro" class="text-danger mt-2" style="font-size:.8rem">{{ novoErro }}</div>
          <button class="btn btn-primary mt-2" :disabled="loading" @click="submeterCandidatura">Submeter candidatura</button>
        </div>
      </div>
    </div>

    <!-- DETALHE / TAREFAS -->
    <div v-if="detalhe" class="modal-overlay" @click.self="fecharDetalhe">
      <div class="card card" style="max-width:720px; max-height:90vh; overflow:auto">
        <div class="card-body">
          <div class="d-flex justify-content-between align-items-center">
            <span class="fw-semibold">{{ detalhe.reference }} · {{ detalhe.nome }}</span>
            <button class="btn btn-sm btn-close" @click="fecharDetalhe"></button>
          </div>
          <p class="sq-muted" style="font-size:.85rem">{{ detalhe.lifecycle_vagas?.titulo || 'Candidatura espontânea' }} · {{ casoStatusLabel(detalhe.estado) }}</p>
          <button class="btn btn-sm btn-outline-primary mb-2 d-inline-flex align-items-center gap-1" @click="abrirWizardFicha" title="Ficha 360º por etapas — ver e editar todos os dados do candidato">
            <IconLayoutGrid :size="15" /> Ficha
          </button>
          <button class="btn btn-sm btn-outline-dark mb-2 ms-1 d-inline-flex align-items-center gap-1" @click="abrirCvView" title="Pré-visualização profissional da ficha + exportar PDF (completa, anonimizada ou sem notas)">
            <IconFileDownload :size="15" /> CV / PDF
          </button>
          <button class="btn btn-sm btn-outline-success mb-2 ms-1 d-inline-flex align-items-center gap-1" @click="avaliarVsVaga" :disabled="avaliando" title="Compara o CV com a vaga: pontuação explicável por requisito, sem decisão automática">
            <IconScale :size="15" /> {{ avaliando ? 'A comparar…' : 'Avaliar vs vaga' }}
          </button>
          <button class="btn btn-sm btn-outline-info mb-2 ms-1 d-inline-flex align-items-center gap-1" @click="abrirEntrevistas" title="Agendar e registar entrevistas com critérios e parecer">
            <IconCalendarEvent :size="15" /> Entrevistas
          </button>
          <div v-if="avaliacaoErro" class="alert alert-warning py-1 px-2 mb-2" style="font-size:.8rem">{{ avaliacaoErro }}</div>
          <div v-if="avaliando && avaliacao" class="d-flex align-items-center gap-2 sq-muted mb-2" style="font-size:.8rem">
            <span class="spinner-border spinner-border-sm" style="color:var(--sq-success)"></span> A analisar com a IA (pode demorar alguns minutos)… já {{ Math.round((avaliacao.progresso||0)/1000) }}s
          </div>
          <div v-if="avaliacao && !avaliando && !avaliacao.progresso" class="border rounded p-2 mb-3" style="background:rgba(40,199,111,.05)">
            <div class="d-flex align-items-center gap-2 mb-1">
              <span class="fw-semibold" style="font-size:.85rem">Avaliação vs vaga</span>
              <span class="sq-badge" :class="(avaliacao.score_global||0)>=70 ? 'badge-soft-success' : (avaliacao.score_global||0)>=40 ? 'badge-soft-warning' : 'badge-soft-danger'">{{ avaliacao.score_global }}/100</span>
              <span class="sq-muted" style="font-size:.72rem">recomendação IA: {{ avaliacao.recomendacao_ia || '—' }} (decisão final é humana)</span>
            </div>
            <div class="row g-1" style="font-size:.75rem">
              <div class="col-4">Requisitos: <strong>{{ avaliacao.score_requisitos }}</strong></div>
              <div class="col-4">Preferenciais: <strong>{{ avaliacao.score_preferenciais }}</strong></div>
              <div class="col-4">Competências: <strong>{{ avaliacao.score_competencias }}</strong></div>
              <div class="col-4">Experiência: <strong>{{ avaliacao.score_experiencia }}</strong></div>
              <div class="col-4">Formação: <strong>{{ avaliacao.score_formacao }}</strong></div>
              <div class="col-4">Idiomas: <strong>{{ avaliacao.score_idiomas }}</strong></div>
            </div>
            <div v-if="avaliacao.competencias_encontradas?.length" class="mt-1">
              <span class="sq-muted">Encontradas:</span>
              <span v-for="(c,i) in avaliacao.competencias_encontradas" :key="i" class="sq-badge badge-soft-success me-1">{{ c }}</span>
            </div>
            <div v-if="avaliacao.competencias_em_falta?.length" class="mt-1">
              <span class="sq-muted">Em falta:</span>
              <span v-for="(c,i) in avaliacao.competencias_em_falta" :key="i" class="sq-badge badge-soft-danger me-1">{{ c }}</span>
            </div>
            <div v-if="avaliacao.razao?.length" class="mt-1">
              <div class="sq-muted mb-1">Justificação por requisito:</div>
              <ul class="mb-0" style="font-size:.72rem;padding-left:1rem">
                <li v-for="(r,i) in avaliacao.razao.slice(0,12)" :key="i">
                  <span class="me-1">{{ r.requisito }}:</span>
                  <span :class="r.encontrado ? 'text-success' : 'text-danger'">{{ r.encontrado ? '✓' : '✗' }}</span>
                  <span v-if="r.evidencia" class="sq-muted"> · {{ r.evidencia }}</span>
                </li>
              </ul>
            </div>
          </div>
          <div v-if="cvPanel && cvPanelCaso" class="mb-2"><CandidateCvPanel :caso-id="detalhe.id" :caso-nome="detalhe.nome" :pessoa-id-inicial="cvPanelPessoaId" @close="fecharCvPanel" @saved="cvSalvo" /></div>
          <div v-if="detalhe.ready_day1_flag" class="alert alert-success py-1 px-2 mb-2" style="font-size:.8rem">
            ✅ READY FOR DAY 1 · {{ datePT(detalhe.data_entrada) }}
          </div>
          <hr />

          <div class="d-flex gap-2 mb-3 flex-wrap">
            <button v-for="s in CASO_STATUS.filter(x=>['EM_TRIAGEM','ENTREVISTA','SELECIONADO','NAO_SELECIONADO'].includes(x.value))" :key="s.value"
              class="btn btn-sm btn-outline-primary" @click="moverCaso(detalhe, s.value)"
              :title="`Mover para: ${s.label}`">{{ s.label }}</button>
            <button v-if="['SELECIONADO','PRE_ADMISSAO','ATIVO'].includes(detalhe.estado||'')" class="btn btn-sm btn-outline-primary" @click="definirAdmissao" title="Iniciar a fase de pré-admissão">Pré-admissão</button>
            <button v-if="readyPronto" class="btn btn-sm btn-success" @click="marcarReady" title="Todas as tarefas P0 concluídas — libertar o gate Ready for Day 1">Ready for Day 1</button>
            <button v-if="['ATIVO','READY_DAY1'].includes(detalhe.estado||'') || detalhe.estado==='OFFBOARDING'" class="btn btn-sm btn-outline-danger" @click="iniciarOffboarding" title="Iniciar o processo de saída (gera a checklist de offboarding)">Iniciar offboarding</button>
            <button v-if="detalhe.estado==='OFFBOARDING' && offReady" class="btn btn-sm btn-danger" @click="encerrarOffboarding" title="Todas as tarefas P0 de saída concluídas — encerrar o caso">Encerrar caso</button>
            <button v-if="detalhe.tipo!=='estagio' && ['SELECIONADO','PRE_ADMISSAO'].includes(detalhe.estado||'')" class="btn btn-sm btn-outline-info" @click="gerarEstagio" title="Ativar o percurso de estágio (gera tarefas de protocolo)">Percurso estágio</button>
          </div>
          <div v-if="detalhe.aviso_duplicado" class="alert alert-warning py-1 px-2 mb-2" style="font-size:.78rem">
            ⚠️ Sinalizado como possível duplicado deste caso.
          </div>

          <!-- Config admissão -->
          <div class="border rounded p-2 mb-3" style="background:var(--sq-primary-soft)">
            <div class="d-flex gap-2 align-items-end flex-wrap">
              <div>
                <label class="form-label small sq-muted mb-1">Data de entrada</label>
                <PtDateInput type="date" class="form-control form-control-sm" v-model="dataEntrada" />
              </div>
              <div>
                <label class="form-label small sq-muted mb-1">Vínculo</label>
                <select class="form-select form-select-sm" v-model="tipoVinculo">
                  <option value="colaborador">Colaborador</option><option value="estagio">Estágio</option>
                </select>
              </div>
              <button class="btn btn-sm btn-primary" @click="definirAdmissao">Definir admissão</button>
              <button class="btn btn-sm btn-outline-primary" :disabled="gerando" @click="gerarTarefas">
                {{ gerando ? '…' : 'Gerar tarefas A01-A20' }}
              </button>
            </div>
          </div>

          <!-- Estatísticas de admissão -->
          <div v-if="tarefas.length" class="d-flex gap-3 mb-2" style="font-size:.82rem">
            <span class="sq-muted">Completas: <strong>{{ completas }}/{{ tarefas.length }}</strong></span>
            <span class="text-danger">P0 pendentes: <strong>{{ p0Pendentes }}</strong></span>
          </div>

          <!-- Offboarding -->
          <div v-if="detalhe.estado==='OFFBOARDING'" class="border rounded p-2 mb-3" style="background:rgba(234,84,85,.06)">
            <span class="fw-semibold" style="font-size:.82rem">Offboarding · {{ datePT(detalhe.data_saida) }}</span>
            <div class="d-flex gap-2 mt-2 flex-wrap">
              <PtDateInput type="date" class="form-control form-control-sm" style="max-width:170px" v-model="dataSaida" />
              <input class="form-control form-control-sm" style="max-width:260px" placeholder="Motivo da saída" v-model="motivoSaida" />
              <button class="btn btn-sm btn-outline-danger" @click="iniciarOffboarding">Aplicar / regenerar</button>
              <button v-if="offReady" class="btn btn-sm btn-danger" @click="encerrarOffboarding">Encerrar caso</button>
            </div>
            <div v-if="offReady" class="text-success mt-1" style="font-size:.78rem">Todas as tarefas P0 de saída concluídas — pronto a encerrar.</div>
            <div v-else class="text-danger mt-1" style="font-size:.78rem">Aguardar conclusão das tarefas P0 de saída para encerrar o caso.</div>
          </div>

          <!-- Comunicações E01-E12 -->
          <div class="mb-3">
            <span class="fw-semibold" style="font-size:.85rem">Comunicações (E01-E12)</span>
            <div class="d-flex flex-wrap gap-1 mt-1">
              <button v-for="c in COMUNICACOES" :key="c.ref" class="btn btn-sm btn-outline-secondary" style="font-size:.72rem" @click="dispararComunicacao(c.ref)"
                :title="`${c.template} — destino: ${c.destino}`">{{ c.ref }}</button>
            </div>
            <ul v-if="comunicacoes.length" class="list-group list-group-flush mt-1" style="max-height:140px;overflow:auto">
              <li v-for="cm in comunicacoes" :key="String(Array.isArray(cm) ? '' : (cm as any).id)"
                class="list-group-item px-0 d-flex justify-content-between" style="font-size:.75rem">
                <span><strong>{{ (cm as any).ref }}</strong> · {{ (cm as any).template || (cm as any).tipo }}</span>
                <span class="sq-badge badge-soft-success">{{ (cm as any).estado }}</span>
              </li>
            </ul>
            <div v-else class="sq-muted mt-1" style="font-size:.75rem">Sem comunicações registadas neste caso.</div>
          </div>

          <div class="d-flex gap-2 mt-1 mb-2">
            <input class="form-control form-control-sm" v-model="novaTarefa" placeholder="Nova tarefa livre" @keyup.enter="adicionarTarefa" />
            <button class="btn btn-sm btn-primary" @click="adicionarTarefa">+</button>
          </div>
          <div class="border rounded p-2 mt-2" style="background:var(--sq-bg)">
            <div class="fw-semibold mb-1" style="font-size:.8rem">RGPD · direitos do titular</div>
            <div class="d-flex gap-2 flex-wrap">
              <button class="btn btn-sm btn-outline-secondary" @click="anonimizarCandidato" title="Remove dados pessoais identificáveis (nome, email, telefone…), mantém estatística">Anonimizar ficha</button>
              <button class="btn btn-sm btn-outline-danger" @click="apagarCandidato" title="Apaga toda a candidatura e histórico associado (irreversível)">Apagar caso (direito ao esquecimento)</button>
            </div>
          </div>
          <ul class="list-group list-group-flush">
            <li v-for="t in tarefas" :key="t.id" class="list-group-item d-flex justify-content-between align-items-center px-0" style="font-size:.85rem; cursor:pointer" @click="alternarTarefa(t)">
              <span class="d-flex align-items-center gap-2">
                <input type="checkbox" :checked="t.status==='COMPLETED'" @click.stop @change="alternarTarefa(t)" />
                <span :class="t.status==='COMPLETED' ? 'text-decoration-line-through sq-muted' : ''">{{ t.titulo }}</span>
              </span>
              <span class="d-flex gap-2 align-items-center">
                <span v-if="t.sector" class="sq-muted" style="font-size:.72rem">{{ SECTOR_LABEL[t.sector] || t.sector }}</span>
                <span v-if="t.due_date" class="sq-muted" style="font-size:.72rem">{{ datePT(t.due_date) }}</span>
                <span v-if="t.gate" class="sq-badge" :class="t.gate==='P0'?'badge-soft-danger':'badge-soft-secondary'">{{ t.gate }}</span>
              </span>
            </li>
            <li v-if="!tarefas.length" class="list-group-item px-0 sq-muted" style="font-size:.8rem">
              Sem tarefas. Define a admissão e gera as tarefas A01-A20.
            </li>
          </ul>
        </div>
      </div>
    </div>

    <!-- Fase 5: entrevistas -->
    <div v-if="showEntrevistas" class="modal-overlay" @click.self="showEntrevistas=false">
      <div class="card" style="max-width:680px; max-height:90vh; overflow:auto">
        <div class="card-body">
          <div class="d-flex justify-content-between align-items-center mb-2">
            <span class="fw-semibold">Entrevistas · {{ detalhe?.nome }}</span>
            <button class="btn btn-sm btn-close" @click="showEntrevistas=false"></button>
          </div>
          <div v-if="!editandoEntrevistaId" class="border rounded p-2 mb-2">
            <div class="row g-2">
              <div class="col-6"><label class="sq-muted" style="font-size:.72rem">Tipo</label>
                <select class="form-select form-select-sm" v-model="novaEntrevista.tipo">
                  <option value="entrevista">Entrevista</option><option value="tecnico">Técnica</option><option value="hr">RH / Soft skills</option><option value="final">Final</option>
                </select></div>
              <div class="col-6"><label class="sq-muted" style="font-size:.72rem">Data/hora</label>
                <PtDateInput type="datetime-local" class="form-control form-control-sm" v-model="novaEntrevista.data_hora" /></div>
              <div class="col-4"><label class="sq-muted" style="font-size:.72rem">Duração (min)</label>
                <input type="number" class="form-control form-control-sm" v-model.number="novaEntrevista.duracao_min" /></div>
              <div class="col-8"><label class="sq-muted" style="font-size:.72rem">Local / ligação</label>
                <input type="text" class="form-control form-control-sm" v-model="novaEntrevista.local_ou_ligacao" /></div>
              <div class="col-12"><label class="sq-muted" style="font-size:.72rem">Guião</label>
                <textarea class="form-control form-control-sm" rows="2" v-model="novaEntrevista.guiao" placeholder="Pontos a abordar…"></textarea></div>
              <div class="col-12">
                <label class="sq-muted" style="font-size:.72rem">Entrevistadores</label>
                <div v-for="(ev,i) in (novaEntrevista.entrevistadores as string[])" :key="i" class="d-flex gap-1 mb-1">
                  <input class="form-control form-control-sm" v-model="(novaEntrevista.entrevistadores as string[])[i]" placeholder="Nome" />
                  <button class="btn btn-sm btn-outline-danger" @click="(novaEntrevista.entrevistadores as string[]).splice(i,1)">✕</button>
                </div>
                <button class="btn btn-sm btn-outline-secondary" @click="addEntrevistador">+ Entrevistador</button>
              </div>
              <div class="col-12">
                <label class="sq-muted" style="font-size:.72rem">Critérios de avaliação</label>
                <div v-for="(cr,i) in (novaEntrevista.criterios as any[])" :key="i" class="d-flex gap-1 mb-1 align-items-center">
                  <input class="form-control form-control-sm" v-model="cr.criterio" placeholder="Critério (ex. fit técnico)" />
                  <input type="number" min="0" max="10" class="form-control form-control-sm" style="width:80px" v-model.number="cr.classificacao" placeholder="0-10" />
                  <button class="btn btn-sm btn-outline-danger" @click="(novaEntrevista.criterios as any[]).splice(i,1)">✕</button>
                </div>
                <button class="btn btn-sm btn-outline-secondary" @click="addCriterio">+ Critério</button>
              </div>
              <div class="col-6"><label class="sq-muted" style="font-size:.72rem">Classificação geral (0-10)</label>
                <input type="number" min="0" max="10" step="0.1" class="form-control form-control-sm" v-model.number="novaEntrevista.classificacao_geral" /></div>
              <div class="col-6"><label class="sq-muted" style="font-size:.72rem">Parecer</label>
                <select class="form-select form-select-sm" v-model="novaEntrevista.parecer">
                  <option value="">—</option><option value="favoravel">Favorável</option><option value="neutro">Neutro</option><option value="desfavoravel">Desfavorável</option>
                </select></div>
              <div class="col-12"><label class="sq-muted" style="font-size:.72rem">Notas privadas</label>
                <textarea class="form-control form-control-sm" rows="2" v-model="novaEntrevista.notas_privadas"></textarea></div>
              <div class="col-12"><label class="sq-muted" style="font-size:.72rem">Próximos passos</label>
                <input type="text" class="form-control form-control-sm" v-model="novaEntrevista.proximos_passos" /></div>
            </div>
            <div class="d-flex justify-content-end mt-2">
              <button class="btn btn-sm btn-success" @click="guardarEntrevista">Guardar entrevista</button>
            </div>
          </div>
          <div v-else class="border rounded p-2 mb-2">
            <p class="sq-muted" style="font-size:.8rem mb-0">A editar entrevista — <button class="btn btn-sm btn-link p-0" @click="abrirEntrevistas">cancelar</button></p>
          </div>
          <h6 class="sq-muted mt-2" style="font-size:.8rem">Histórico</h6>
          <ul class="list-group list-group-flush">
            <li v-for="e in entrevistas" :key="e.id" class="list-group-item px-0 d-flex justify-content-between align-items-center" style="font-size:.8rem">
              <div>
                <strong>{{ e.tipo }}</strong>
                <span v-if="e.data_hora" class="sq-muted"> · {{ new Date(e.data_hora).toLocaleString('pt-PT') }}</span>
                <span v-if="e.classificacao_geral!=null" class="sq-muted"> · {{ e.classificacao_geral }}/10</span>
                <span v-if="e.parecer" class="sq-badge ms-1" :class="e.parecer==='favoravel'?'badge-soft-success':e.parecer==='desfavoravel'?'badge-soft-danger':'badge-soft-warning'">{{ e.parecer }}</span>
                <div v-if="e.notas_privadas" class="sq-muted" style="font-size:.72rem">{{ e.notas_privadas }}</div>
              </div>
              <div class="d-flex gap-1">
                <button class="btn btn-sm btn-outline-secondary" @click="editarEntrevista(e)">✎</button>
                <button class="btn btn-sm btn-outline-danger" @click="removerEntrevista(e)">🗑</button>
              </div>
            </li>
            <li v-if="!entrevistas.length" class="list-group-item px-0 sq-muted" style="font-size:.8rem">Sem entrevistas registadas.</li>
          </ul>
        </div>
      </div>
    </div>

    <!-- Wizard de ficha 360º (ecrã completo) -->
    <CandidateWizard v-if="wizardAberto" :caso-id="detalhe?.id ?? null" :pessoa-id="wizardPessoaId" @close="fecharWizard" @saved="wizardGravado" />

    <!-- Pré-visualização profissional + exportação PDF -->
    <CandidateCvView v-if="cvViewAberto && cvViewPessoaId" :pessoa-id="cvViewPessoaId" @close="cvViewAberto=false" />

    <!-- IMPORTAR CV NO TOPO (sem caso: cria nova ficha/pessoa) ou VALIDAR a partir da fila -->
    <CandidateCvPanel v-if="cvPanel && !cvPanelCaso && !validarJobDados" @close="fecharCvPanel" @saved="cvSalvoTopo" @queued="cvQueued" />
    <CandidateCvPanel v-if="cvPanel && validarJobDados" :pre-analise="validarJobDados.analise" :pre-texto="validarJobDados.texto" :pre-job-id="validarJobDados.file_path" @close="fecharValidarFila" @saved="cvSalvoTopo" />
  </div>
</template>

<style scoped>
.modal-overlay { position: fixed; inset: 0; background: rgba(15,15,40,.45); display: grid; place-items:center; z-index:1050; padding:1rem; }
.sq-kpi-value { font-size: 1.5rem; font-weight: 600; color: var(--sq-primary); }
.card { border:none; border-radius:.75rem; box-shadow:0 2px 10px rgba(76,69,157,.08); }
.form-control, .form-select { border-radius:.5rem; font-size:.9rem; }
/* transição do painel de filtros */
.sqfade-enter-active, .sqfade-leave-active { transition: opacity .18s ease; }
.sqfade-enter-from, .sqfade-leave-to { opacity: 0; }
</style>