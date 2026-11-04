// consultor-service.js — Consultor Operacional da Qualidade.
// Calcula PRIORIDADES por regras OBJETIVAS e EXPLICÁVEIS em código (não na LLM):
// ações vencidas/prestes a vencer, ocorrências sem responsável/ação, eficácia pendente,
// reincidências, paradas, bloqueios. A LLM explica e propõe, nunca decide sozinha a prioridade.
// Tudo via PostgREST com o TOKEN do utilizador (RLS) — a IA nunca vê fora das permissões.
const http = require('http')

const REST_URL = process.env.SUPABASE_REST_URL || 'http://127.0.0.1:3001'

function rest(path, token) {
  return new Promise((resolve, reject) => {
    const u = new URL(REST_URL)
    const req = http.request({ hostname: u.hostname, port: u.port, path, method: 'GET', headers: { Authorization: `Bearer ${token}`, apikey: process.env.VITE_SUPABASE_ANON_KEY || 'anon', Accept: 'application/json' } }, (res) => { let d = ''; res.on('data', (c) => (d += c)); res.on('end', () => { try { resolve(JSON.parse(d)) } catch { resolve([]) } }) })
    req.on('error', reject); req.end()
  })
}

// ---- regras de prioridade (configuráveis, explicáveis) ----
const RULES = {
  acao_vencida_mais_7d: { pontos: 50, rotulo: 'ação vencida há mais de 7 dias' },
  acao_vencida_ate_7d: { pontos: 40, rotulo: 'ação vencida até 7 dias' },
  acao_vence_ate_3d: { pontos: 30, rotulo: 'ação vence nos próximos 3 dias' },
  sem_responsavel: { pontos: 25, rotulo: 'ocorrência sem responsável atribuído' },
  eficacia_pendente: { pontos: 35, rotulo: 'ação concluída a aguardar validação de eficácia' },
  reincidencia: { pontos: 20, rotulo: 'reincidência (relação com ocorrência anterior)' },
  parada_demais: { pontos: 15, rotulo: 'parada há mais de 30 dias sem atualização' },
}

function nivelDe(pontos) {
  if (pontos >= 50) return 'Crítica'
  if (pontos >= 30) return 'Alta'
  if (pontos >= 15) return 'Média'
  return 'Baixa'
}

function diasDesde(s) {
  if (!s) return null
  const t = new Date(s).getTime(); if (isNaN(t)) return null
  return Math.floor((Date.now() - t) / 86400000)
}

/** Converte data ISO para dd/mm/aaaa (para apresentação). */
function dmy(s) { if (!s) return '—'; const d = new Date(s + (String(s).length === 10 ? 'T00:00:00' : '')); if (isNaN(d.getTime())) return String(s); return `${String(d.getDate()).padStart(2, '0')}/${String(d.getMonth() + 1).padStart(2, '0')}/${d.getFullYear()}` }

/**
 * Calcula as prioridades da Qualidade a partir dos dados reais.
 * @param {string} token token do utilizador
 * @param {number} limit quantos devolver (default 10)
 * @returns {Promise<{prioridades: Array, regras: object, hoje: string}>}
 */
async function calcularPrioridades(token, limit = 10) {
  const enc = encodeURIComponent
  const hoje = new Date().toISOString().slice(0, 10)

  // ocorrências não encerradas (detalhe: estado + eficácia + datas + responsável)
  const ocorr = await rest(`/quality_occurrences?select=id,reference,type,status,description,responsible_user_id,created_at,updated_at,effectiveness_status&not.and=(status.eq.CLOSED)&order=updated_at.desc&limit=${Number(process.env.AI_MAX_RESULT_ROWS || 200)}`, token)
  const occs = Array.isArray(ocorr) ? ocorr : []

  // ações por ocorrência (todas as não concluídas + concluídas recentes)
  const acoes = await rest(`/quality_actions?select=id,reference,occurrence_id,description,deadline,status,responsible_user_id,completed_at&limit=${Number(process.env.AI_MAX_RESULT_ROWS || 400)}`, token)
  const acts = Array.isArray(acoes) ? acoes : []

  // relações (reincidência)
  const rels = await rest(`/quality_occurrence_relations?select=occurrence_id,related_occurrence_id,relation_type&limit=500`, token)
  const relArr = Array.isArray(rels) ? rels : []
  const reincidentes = new Set()
  for (const r of relArr) if (/reinc|recor|relacio/i.test(r.relation_type || '')) { reincidentes.add(r.occurrence_id); reincidentes.add(r.related_occurrence_id) }

  // agrupa ações por ocorrência
  const acoesPorOcc = new Map()
  const responsaveisAcoes = new Set()
  for (const a of acts) {
    if (!a.occurrence_id) continue
    if (a.responsible_user_id) responsaveisAcoes.add(a.responsible_user_id)
    if (!acoesPorOcc.has(a.occurrence_id)) acoesPorOcc.set(a.occurrence_id, [])
    acoesPorOcc.get(a.occurrence_id).push(a)
  }

  const ocorrIdResp = new Map() // occurrence_id -> {responsable_name}
  try {
    const ids = [...new Set(occs.map((o) => o.responsible_user_id).filter(Boolean))]
    if (ids.length) {
      const resp = await rest(`/profiles?select=id,full_name&id=in.(${ids.map(enc).join(',')})`, token)
      for (const p of resp) ocorrIdResp.set(p.id, p.full_name || '')
    }
  } catch {}

  const prioridades = []

  for (const o of occs) {
    const pont = []
    const janela = (o.updated_at || o.created_at)
    const pp = ocorrIdResp.get(o.responsible_user_id) || null

    const occAcoes = acoesPorOcc.get(o.id) || []
    const vencidas = occAcoes.filter((a) => a.deadline && a.status !== 'COMPLETED' && a.deadline < hoje)
    const aVencer = occAcoes.filter((a) => a.deadline && a.status !== 'COMPLETED' && a.deadline >= hoje)
    const concluidasPendentes = occAcoes.filter((a) => a.status === 'COMPLETED' && (!o.effectiveness_status || o.effectiveness_status !== 'EFFECTIVE'))

    if (!o.responsible_user_id) pont.push({ pts: RULES.sem_responsavel.pontos, motivo: RULES.sem_responsavel.rotulo })

    for (const a of vencidas) {
      const d = diasDesde(a.deadline + 'T00:00:00')
      pont.push({ pts: (d !== null && d > 7) ? RULES.acao_vencida_mais_7d.pontos : RULES.acao_vencida_ate_7d.pontos, motivo: `${RULES.acao_vencida_mais_7d.rotulo}${d !== null ? ` (há ${d} dias)` : ''}` })
    }
    for (const a of aVencer) {
      const d = diasDesde(a.deadline + 'T00:00:00')
      if (d !== null && d <= 3 && d >= 0) pont.push({ pts: RULES.acao_vence_ate_3d.pontos, motivo: RULES.acao_vence_ate_3d.rotulo })
    }
    if (concluidasPendentes.length) pont.push({ pts: RULES.eficacia_pendente.pontos, motivo: RULES.eficacia_pendente.rotulo })

    if (reincidentes.has(o.id)) pont.push({ pts: RULES.reincidencia.pontos, motivo: RULES.reincidencia.rotulo })

    if (!o.responsible_user_id && !occAcoes.length) pont.push({ pts: 0, motivo: 'sem ação nem responsável' })
    const parada = diasDesde(janela)
    if (parada !== null && parada > 30 && o.status !== 'CLOSED') pont.push({ pts: RULES.parada_demais.pontos, motivo: `${RULES.parada_demais.rotulo} (${parada} dias)` })

    const pontos = pont.reduce((s, p) => s + p.pts, 0)
    if (pontos === 0 && o.status === 'IN_PROGRESS') continue // evitar lixo (em curso sem sinais)

    prioridades.push({
      reference: o.reference,
      type: o.type,
      status: o.status,
      description: (o.description || '').slice(0, 90),
      prioridade: nivelDe(pontos),
      pontos,
      motivo: [...new Set(pont.map((p) => p.motivo))].filter(Boolean),
      responsavel: pp,
      eficacia: o.effectiveness_status || '—',
      url: `/ocorrencias/${o.id}`,
      ultima_atualizacao: dmy((o.updated_at || o.created_at || '').slice(0, 10)),
      acoes: occAcoes.map((a) => ({ ref: a.reference, desc: (a.description || '').slice(0, 50), prazo: dmy(a.deadline), estado: a.status, responsavel_resp: !!a.responsible_user_id })),
    })
  }

  // ordena por pontos desc, depois por vencimento mais antigo
  prioridades.sort((a, b) => b.pontos - a.pontos || (a.reference < b.reference ? -1 : 1))
  return { hoje: dmy(hoje), regras: RULES, prioridades: prioridades.slice(0, limit), total: prioridades.length }
}

module.exports = { calcularPrioridades, nivelDe, dmy, diasDesde, RULES }