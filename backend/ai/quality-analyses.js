// quality-analyses.js — Análises automáticas do Consultor de Qualidade (documento Melhoria MCP §4).
// Tudo via PostgREST com o TOKEN do utilizador (RLS) — a IA nunca vê dados fora das permissões.
// Regras determinísticas em código (datas, atrasos, totais, agrupamentos, comparações) — a LLM
// apenas explica/propõe. Nunca inventa. Prioridades por dados, nunca por suposição do modelo.
const http = require('http')

const REST_URL = process.env.SUPABASE_REST_URL || 'http://127.0.0.1:3001'
const LIMIT = Number(process.env.AI_MAX_RESULT_ROWS || 300)

function rest(path, token) {
  return new Promise((resolve, reject) => {
    const u = new URL(REST_URL)
    const req = http.request({ hostname: u.hostname, port: u.port, path, method: 'GET', headers: { Authorization: `Bearer ${token}`, apikey: process.env.SUPABASE_ANON_KEY || 'anon', Accept: 'application/json' } }, (res) => {
      let d = ''
      res.on('data', (c) => (d += c))
      res.on('end', () => { try { resolve(JSON.parse(d)) } catch { resolve([]) } })
    })
    req.on('error', reject)
    req.end()
  })
}
const enc = encodeURIComponent
const hoje = () => new Date().toISOString().slice(0, 10)
const dmy = (s) => { if (!s) return '—'; const d = new Date(String(s).slice(0, 10) + 'T00:00:00'); return isNaN(d.getTime()) ? String(s) : `${String(d.getDate()).padStart(2, '0')}/${String(d.getMonth() + 1).padStart(2, '0')}/${d.getFullYear()}` }

/** Dias entre duas datas ISO (yyyy-mm-dd) — negativo = passado (vencido). */
function diffDias(isoIni, isoFim) {
  const a = new Date(isoIni + 'T00:00:00').getTime()
  const b = new Date(isoFim + 'T00:00:00').getTime()
  if (isNaN(a) || isNaN(b)) return null
  return Math.ceil((b - a) / 86400000)
}

async function loadData(token) {
  // ocorrências não encerradas + responsável + eficácia
  const ocorr = await rest(`/quality_occurrences?select=id,reference,type,status,description,responsible_user_id,created_at,updated_at,effectiveness_status,effectiveness_validated_at,cause_analysis,quality_areas(name),quality_origins(name)&limit=${LIMIT * 2}&order=updated_at.desc`, token)
  // todas as ações (para cruzar ocorrência<->ação)
  const acoes = await rest(`/quality_actions?select=id,reference,occurrence_id,description,deadline,status,responsible_user_id,completed_at&limit=${LIMIT * 4}`, token)
  // relações para reincidência
  const rels = await rest(`/quality_occurrence_relations?select=occurrence_id,related_occurrence_id,relation_type&limit=1000`, token).catch(() => [])
  // perfis (responsáveis)
  const ids = [...new Set([...(Array.isArray(ocorr) ? ocorr : []), ...(Array.isArray(acoes) ? acoes : [])].map((x) => x.responsible_user_id).filter(Boolean))]
  let perfis = {}
  if (ids.length) {
    const p = await rest(`/profiles?select=id,full_name&id=in.(${ids.map(enc).join(',')})`, token).catch(() => [])
    for (const x of p) perfis[x.id] = x.full_name || ''
  }
  return { ocorr: Array.isArray(ocorr) ? ocorr : [], acoes: Array.isArray(acoes) ? acoes : [], rels: Array.isArray(rels) ? rels : [], perfis }
}

/** 1) Registos fora do prazo / próximos do prazo. */
function analisarPrazos({ ocorr, acoes }) {
  const h = hoje()
  const foraPrazo = []
  const proximos = []
  for (const a of acoes) {
    if (!a.deadline || a.status === 'COMPLETED') continue
    const d = diffDias(h, String(a.deadline).slice(0, 10))
    if (d === null) continue
    if (d < 0) foraPrazo.push({ ref: a.reference, desc: (a.description || '').slice(0, 60), prazo: dmy(a.deadline), atraso_dias: Math.abs(d), estado: a.status, occurrence_id: a.occurrence_id })
    else if (d <= 3) proximos.push({ ref: a.reference, desc: (a.description || '').slice(0, 60), prazo: dmy(a.deadline), vence_dias: d, estado: a.status, occurrence_id: a.occurrence_id })
  }
  foraPrazo.sort((a, b) => b.atraso_dias - a.atraso_dias)
  proximos.sort((a, b) => a.vence_dias - b.vence_dias)
  return { fora_de_prazo: { total: foraPrazo.length, items: foraPrazo.slice(0, 15) }, a_vencer_3_dias: { total: proximos.length, items: proximos.slice(0, 10) } }
}

/** 2) Ações/ocorrências sem responsável ou sem data prevista; ocorrências sem causa/plano. */
function verificarDadosIncompletos({ ocorr, acoes }) {
  const h = hoje()
  const acoesSemResp = acoes.filter((a) => !a.responsible_user_id && a.status !== 'COMPLETED')
  const acoesSemPrazo = acoes.filter((a) => !a.deadline && a.status !== 'COMPLETED')
  const occSemCausa = ocorr.filter((o) => o.status !== 'CLOSED' && !o.cause_analysis)
  const occSemResp = ocorr.filter((o) => !o.responsible_user_id)
  // concluídas sem evidência de conclusão (sem data de conclusão regista)
  const semEvidencia = acoes.filter((a) => a.status === 'COMPLETED' && !a.completed_at)
  return {
    acoes_sem_responsavel: { total: acoesSemResp.length, items: acoesSemResp.slice(0, 10).map((a) => ({ ref: a.reference, desc: (a.description || '').slice(0, 50) })) },
    acoes_sem_prazo: { total: acoesSemPrazo.length, items: acoesSemPrazo.slice(0, 10).map((a) => ({ ref: a.reference, desc: (a.description || '').slice(0, 50) })) },
    ocorrencias_sem_causa: { total: occSemCausa.length, items: occSemCausa.slice(0, 8).map((o) => ({ ref: o.reference, status: o.status })) },
    ocorrencias_sem_responsavel: { total: occSemResp.length, items: occSemResp.slice(0, 8).map((o) => ({ ref: o.reference, status: o.status })) },
    acoes_concluidas_sem_evidencia: { total: semEvidencia.length, items: semEvidencia.slice(0, 8).map((a) => ({ ref: a.reference, desc: (a.description || '').slice(0, 50) })) },
  }
}

/** 3) Reincidências: ocorrências ligadas por relação de recorrência. */
function analisarReincidencias({ ocorr, rels, ocorrIdRef }) {
  const ligadas = new Set()
  for (const r of rels) {
    if (/reinc|recor|relacio/i.test(r.relation_type || '')) { ligadas.add(r.occurrence_id); ligadas.add(r.related_occurrence_id) }
  }
  // ocorrências repetidas com a MESMA descrição normalizada (heurística forte de reincidência)
  const porDesc = {}
  for (const o of ocorr) {
    const k = (o.description || '').slice(0, 80).toLowerCase().replace(/[^a-z0-9 ]/g, '').trim()
    if (k.length > 20) { (porDesc[k] = porDesc[k] || []).push(o) }
  }
  const repetidas = Object.values(porDesc).filter((g) => g.length > 1).map((g) => g.map((o) => o.reference))
  const reincidentesIds = [...ligadas]
  return {
    reincidentes: reincidentesIds.length,
    reincidentes_refs: reincidentesIds.slice(0, 12).map((id) => ocorrIdRef[id] || id),
    descricoes_repetidas: repetidas.slice(0, 8),
  }
}

/** 4) Responsáveis com excesso de pendências (abertas + vencidas). */
function cargaPorResponsavel({ ocorr, acoes, perfis }) {
  const nome = (id) => perfis[id] || '—'
  const mapa = {}
  const add = (id, cat) => { if (!id) return; (mapa[id] = mapa[id] || { pendentes: 0, vencidas: 0, abertas: 0 }); mapa[id][cat]++ }
  const h = hoje()
  for (const a of acoes) {
    if (a.status === 'COMPLETED') continue
    if (a.deadline && String(a.deadline).slice(0, 10) < h) add(a.responsible_user_id, 'vencidas')
    else add(a.responsible_user_id, 'pendentes')
  }
  // ocorrências abertas e sem haver ação em curso correspondente
  for (const o of ocorr) {
    if (o.status === 'CLOSED') continue
    add(o.responsible_user_id, 'abertas')
  }
  const lista = Object.entries(mapa)
    .map(([id, v]) => ({ responsavel: nome(id), ...v, total: v.pendentes + v.vencidas }))
    .filter((r) => r.total > 0 || r.abertas > 0)
    .sort((a, b) => (b.vencidas + b.pendentes) - (a.vencidas + a.pendentes))
  return { items: lista.slice(0, 12), total_responsaveis: lista.length }
}

/** 5) Tendências: comparação mês atual vs anterior (novas ocorrências, por estado). */
function analisarTendencias({ ocorr }) {
  const d = new Date()
  const mesAtual = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
  d.setMonth(d.getMonth() - 1)
  const mesAnterior = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
  const conta = (prefixo) => ocorr.filter((o) => (o.created_at || '').startsWith(prefixo)).length
  const contei = conta(mesAtual)
  const conteA = conta(mesAnterior)
  const dif = contei - conteA
  return {
    mes_atual: mesAtual, mes_anterior: mesAnterior,
    novas_mes_atual: contei, novas_mes_anterior: conteA,
    variacao: dif, tendencia: dif > 0 ? 'subida' : dif < 0 ? 'descida' : 'estável',
  }
}

/** 6) Eficácia pendente: ações concluídas cuja ocorrência ainda não validou eficácia. */
function eficaciaPendente({ ocorr, acoes }) {
  const pend = []
  const ocById = new Map(ocorr.map((o) => [o.id, o]))
  for (const a of acoes) {
    if (a.status === 'COMPLETED' && a.occurrence_id) {
      const o = ocById.get(a.occurrence_id)
      if (o && o.status !== 'CLOSED' && o.effectiveness_status !== 'EFFECTIVE') {
        pend.push({ occurrence: o.reference, acao: a.reference, desc: (a.description || '').slice(0, 50), eficacia: o.effectiveness_status || '—' })
      }
    }
  }
  return { total: pend.length, items: pend.slice(0, 12) }
}

/** Riscos elevados: ocorrências abertas >30 dias sem avanço + sem eficácia no prazo. */
function riscosElevados({ ocorr, acoes }) {
  const h = hoje()
  const ocById = new Map(ocorr.map((o) => [o.id, o]))
  const atados30 = ocorr.filter((o) => o.status !== 'CLOSED' && diffDias(String(o.updated_at || o.created_at).slice(0, 10), h) !== null && diffDias(String(o.updated_at || o.created_at).slice(0, 10), h) > 30)
  const semAcaoNaoConcluida = ocorr.filter((o) => {
    const suas = acoes.filter((a) => a.occurrence_id === o.id && a.status !== 'COMPLETED')
    return o.status !== 'CLOSED' && suas.length === 0
  })
  return {
    paradas_30dias: { total: atados30.length, items: atados30.slice(0, 8).map((o) => ({ ref: o.reference, status: o.status, responsavel: o.responsible_user_id ? '✓' : '—' })) },
    sem_acao_em_curso: { total: semAcaoNaoConcluida.length, items: semAcaoNaoConcluida.slice(0, 8).map((o) => ({ ref: o.reference, status: o.status })) },
    ocorrencia_de: { count: ocorr.length },
  }
}

/** 7) Pesquisa semântica básica (§17): NCs + ações + causas semelhantes a um termo.
 *  Pontua por sobreposição de tokens (descrição, causa, área, origem, referência); devolve
 *  os mais relevantes com contexto. Apoia a decisão — a fonte de verdade é a BD. */
function pesquisaSemanticaPorTextoTokens(termo, ocorr, acoes) {
  const t = String(termo || '').toLowerCase()
  if (!t.trim()) return { items: [], total: 0, termo }
  const toks = new Set(t.split(/\s+/).filter((w) => w.length > 2))
  const relevancia = (texto) => {
    if (!texto) return 0
    const lt = texto.toLowerCase()
    if (lt.includes(t)) return 100
    const ws = lt.split(/\W+/).filter((w) => w.length > 2)
    let pts = 0
    for (const w of ws) if (toks.has(w)) pts += 3
    return pts
  }
  const ocById = new Map(ocorr.map((o) => [o.id, o]))
  const scored = []
  for (const o of ocorr) {
    const base = `${o.reference} ${o.description || ''} ${o.cause_analysis || ''} ${(o.quality_areas && o.quality_areas.name) || ''} ${(o.quality_origins && o.quality_origins.name) || ''}`
    const pts = relevancia(base)
    if (pts > 0) {
      const suas = acoes.filter((a) => a.occurrence_id === o.id)
      scored.push({
        reference: o.reference, type: o.type, status: o.status,
        descricao: (o.description || '').slice(0, 120),
        causa: o.cause_analysis || null,
        area: (o.quality_areas && o.quality_areas.name) || null,
        origem: (o.quality_origins && o.quality_origins.name) || null,
        relevancia: pts,
        n_acoes: suas.length,
        acoes: suas.slice(0, 5).map((a) => ({ ref: a.reference, desc: (a.description || '').slice(0, 60), estado: a.status })),
        url: `/ocorrencias/${o.id}`,
      })
    }
  }
  scored.sort((a, b) => b.relevancia - a.relevancia)
  return { total: scored.length, termo, items: scored.slice(0, 15) }
}

/** 8) Alertas inteligentes (§16): agrega sinais que merecem atenção sem ruído. */
async function alertasInteligentes(token) {
  const data = await loadData(token)
  const h = hoje()
  const alertas = []
  // ação vence nas próximas 72h
  const vence72 = []
  for (const a of data.acoes) {
    if (a.status === 'COMPLETED' || !a.deadline) continue
    const d = diffDias(h, String(a.deadline).slice(0, 10))
    if (d !== null && d >= 0 && d <= 3) vence72.push({ ref: a.reference, desc: (a.description || '').slice(0, 50), vence_dias: d })
  }
  if (vence72.length) alertas.push({ tipo: 'vence_72h', nivel: 'atenção', total: vence72.length, refs: vence72.slice(0, 10) })
  // paradas há +30 dias
  const paradas = data.ocorr.filter((o) => o.status !== 'CLOSED' && diffDias(String(o.updated_at || o.created_at).slice(0, 10), h) !== null && diffDias(String(o.updated_at || o.created_at).slice(0, 10), h) > 30)
  if (paradas.length) alertas.push({ tipo: 'parada_30d', nivel: 'atenção', total: paradas.length, refs: paradas.map((o) => o.reference).slice(0, 8) })
  // resumo simples
  return { hoje: h, alertas, total_alertas: alertas.length }
}

async function pesquisarSemantica(token, termo) {
  const data = await loadData(token)
  return pesquisaSemanticaPorTextoTokens(termo, data.ocorr, data.acoes)
}

async function alertas(token) {
  return alertasInteligentes(token)
}

module.exports = {
  analiseCompleta, analisePrazos, analiseIncompletos, analiseReincidencias, analiseCarga, analiseTendencias, analiseEficacia, analiseRiscos,
  pesquisarSemantica, alertas,
  dmy, diffDias,
}

/** Entrada principal: consolida todas as verificações automáticas do documento §4. */
async function analiseCompleta(token, opts = {}) {
  const data = await loadData(token)
  const ocorrIdRef = new Map(data.ocorr.map((o) => [o.id, o.reference]))
  const prazos = analisarPrazos(data)
  const incompletos = verificarDadosIncompletos(data)
  const reincidencias = analisarReincidencias({ ...data, ocorrIdRef })
  const carga = cargaPorResponsavel(data)
  const tendencias = analisarTendencias(data)
  const eficacia = eficaciaPendente(data)
  const riscos = riscosElevados(data)

  const resumo = {
    prazos, dados_incompletos: incompletos, reincidencias, carga_responsaveis: carga,
    tendencias, eficacia_pendente: eficacia, riscos,
  }
  // contagem global de "sinais de atenção"
  const nSinais =
    prazos.fora_de_prazo.total + prazos.a_vencer_3_dias.total +
    incompletos.acoes_sem_responsavel.total + incompletos.acoes_sem_prazo.total +
    incompletos.ocorrencias_sem_causa.total + incompletos.ocorrencias_sem_responsavel.total +
    incompletos.acoes_concluidas_sem_evidencia.total +
    eficacia.total + riscos.paradas_30dias.total + riscos.sem_acao_em_curso.total
  resumo.total_sinais_atencao = nSinais
  resumo.hoje = hoje()
  return resumo
}

/** Verificações individuais para tools MCP dedicadas (cada uma devolve só a sua análise). */
async function analisePrazos(token) { return analisarPrazos(await loadData(token)) }
async function analiseIncompletos(token) { return verificarDadosIncompletos(await loadData(token)) }
async function analiseReincidencias(token) {
  const d = await loadData(token)
  const ocorrIdRef = new Map(d.ocorr.map((o) => [o.id, o.reference]))
  return analisarReincidencias({ ...d, ocorrIdRef })
}
async function analiseCarga(token) { return cargaPorResponsavel(await loadData(token)) }
async function analiseTendencias(token) { return analisarTendencias(await loadData(token)) }
async function analiseEficacia(token) { return eficaciaPendente(await loadData(token)) }

async function analiseRiscos(token) { return riscosElevados(await loadData(token)) }