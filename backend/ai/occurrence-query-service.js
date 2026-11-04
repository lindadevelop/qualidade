// occurrence-query-service.js — executa planos validados contra a API (PostgREST)
// SEGURANÇA: as consultas usam o ACCESS TOKEN DO PRÓPRIO UTILIZADOR (Authorization bearer).
// O PostgREST aplica o mesmo RLS da interface normal — a IA nunca obtém dados fora das permissões (§8, §36).
const http = require('http')

const REST_URL = process.env.SUPABASE_REST_URL || 'http://127.0.0.1:3001'
const MAX_ROWS = Number(process.env.AI_MAX_RESULT_ROWS || 100)

function rest(path, token, { method = 'GET', body } = {}) {
  return new Promise((resolve, reject) => {
    const u = new URL(REST_URL)
    const payload = body ? JSON.stringify(body) : null
    const req = http.request(
      {
        hostname: u.hostname, port: u.port, path, method,
        headers: {
          Authorization: `Bearer ${token}`,
          apikey: process.env.SUPABASE_ANON_KEY || 'anon',
          'Content-Type': 'application/json',
          Accept: 'application/json',
        },
      },
      (res) => {
        let data = ''
        res.on('data', (c) => (data += c))
        res.on('end', () => {
          try { resolve({ status: res.statusCode, data: data ? JSON.parse(data) : null }) }
          catch { resolve({ status: res.statusCode, data }) }
        })
      },
    )
    req.on('error', reject)
    if (payload) req.write(payload)
    req.end()
  })
}

function ilikeArr(field, values) {
  return values.map((v) => `${field}=ilike.*${encodeURIComponent(v)}*`).join(',')
}

/**
 * Constrói query SELECT (embedding de relações) a partir do plano validado.
 * groupBy<->relação: area->quality_areas(name), origin->quality_origins(name),
 * responsible->profiles:responsible_user_id(full_name), month->created_at.
 */
function buildSelect(plan) {
  const base = 'reference,type,status,occurrence_date,created_at,updated_at,closed_at,description,responsible_user_id'
    + ',quality_areas(name),quality_origins(name),profiles:responsible_user_id(full_name)'
  if (!plan.groupBy) return base
  switch (plan.groupBy) {
    case 'area': return 'quality_areas(name),count'
    case 'origin': return 'quality_origins(name),count'
    case 'responsible': return 'profiles:responsible_user_id(full_name),count'
    case 'type': return 'type,count'
    case 'status': return 'status,count'
    case 'month': return 'created_at,count'
    default: return base
  }
}

function buildFilters(plan) {
  const f = plan.filters || {}
  const parts = []
  if (f.status && f.status.length) parts.push(`status=in.(${f.status.join(',')})`)
  if (f.type) parts.push(`type=eq.${f.type}`)
  if (f.area_name) parts.push(ilikeArr('quality_areas(name)', f.area_name))
  if (f.origin_name) parts.push(ilikeArr('quality_origins(name)', f.origin_name))
  if (f.responsible_name) parts.push(ilikeArr('profiles(full_name)', f.responsible_name))
  if (f.date_from) parts.push(`occurrence_date=gte.${f.date_from}`)
  if (f.date_to) parts.push(`occurrence_date=lt.${f.date_to}`)
  if (f.occurrence_date_from) parts.push(`occurrence_date=gte.${f.occurrence_date_from}`)
  if (f.occurrence_date_to) parts.push(`occurrence_date=lt.${f.occurrence_date_to}`)
  if (f.created_after) parts.push(`created_at=gte.${f.created_after}`)
  if (f.created_before) parts.push(`created_at=lt.${f.created_before}`)
  if (f.updated_before) parts.push(`updated_at=lt.${f.updated_before}`)
  if (f.unassigned) parts.push('responsible_user_id=is.null')
  if (f.days_since_update) {
    const d = new Date()
    d.setDate(d.getDate() - f.days_since_update)
    parts.push(`updated_at=lt.${d.toISOString()}`)
  }
  return parts.join('&')
}

/** Executa o plano e devolve estrutura apresentável (count/list/grupos). */
async function executePlan(plan, token) {
  // primeiro: aplicar período semântico quando presente
  const { resolvePeriod } = require('./query-validator')
  if (plan.filters.period) {
    const r = resolvePeriod(plan.filters.period)
    if (r) { plan.filters.date_from = plan.filters.date_from || r.from; plan.filters.date_to = plan.filters.date_to || r.to }
    delete plan.filters.period
  }

  const f = plan.filters || {}
  const groupBy = plan.groupBy

  // --- via RPC seguro ai_occurrence_search (filtra por nome; respeita RLS) ---
  // contagem/agrupamento exigem ver todos; listas usam o limite pedido.
  const needAll = groupBy !== null || plan.metric === 'count'
  const rpcBody = buildRpcBody(plan)
  if (needAll) rpcBody.p_limit = Number(process.env.AI_MAX_RESULT_ROWS || 100)
  const rpcPath = '/rpc/ai_occurrence_search'
  const res = await rest(rpcPath, token, { method: 'POST', body: rpcBody })
  if (res.status >= 400) throw new Error(res.data?.message || `Erro API (${res.status})`)

  if (groupBy) {
    const rows = Array.isArray(res.data) ? res.data : []
    const groups = new Map()
    for (const r of rows) {
      let key
      switch (groupBy) {
        case 'area': key = r.area_name || '(sem área)'; break
        case 'origin': key = r.origin_name || '(sem origem)'; break
        case 'responsible': key = r.responsible_name || '(sem responsável)'; break
        case 'type': key = r.type; break
        case 'status': key = r.status; break
        case 'month': key = (r.created_at || '').slice(0, 7); break
        default: key = 'total'
      }
      groups.set(key, (groups.get(key) || 0) + 1)
    }
    const arr = [...groups.entries()].map(([k, v]) => ({ key: k, count: v }))
    if (plan.order === 'desc') arr.sort((a, b) => b.count - a.count)
    else arr.sort((a, b) => a.count - b.count)
    const top = arr.slice(0, plan.limit || 10)
    return { type: 'grouped', groups: top, total: rows.length }
  }

  if (plan.metric === 'count') {
    const rows = Array.isArray(res.data) ? res.data : []
    return { type: 'count', count: rows.length }
  }

  // lista controlada
  const rows = Array.isArray(res.data) ? res.data : []
  return {
    type: 'list',
    rows: rows.map((r) => ({
      id: r.id, reference: r.reference, type: r.type, status: r.status,
      area: r.area_name ?? null, origin: r.origin_name ?? null,
      responsible: r.responsible_name ?? null,
      occurrence_date: r.occurrence_date, description: (r.description || '').slice(0, 120),
      url: `/ocorrencias/${r.id}`,
    })),
  }
}

/** Constrói o body da RPC a partir do plano validado. */
function buildRpcBody(plan) {
  const f = plan.filters || {}
  const body = { p_limit: Math.min(plan.limit || 100, Number(process.env.AI_MAX_RESULT_ROWS || 100)) }
  if (f.status && f.status.length) body.p_status = f.status
  if (f.type) body.p_type = f.type
  if (f.area_name) body.p_area_name = f.area_name
  if (f.origin_name) body.p_origin_name = f.origin_name
  if (f.responsible_name) body.p_responsible_name = f.responsible_name
  if (f.date_from) body.p_date_from = f.date_from
  if (f.date_to) body.p_date_to = f.date_to
  if (f.unassigned) body.p_unassigned = true
  if (f.search) body.p_search = f.search
  return body
}

module.exports = { executePlan, buildFilters, buildSelect }