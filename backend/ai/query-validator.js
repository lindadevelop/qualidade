// query-validator.js — validação FORTE do plano devolvido pelo modelo (§18)
// Nunca confiar no modelo: cada campo é verificado contra o catálogo.
const { INTENTS, SENSITIVE_FIELDS } = require('./intent-catalog')

const VALID_STATUS = ['OPEN', 'IN_PROGRESS', 'AWAITING_EFFECTIVENESS', 'CLOSED']
const VALID_TYPE = ['NC', 'OM']
const VALID_ACTION_STATUS = ['TODO', 'IN_PROGRESS', 'COMPLETED']
const MAX_LIMIT = 100
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/

function isSensitive(key) {
  return SENSITIVE_FIELDS.some((s) => key === s || key.startsWith(s))
}

/**
 * Valida o plano JSON devolvido pelo Ollama.
 * Devolve: { ok: true, plan: <plano normalizado> } | { ok: false, error: <mensagem> }
 */
function validatePlan(raw) {
  if (!raw || typeof raw !== 'object') return { ok: false, error: 'Plano inválido' }

  const intent = typeof raw.intent === 'string' ? raw.intent : ''
  if (!INTENTS[intent]) return { ok: false, error: `Intent não autorizado: ${intent || '(vazio)'}` }

  const def = INTENTS[intent]
  const filters = raw.filters && typeof raw.filters === 'object' ? raw.filters : {}
  const groupBy = raw.group_by || null
  const metric = raw.metric || 'count'
  const order = raw.order || null
  const limit = Math.min(Number(raw.limit) || 20, MAX_LIMIT)

  // --- validação do agrupamento ---
  if (groupBy && !(def.allowGroupBy || []).includes(groupBy)) {
    return { ok: false, error: `Agrupamento não autorizado para ${intent}: ${groupBy}` }
  }

  // --- validação de filtros autorizados ---
  const allowedFilterKeys = [
    'status', 'type', 'area_id', 'area_name', 'origin_id', 'origin_name',
    'responsible_user_id', 'responsible_name', 'date_from', 'date_to',
    'occurrence_date_from', 'occurrence_date_to', 'created_before', 'created_after',
    'updated_before', 'updated_after', 'days_since_update', 'unassigned', 'period',
    'action_status', 'has_open_actions',
  ]
  for (const key of Object.keys(filters)) {
    if (!allowedFilterKeys.includes(key) || isSensitive(key)) {
      return { ok: false, error: `Filtro não autorizado: ${key}` }
    }
  }

  const cleanFilters = {}
  const f = filters

  if (f.status) {
    const arr = Array.isArray(f.status) ? f.status : [f.status]
    cleanFilters.status = arr.map((s) => String(s).toUpperCase()).filter((s) => VALID_STATUS.includes(s))
    if (cleanFilters.status.length !== arr.length) return { ok: false, error: 'Valor de estado inválido' }
  }
  if (f.type) {
    const t = String(f.type).toUpperCase()
    if (!VALID_TYPE.includes(t)) return { ok: false, error: 'Tipo inválido (use NC ou OM)' }
    cleanFilters.type = t
  }
  if (f.action_status) {
    const a = String(f.action_status).toUpperCase()
    if (!VALID_ACTION_STATUS.includes(a)) return { ok: false, error: 'Estado de ação inválido' }
    cleanFilters.action_status = a
  }
  if (f.area_name) cleanFilters.area_name = fuzzyJoin(f.area_name)
  if (f.origin_name) cleanFilters.origin_name = fuzzyJoin(f.origin_name)
  if (f.responsible_name) cleanFilters.responsible_name = fuzzyJoin(f.responsible_name)
  if (f.days_since_update) {
    const n = Number(f.days_since_update)
    if (!(n > 0 && n <= 3650)) return { ok: false, error: 'days_since_update inválido' }
    cleanFilters.days_since_update = n
  }
  if (f.unassigned === true || f.unassigned === 'true') cleanFilters.unassigned = true
  for (const k of ['date_from', 'date_to', 'occurrence_date_from', 'occurrence_date_to', 'created_before', 'created_after', 'updated_before', 'updated_after']) {
    if (f[k] !== undefined && f[k] !== null && f[k] !== '') {
      if (typeof f[k] !== 'string' || !DATE_RE.test(f[k])) return { ok: false, error: `Data inválida em ${k}` }
      cleanFilters[k] = f[k]
    }
  }
  if (f.period) cleanFilters.period = String(f.period) // normalizado no query service

  const allowedMetrics = ['count', 'list', 'avg_days', 'max', 'min', 'sum']
  if (!allowedMetrics.includes(metric)) return { ok: false, error: `Métrica não autorizada: ${metric}` }

  // detetar tentativas de SQL/prompt injection no plano
  const flat = JSON.stringify(raw).toLowerCase()
  if (/select |insert |update |delete |drop table|alter table|union select|--|;/.test(flat) && !/allowlist/.test(flat)) {
    return { ok: false, error: 'Operação não autorizada detetada' }
  }

  return {
    ok: true,
    plan: {
      intent, filters: cleanFilters, groupBy, metric, order,
      limit: limit > 0 ? limit : 20,
    },
  }
}

function fuzzyJoin(v) {
  if (Array.isArray(v)) return v.map((x) => String(x).toLowerCase()).join('|')
  return String(v).toLowerCase()
}

/** Resolve períodos semânticos em datas concretas (§10) — no backend, nunca no modelo. */
function resolvePeriod(period, now = new Date()) {
  const start = (d) => {
    const x = new Date(d); x.setHours(0, 0, 0, 0); return x
  }
  let from = null, to = null
  const p = String(period || '').toLowerCase()
  const today = start(now)
  const iso = (d) => d.toISOString().slice(0, 10)
  const addDays = (d, n) => new Date(d.getTime() + n * 86400000)

  switch (p) {
    case 'today': case 'hoje':
      from = today; to = addDays(today, 1); break
    case 'yesterday': case 'ontem':
      from = addDays(today, -1); to = today; break
    case 'this_week': case 'estasemana': {
      const dow = (today.getDay() + 6) % 7 // segunda=0
      from = addDays(today, -dow); to = addDays(from, 7); break
    }
    case 'last_week': case 'semanapassada': {
      const dow = (today.getDay() + 6) % 7
      const monday = addDays(today, -dow)
      from = addDays(monday, -7); to = monday; break
    }
    case 'this_month': case 'estemas':
      from = new Date(today.getFullYear(), today.getMonth(), 1); to = new Date(today.getFullYear(), today.getMonth() + 1, 1); break
    case 'last_month': case 'mespassado': {
      from = new Date(today.getFullYear(), today.getMonth() - 1, 1)
      to = new Date(today.getFullYear(), today.getMonth(), 1); break
    }
    case 'last_7_days': case 'ultimos7dias':
      from = addDays(today, -7); to = addDays(today, 1); break
    case 'last_30_days': case 'ultimos30dias':
      from = addDays(today, -30); to = addDays(today, 1); break
    case 'this_quarter': case 'estetrimestre': {
      const q = Math.floor(today.getMonth() / 3)
      from = new Date(today.getFullYear(), q * 3, 1); to = new Date(today.getFullYear(), q * 3 + 3, 1); break
    }
    case 'last_quarter': case 'trimestreanterior': {
      const q = Math.floor(today.getMonth() / 3)
      from = new Date(today.getFullYear(), q * 3 - 3, 1); to = new Date(today.getFullYear(), q * 3, 1); break
    }
    case 'this_year': case 'esteano':
      from = new Date(today.getFullYear(), 0, 1); to = new Date(today.getFullYear() + 1, 0, 1); break
    case 'last_year': case 'anopassado':
      from = new Date(today.getFullYear() - 1, 0, 1); to = new Date(today.getFullYear(), 0, 1); break
    default:
      return null // sem período
  }
  return { from: iso(from), to: iso(to) }
}

// Deteção de SQL destrutivo em texto do utilizador (defesa extra em profundidade)
function hasDestructiveSql(text) {
  return /(\bselect\b.*\bfrom\b|\binsert\s+into\b|\bupdate\b.*\bset\b|\bdelete\s+from\b|\bdrop\s+table\b|\balter\s+table\b|\bunion\s+select\b|--|;)/i.test(text)
}

module.exports = { validatePlan, resolvePeriod, hasDestructiveSql, MAX_LIMIT }