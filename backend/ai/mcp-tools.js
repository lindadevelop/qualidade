// mcp-tools.js — Camada MCP da aplicação (Fase 1). Tools READ-ONLY sobre o domínio real
// (ocorrências NC/OM, áreas, origens, responsáveis). Nenhuma tool executa SQL livre nem
// toca a BD diretamente: todas usam executePlan() que consome o ACCESS TOKEN DO UTILIZADOR
// (PostgREST + RLS). A IA nunca recebe credenciais da BD (§3, §16).
const { executePlan } = require('./occurrence-query-service')

// Filtros de data derivados de um periodo nomeado (reutiliza query-validator de forma central)
const { resolvePeriod } = require('./query-validator')

function applyPeriod(filters, period) {
  if (!period) return filters
  const r = resolvePeriod(period)
  if (!r) return filters
  return { ...filters, date_from: filters.date_from || r.from, date_to: filters.date_to || r.to }
}

// Helper: converte input em plano executePlan com métrica count (seguro)
function countPlan(filters) {
  return { intent: 'occurrence_count', filters, groupBy: null, metric: 'count', order: null, limit: 20 }
}
function listPlan(filters, limit) {
  return { intent: 'occurrence_list', filters, groupBy: null, metric: 'list', order: 'desc', limit: limit ?? 20 }
}
function statsPlan(filters, groupBy, limit) {
  return { intent: 'occurrence_statistics', filters, groupBy, metric: 'count', order: 'desc', limit: limit ?? 10 }
}

// Lista de tools MCP — NOME, DESCRIÇÃO (para o LLM), esquemas de entrada e executor.
// Adaptado ao domínio real: área/processo (em vez de "cliente"), responásavel (em vez de "técnico").
const TOOLS = [
  {
    name: 'get_occurrences_summary',
    description: 'Contagens de ocorrências NC/OM nas dimensões pedidas. Devolve abertas, em curso, a aguardar eficácia, encerradas e total (com filtros opcionais de tipo/área/origem/período).',
    inputSchema: {
      type: 'object',
      properties: {
        type: { type: 'string', enum: ['NC', 'OM'], description: 'Tipo (opcional)' },
        area_name: { type: 'string', description: 'Área/processo (ex.: Desenvolvimento, Sistemas, Financeiro)' },
        origin_name: { type: 'string', description: 'Origem (ex.: Auditoria Interna, Reclamação)' },
        period: { type: 'string', description: 'Período nomeado: today|this_week|last_week|this_month|last_month|last_7_days|last_30_days|this_year|last_year' },
      },
      required: [],
    },
    async run(args, token) {
      const f = applyPeriod({ type: args.type, area_name: args.area_name, origin_name: args.origin_name }, args.period)
      const OPEN_ALL = ['OPEN', 'IN_PROGRESS', 'AWAITING_EFFECTIVENESS']
      const [open, progress, awaiting, closed, total] = await Promise.all([
        executePlan(countPlan({ ...f, status: OPEN_ALL }), token),
        executePlan(countPlan({ ...f, status: ['IN_PROGRESS'] }), token),
        executePlan(countPlan({ ...f, status: ['AWAITING_EFFECTIVENESS'] }), token),
        executePlan(countPlan({ ...f, status: ['CLOSED'] }), token),
        executePlan(countPlan(f), token),
      ])
      const pick = (r) => (r && r.type === 'count' ? r.count : 0)
      return { abertas: pick(open), em_curso: pick(progress), a_aguardar_eficacia: pick(awaiting), encerradas: pick(closed), total: pick(total) }
    },
  },
  {
    name: 'search_occurrences',
    description: 'Pesquisa de ocorrências NC/OM com filtros e paginação. Devolve lista real (referência, tipo, estado, área, origem, responsável, data).',
    inputSchema: {
      type: 'object',
      properties: {
        status: { type: 'array', items: { type: 'string', enum: ['OPEN', 'IN_PROGRESS', 'AWAITING_EFFECTIVENESS', 'CLOSED'] }, description: 'Estados (vazio = todos)' },
        type: { type: 'string', enum: ['NC', 'OM'] },
        area_name: { type: 'string' },
        origin_name: { type: 'string' },
        responsible_name: { type: 'string', description: 'Responsável (nome)' },
        unassigned: { type: 'boolean', description: 'true = sem responsável atribuído' },
        period: { type: 'string' },
        search: { type: 'string', description: 'Texto livre na referência/descrição' },
        page: { type: 'integer', minimum: 1, default: 1 },
        page_size: { type: 'integer', minimum: 1, maximum: 50, default: 10 },
      },
      required: [],
    },
    async run(args, token) {
      const status = Array.isArray(args.status) && args.status.length ? args.status : undefined
      const f = applyPeriod({ status, type: args.type, area_name: args.area_name, origin_name: args.origin_name, responsible_name: args.responsible_name }, args.period)
      if (args.unassigned) f.unassigned = true
      if (args.search) f.search = args.search
      const limit = Math.min(args.page_size ?? 10, 50)
      const offset = ((args.page ?? 1) - 1) * limit
      // pedir um bloco alargado para conseguir paginar sobre a RPC (que não tem offset)
      const all = await executePlan(listPlan(f, 200), token)
      const rowsAll = Array.isArray(all.rows) ? all.rows : []
      const rows = rowsAll.slice(offset, offset + limit)
      return { page: args.page ?? 1, page_size: limit, total: rowsAll.length, items: rows }
    },
  },
  {
    name: 'get_occurrence',
    description: 'Dados de UMA ocorrência pelo seu ID ou referência (ex.: "OC-1054" ou "NC-2026-0001").',
    inputSchema: {
      type: 'object',
      properties: {
        reference: { type: 'string', description: 'Referência da ocorrência, ex.: NC-2026-0001' },
        id: { type: 'string', description: 'UUID da ocorrência' },
      },
      required: [],
    },
    async run(args, token) {
      const f = {}
      if (args.reference) f.search = args.reference
      const plan = listPlan(f, 20)
      const result = await executePlan(plan, token)
      const rows = Array.isArray(result.rows) ? result.rows : []
      const hit = rows.find((r) => r.reference && r.reference.toLowerCase() === String(args.reference || '').toLowerCase()) || (args.id ? rows[0] : null)
      return hit || { not_found: true }
    },
  },
  {
    name: 'get_open_occurrences',
    description: 'Ocorrências em aberto (OPEN, IN_PROGRESS, AWAITING_EFFECTIVENESS) com filtros opcionais.',
    inputSchema: {
      type: 'object',
      properties: {
        type: { type: 'string', enum: ['NC', 'OM'] },
        area_name: { type: 'string' },
        responsible_name: { type: 'string' },
        limit: { type: 'integer', minimum: 1, maximum: 50, default: 10 },
      },
      required: [],
    },
    async run(args, token) {
      const f = { status: ['OPEN', 'IN_PROGRESS', 'AWAITING_EFFECTIVENESS'], type: args.type, area_name: args.area_name, responsible_name: args.responsible_name }
      const result = await executePlan(listPlan(f, args.limit ?? 10), token)
      return { items: Array.isArray(result.rows) ? result.rows : [] }
    },
  },
  {
    name: 'get_critical_occurrences',
    description: 'Ocorrências críticas: as sem responsável há mais tempo ou com ações em atraso. Aceita período opcional.',
    inputSchema: {
      type: 'object',
      properties: {
        period: { type: 'string' },
        limit: { type: 'integer', minimum: 1, maximum: 50, default: 10 },
      },
      required: [],
    },
    async run(args, token) {
      const f = applyPeriod({ status: ['OPEN', 'IN_PROGRESS', 'AWAITING_EFFECTIVENESS'], unassigned: true }, args.period)
      const result = await executePlan(listPlan(f, args.limit ?? 10), token)
      const critical = Array.isArray(result.rows) ? result.rows : []
      return { items: critical, criterio: 'sem responsável atribuído' }
    },
  },
  {
    name: 'get_occurrences_statistics',
    description: 'Estatísticas/agrupamentos de ocorrências por tipo, estado, área, origem, responsável ou mês.',
    inputSchema: {
      type: 'object',
      properties: {
        group_by: { type: 'string', enum: ['type', 'status', 'area', 'origin', 'responsible', 'month'], description: 'Dimensão de agrupamento' },
        period: { type: 'string' },
        type: { type: 'string', enum: ['NC', 'OM'] },
        limit: { type: 'integer', minimum: 1, maximum: 50, default: 10 },
      },
      required: ['group_by'],
    },
    async run(args, token) {
      const f = applyPeriod({ type: args.type }, args.period)
      const result = await executePlan(statsPlan(f, args.group_by, args.limit ?? 10), token)
      return { group_by: args.group_by, groups: Array.isArray(result.groups) ? result.groups : [], total: result.total || 0 }
    },
  },
  {
    name: 'get_area_occurrences',
    description: 'Ocorrências de uma Área/Processo específica, com filtros de estado e período.',
    inputSchema: {
      type: 'object',
      properties: {
        area_name: { type: 'string', description: 'Nome da área' },
        status: { type: 'array', items: { type: 'string' } },
        period: { type: 'string' },
        limit: { type: 'integer', minimum: 1, maximum: 50, default: 10 },
      },
      required: ['area_name'],
    },
    async run(args, token) {
      const f = applyPeriod({ area_name: args.area_name, status: args.status }, args.period)
      const result = await executePlan(listPlan(f, args.limit ?? 10), token)
      return { items: Array.isArray(result.rows) ? result.rows : [] }
    },
  },
  {
    name: 'get_responsible_workload',
    description: 'Carga de trabalho por responsável: nº de ocorrências em aberto e em atraso por pessoa.',
    inputSchema: {
      type: 'object',
      properties: { period: { type: 'string' } },
      required: [],
    },
    async run(args, token) {
      const f = applyPeriod({ status: ['OPEN', 'IN_PROGRESS', 'AWAITING_EFFECTIVENESS'] }, args.period)
      const result = await executePlan(statsPlan(f, 'responsible', 50), token)
      return { responsaveis: Array.isArray(result.groups) ? result.groups : [], total: result.total || 0 }
    },
  },
  {
    name: 'get_available_areas',
    description: 'Lista as áreas/processos configurados (para resolver nomes sem inventar IDs).',
    inputSchema: { type: 'object', properties: {}, required: [] },
    async run(args, token) {
      const { listAreas } = require('./shared-lists')
      const rows = await listAreas(token)
      return { areas: rows.map((r) => r.name) }
    },
  },
  {
    name: 'get_available_origins',
    description: 'Lista as origens configuradas (para resolver nomes sem inventar IDs).',
    inputSchema: { type: 'object', properties: {}, required: [] },
    async run(args, token) {
      const { listOrigins } = require('./shared-lists')
      const rows = await listOrigins(token)
      return { origens: rows.map((r) => r.name) }
    },
  },
  {
    name: 'get_dashboard_summary',
    description: 'Resumo executivo do dashboard: KPIs atuais (abertas, em atraso, aguardar eficácia) e distribuição por área e origem.',
    inputSchema: {
      type: 'object',
      properties: { period: { type: 'string' } },
      required: [],
    },
    async run(args, token) {
      const summary = await TOOLS[0].run({ ...args }, token) // get_occurrences_summary
      const f = args.period ? applyPeriod({}, args.period) : {}
      const [byArea, byOrigin] = await Promise.all([
        executePlan(statsPlan(f, 'area', 10), token),
        executePlan(statsPlan(f, 'origin', 10), token),
      ])
      return {
        kpis: summary,
        por_area: Array.isArray(byArea.groups) ? byArea.groups : [],
        por_origem: Array.isArray(byOrigin.groups) ? byOrigin.groups : [],
      }
    },
  },
]

// ---- Tools LifeCycle RH (B15: pool/talento, consulta de candidaturas/vagas/tarefas/comunicações) ----
const lc = () => require('./lifecycle-lists')

const LC_TOOLS = [
  {
    name: 'lc_search_candidates',
    description: 'Pesquisa candidaturas LifeCycle RH por estado, nome ou texto. Devolve lista real (referência LCY, nome, email, estado, origem, função, equipa, decisão de triagem, dados de entrada/duplicado).',
    inputSchema: {
      type: 'object',
      properties: {
        estado: { type: 'string', description: 'Estado do caso (ex.: NA_FILA, EM_TRIAGEM, ENTREVISTA, SELECIONADO, PRE_ADMISSAO, READY_DAY1, ATIVO, OFFBOARDING, ENCERRADO, NAO_SELECIONADO)' },
        search: { type: 'string', description: 'Texto no nome da candidatura' },
        limit: { type: 'integer', minimum: 1, maximum: 50, default: 10 },
      },
      required: [],
    },
    async run(args, token) {
      const rows = await lc().listCasos({ estado: args.estado, search: args.search, limit: args.limit ?? 10 }, token)
      return { items: rows }
    },
  },
  {
    name: 'lc_get_candidate',
    description: 'Dados de UMA candidatura LifeCycle pelo LifeCycle ID de referência (ex.: LCY-2026-576189).',
    inputSchema: {
      type: 'object',
      properties: { reference: { type: 'string', description: 'Referência LCY-…' } },
      required: ['reference'],
    },
    async run(args, token) {
      const id = await lc().resolveCasoId(args.reference, token)
      if (!id) return { not_found: true }
      const [caso, tarefas, comunicacoes] = await Promise.all([
        lc().listCasos({ search: args.reference, limit: 1 }, token),
        lc().listTarefas(id, {}, token),
        lc().listComunicacoes(id, token),
      ])
      return { caso: Array.isArray(caso) ? caso[0] : null, tarefas, comunicacoes }
    },
  },
  {
    name: 'lc_list_vagas',
    description: 'Lista as vagas LifeCycle RH (referência VG, título, departamento, tipo, estado, data desejada).',
    inputSchema: {
      type: 'object',
      properties: {
        estado: { type: 'string', description: 'Estado (ex.: ABERTA, APROVADA, ENCERRADA)' },
        search: { type: 'string', description: 'Texto no título da vaga' },
        limit: { type: 'integer', minimum: 1, maximum: 50, default: 10 },
      },
      required: [],
    },
    async run(args, token) {
      const rows = await lc().listVagas({ estado: args.estado, search: args.search }, token)
      return { items: (Array.isArray(rows) ? rows : []).slice(0, args.limit ?? 10) }
    },
  },
  {
    name: 'lc_candidate_tasks',
    description: 'Tarefas de admissão/offboarding/estágio de uma candidatura (referência LCY). Filtra por gate (P0/P1/CONDICIONAL) ou status (COMPLETED/PENDING).',
    inputSchema: {
      type: 'object',
      properties: {
        reference: { type: 'string', description: 'Referência LCY-… da candidatura' },
        gate: { type: 'string', enum: ['P0', 'P1', 'CONDICIONAL'] },
        status: { type: 'string', enum: ['COMPLETED', 'PENDING'] },
      },
      required: ['reference'],
    },
    async run(args, token) {
      const id = await lc().resolveCasoId(args.reference, token)
      if (!id) return { not_found: true }
      const rows = await lc().listTarefas(id, { gate: args.gate, status: args.status }, token)
      return { items: rows }
    },
  },
  {
    name: 'lc_candidate_communications',
    description: 'Comunicações E01-E12 registadas numa candidatura (referência LCY). Devolve ref, tipo, destino, template e estado (evidência de envio).',
    inputSchema: {
      type: 'object',
      properties: { reference: { type: 'string', description: 'Referência LCY-…' } },
      required: ['reference'],
    },
    async run(args, token) {
      const id = await lc().resolveCasoId(args.reference, token)
      if (!id) return { not_found: true }
      const rows = await lc().listComunicacoes(id, token)
      return { items: rows }
    },
  },
  {
    name: 'lc_pool_summary',
    description: 'Resumo do pool de talento: contagem de candidaturas por estado e por vaga (distribuição).',
    inputSchema: { type: 'object', properties: {}, required: [] },
    async run(args, token) {
      const casos = await lc().listCasos({ limit: 1000 }, token)
      const arr = Array.isArray(casos) ? casos : []
      const porEstado = {}
      const porTipo = {}
      for (const c of arr) {
        const e = c.estado || 'S/ESTADO'; porEstado[e] = (porEstado[e] || 0) + 1
        const t = c.tipo || 'S/TIPO'; porTipo[t] = (porTipo[t] || 0) + 1
      }
      return { total: arr.length, por_estado: porEstado, por_tipo: porTipo }
    },
  },
  {
    name: 'get_overdue_actions',
    description: 'Ações em ATRASO: ações com prazo já ultrapassado (deadline < hoje) e não concluídas (TODO/IN_PROGRESS). Devolve referência, descrição, responsável, prazo e estado.',
    inputSchema: {
      type: 'object',
      properties: { limit: { type: 'integer', minimum: 1, maximum: 50, default: 20 } },
      required: [],
    },
    async run(args, token) {
      const http = require('http')
      const REST_URL = process.env.SUPABASE_REST_URL || 'http://127.0.0.1:3001'
      const rest = (p) => new Promise((resolve, reject) => {
        const u = new URL(REST_URL)
        const req = http.request({ hostname: u.hostname, port: u.port, path: p, method: 'GET', headers: { Authorization: `Bearer ${token}`, apikey: process.env.VITE_SUPABASE_ANON_KEY || 'anon', Accept: 'application/json' } }, (res) => { let d = ''; res.on('data', (c) => (d += c)); res.on('end', () => { try { resolve(JSON.parse(d)) } catch { resolve([]) } }) })
        req.on('error', reject); req.end()
      })
      const today = new Date().toISOString().slice(0, 10)
      // ações não concluídas com prazo passado
      const enc = encodeURIComponent
      const rows = await rest(`/quality_actions?select=reference,description,deadline,status,responsible_user_id,occurrence_id&deadline=lt.${today}&and=(status.neq.COMPLETED)&order=deadline.asc&limit=${args.limit ?? 20}`)
      const arr = Array.isArray(rows) ? rows : []
      return { hoje: today, total: arr.length, items: arr }
    },
  },
  // ---- Consultor Operacional: prioridades calculadas por regras objetivas ----
  {
    name: 'get_quality_priorities',
    description: 'Consultor: prioridades da Qualidade calculadas por regras objetivas. Níveis Crítica/Alta/Média/Baixa com motivo de cada regra (ações vencidas, sem responsável, eficácia pendente, reincidência, paradas). Ideal para "o que é mais urgente hoje?".',
    inputSchema: {
      type: 'object',
      properties: { limit: { type: 'integer', minimum: 1, maximum: 25, default: 10 } },
      required: [],
    },
    async run(args, token) {
      const { calcularPrioridades } = require('./consultor-service')
      return calcularPrioridades(token, args.limit ?? 10)
    },
  },
  {
      name: 'get_occurrence_context',
      description: 'Consultor: contexto COMPLETO de uma ocorrência (ficha, ações, eficácia, relações) para recomendar o próximo passo. Devolve dados reais e pertinentes.',
      inputSchema: {
        type: 'object',
        properties: { reference: { type: 'string', description: 'Referência, ex.: NC-2026-0024' } },
        required: ['reference'],
      },
      async run(args, token) {
        const http = require('http')
        const REST_URL = process.env.SUPABASE_REST_URL || 'http://127.0.0.1:3001'
        const rest = (p) => new Promise((resolve, reject) => {
          const u = new URL(REST_URL)
          const req = http.request({ hostname: u.hostname, port: u.port, path: p, method: 'GET', headers: { Authorization: `Bearer ${token}`, apikey: process.env.SUPABASE_ANON_KEY || 'anon', Accept: 'application/json' } }, (res) => { let d = ''; res.on('data', (c) => (d += c)); res.on('end', () => { try { resolve(JSON.parse(d)) } catch { resolve([]) } }) })
          req.on('error', reject); req.end()
        })
        const enc = encodeURIComponent
        const rows = await rest(`/quality_occurrences?select=id,reference,type,status,occurrence_date,description,cause_analysis,effectiveness_status,effectiveness_notes,effectiveness_evidence,effectiveness_validated_at,closed_at,created_at,updated_at,quality_areas(name),quality_origins(name),profiles:responsible_user_id(full_name)&reference=eq.${enc(args.reference)}&limit=1`)
        if (!Array.isArray(rows) || !rows.length) return { not_found: true, referência: args.reference }
        const o = rows[0]
        const acoes = await rest(`/quality_actions?select=reference,description,deadline,status,completed_at,profiles:responsible_user_id(full_name)&occurrence_id=eq.${enc(o.id)}&order=created_at.asc&limit=50`)
        const rels = await rest(`/quality_occurrence_relations?select=relation_type,related_occurrence_id&occurrence_id=eq.${enc(o.id)}&limit=50`)
        return {
          ocorrencia: {
            referência: o.reference, tipo: o.type, estado: o.status, data: o.occurrence_date, área: o.quality_areas?.name || null, origem: o.quality_origins?.name || null, responsável: o.profiles?.full_name || null,
            descricao: o.description, causa: o.cause_analysis || null, eficácia: o.effectiveness_status || null, eficácia_notas: o.effectiveness_notes || null, encerrada_em: o.closed_at || null, criada_em: o.created_at, atualizada_em: o.updated_at,
          },
          acoes: acoes.map((a) => ({ ref: a.reference, desc: a.description, prazo: a.deadline, estado: a.status, concluida_em: a.completed_at, responsavel: a.profiles?.full_name || null })),
          relacoes: rels,
          url: `/ocorrencias/${o.id}`,
        }
      },
    },
    // ---- Análises automáticas do Consultor (documento Melhoria MCP §4) ----
    {
      name: 'get_quality_health_check',
      description: 'Consultor: verificação de saúde completa da Qualidade — prazos (vencidos/à vencer), ações sem responsável/prazo/evidência, ocorrências sem causa/responsável, eficácia pendente, reincidências, responsáveis sobrecarregados, tendência mês-vs-mês e riscos (paradas/sem ação). Ideal para "o que tenho pendente?", "preocupar-me", "há algo urgente?", "como está a Qualidade?".',
      inputSchema: { type: 'object', properties: {}, required: [] },
      async run(args, token) {
        const { analiseCompleta } = require('./quality-analyses')
        return analiseCompleta(token)
      },
    },
    {
      name: 'get_overdue_and_due',
      description: 'Consultor: ações em atraso e a vencer nos próximos 3 dias (prazos). Devolve fora_de_prazo e a_vencer_3_dias. Para "o que está atrasado?", "ações por vencer".',
      inputSchema: { type: 'object', properties: {}, required: [] },
      async run(args, token) {
        const { analisePrazos } = require('./quality-analyses')
        return analisePrazos(token)
      },
    },
    {
      name: 'get_incomplete_records',
      description: 'Consultor: registos com dados em falta — ações sem responsável ou sem prazo, ocorrências sem causa ou sem responsável, ações concluídas sem evidência. Para "há registos incompletos?", "o que falta preencher?".',
      inputSchema: { type: 'object', properties: {}, required: [] },
      async run(args, token) {
        const { analiseIncompletos } = require('./quality-analyses')
        return analiseIncompletos(token)
      },
    },
    {
      name: 'get_recurrences',
      description: 'Consultor: reincidências — ocorrências ligadas como recorrentes (relação) e descrições repetidas. Para "existem problemas repetidos?", "reincidências?".',
      inputSchema: { type: 'object', properties: {}, required: [] },
      async run(args, token) {
        const { analiseReincidencias } = require('./quality-analyses')
        return analiseReincidencias(token)
      },
    },
    {
      name: 'get_overloaded_responsibles',
      description: 'Consultor: responsáveis com excesso de pendências (ações vencidas + pendentes + ocorrências abertas). Para "quem tem mais ações pendentes?", "quem está assoberbado?".',
      inputSchema: { type: 'object', properties: {}, required: [] },
      async run(args, token) {
        const { analiseCarga } = require('./quality-analyses')
        return analiseCarga(token)
      },
    },
    {
      name: 'get_month_trend',
      description: 'Consultor: tendência mês atual vs anterior (novas ocorrências, subida/descida/estável). Para "compara este mês com o anterior", "está a melhorar?".',
      inputSchema: { type: 'object', properties: {}, required: [] },
      async run(args, token) {
        const { analiseTendencias } = require('./quality-analyses')
        return analiseTendencias(token)
      },
    },
    {
      name: 'get_pending_effectiveness',
      description: 'Consultor: ações concluídas cuja eficácia ainda não foi validada (ocorrência ainda não efeativa). Para "o que falta validar?", "eficácia pendente".',
      inputSchema: { type: 'object', properties: {}, required: [] },
      async run(args, token) {
        const { analiseEficacia } = require('./quality-analyses')
        return analiseEficacia(token)
      },
    },
    {
      name: 'get_high_risks',
      description: 'Consultor: riscos elevados — ocorrências paradas há +30 dias e ocorrências abertas sem ação em curso. Para "quais os principais riscos?", "o que está parado?".',
      inputSchema: { type: 'object', properties: {}, required: [] },
      async run(args, token) {
        const { analiseRiscos } = require('./quality-analyses')
        return analiseRiscos(token)
      },
    },
    {
      name: 'pesquisar_semantica_ncs',
      description: 'Consultor: pesquisa semântica por Não Conformidades e ações semelhantes a um termo — pontua por sobreposição (descrição, causa, área, origem, referência) e devolve as mais relevantes com contexto e ações. Para "já tivemos problemas semelhantes?", "o que aconteceu antes com X?". Apoia a decisão; a fonte de verdade é a base de dados.',
      inputSchema: { type: 'object', properties: { termo: { type: 'string', description: 'Texto a pesquisar (ex.: "formação PHC", "avaliação fornecedores")' } }, required: ['termo'] },
      async run(args, token) {
        const { pesquisarSemantica } = require('./quality-analyses')
        return pesquisarSemantica(token, args.termo)
      },
    },
    {
      name: 'get_alertas_inteligentes',
      description: 'Consultor: alertas inteligentes (§16) — ações a vencer nas próximas 72h e registos parados há +30 dias. Para "há algo a vencer?", "o que merece atenção?".',
      inputSchema: { type: 'object', properties: {}, required: [] },
      async run(args, token) {
        const { alertas } = require('./quality-analyses')
        return alertas(token)
      },
    },
  ]

// ---- Ferramentas de ESCRITA (Fase 3 · Copiloto de Qualidade §7/§9/§14) ----
// Separadas das de leitura. A IA NUNCA persiste diretamente: gera uma proposta
// apresentada ao utilizador; apenas a confirmação explícita chama a persistência.
// Única store de propostas em espera: por utilizador, com expiração curta.
const pendingProposals = new Map() // tokenHash -> {nc, proposta, ts}
const PP_TTL_MS = 15 * 60000
function pendingKey(token) { try { return require('crypto').createHash('sha256').update(String(token)).digest('hex').slice(0, 32) } catch { return String(token).slice(0, 32) } }
function getPending(token) {
  const k = pendingKey(token)
  const p = pendingProposals.get(k)
  if (p && Date.now() - p.ts > PP_TTL_MS) { pendingProposals.delete(k); return null }
  return p || null
}

const WRITE_TOOLS = [
  {
    name: 'propor_plano_conformidade',
    description: 'ESCRITA (proposta, NÃO persiste): gera um rascunho de Plano de Conformidade para uma Não Conformidade — recolhe a NC, histórico e ações existentes, e propõe um plano com ações e responsáveis sugeridos. O utilizador revê; só guarda após confirmar. Para "cria uma proposta de plano para esta NC".',
    inputSchema: {
      type: 'object',
      properties: {
        nc_ref: { type: 'string', description: 'Referência da NC, ex.: NC-2026-0048' },
        titulo: { type: 'string', description: 'Título sugerido do plano' },
        descricao: { type: 'string', description: 'Descrição do plano' },
        responsavel: { type: 'string', description: 'Nome do responsável proposto (opcional; só se único)' },
        acoes: {
          type: 'array', items: { type: 'object', properties: {
            titulo: { type: 'string' }, descricao: { type: 'string' },
            tipo: { type: 'string', enum: ['CONTENCAO', 'CORRETIVA', 'PREVENTIVA', 'MELHORIA', 'FORMACAO', 'ALTERACAO_DOCUMENTAL', 'ALTERACAO_PROCESSO', 'VERIFICACAO', 'VALIDACAO_EFICACIA', 'OUTRA'] },
            prioridade: { type: 'string' }, deadline: { type: 'string' }, horas_previstas: { type: 'number' },
            responsavel: { type: 'string' }, verificar_eficacia: { type: 'boolean' },
          }, required: [] },
        },
      },
      required: ['nc_ref'],
    },
    async run(args, token) {
      const qs = require('./quality-service')
      const r = await qs.proporPlano(args.nc_ref, args, token)
      if (r.ok) {
        pendingProposals.set(pendingKey(token), { nc: args.nc_ref, proposta: r.proposta, ts: Date.now() })
        r.proposta_em_espera = true
      }
      return r
    },
  },
  {
    name: 'confirmar_plano_conformidade',
    description: 'ESCRITA (confirmação): persiste o Plano de Conformidade e as ações da proposta em espera (criada por propor_plano_conformidade). EXIGE confirmação explícita do utilizador — nunca execute auto e nunca invente. Regista auditoria de proposta IA aprovada pelo utilizador.',
    inputSchema: { type: 'object', properties: {}, required: [] },
    async run(args, token) {
      const qs = require('./quality-service')
      const pend = getPending(token)
      if (!pend || !pend.proposta) return { ok: false, motivo: 'Não há proposta em espera para confirmar. Gera primeiro uma proposta ("cria uma proposta de plano para esta NC").' }
      const r = await qs.confirmarProposta(pend.proposta, token, args.usuario_id || null)
      if (r.ok) { pendingProposals.delete(pendingKey(token)); r.confirmado_por_utilizador = true }
      return r
    },
  },
  {
    name: 'ver_plano_em_espera',
    description: 'LEITURA auxiliar: mostra a proposta de Plano/Copiloto que está em espera para confirmação (sem persistir nada). Para o utilizador rever antes de aprovar.',
    inputSchema: { type: 'object', properties: {}, required: [] },
    async run(args, token) {
      const pend = getPending(token)
      if (!pend || !pend.proposta) return { ok: false, motivo: 'Não há proposta em espera.' }
      return { nc: pend.nc, em_espera: pend.proposta }
    },
  },
  {
    name: 'estado_nao_conformidade',
    description: 'LEITURA: estado operacional completo de uma Não Conformidade — descrição, causa, plano ativo, ações (estado/progresso/prazos/horas) e avaliação de encerramento (pode ou não ser encerrada e porquê). Para "como está esta NC?", "o que falta fazer?".',
    inputSchema: {
      type: 'object',
      properties: { nc_ref: { type: 'string', description: 'Referência da NC' } },
      required: ['nc_ref'],
    },
    async run(args, token) {
      const qs = require('./quality-service')
      return qs.estadoNc(args.nc_ref, token)
    },
  },
  {
    name: 'registar_trabalho_acao',
    description: 'ESCRITA (registar trabalho): regista horas/descrição de trabalho numa ação e atualiza a percentagem. A IA deve apresentar o resumo ao utilizador e obter confirmação antes de chamar em operações relevantes. Para "na ação AC-2026-0148 regista 2h30 e passa para 60%".',
    inputSchema: {
      type: 'object',
      properties: {
        action_ref: { type: 'string', description: 'Referência da ação, ex.: AC-2026-0148' },
        descricao: { type: 'string', description: 'Trabalho realizado' },
        horas: { type: 'number', description: 'Horas (ex.: 2.5)' },
        minutos: { type: 'integer', description: 'Minutos (se usar horas deixa vazio)' },
        percent_depois: { type: 'number', description: 'Percentagem de execução após (0-100)' },
        logged_by: { type: 'string', description: 'UUID do utilizador que regista' },
      },
      required: ['action_ref'],
    },
    async run(args, token) {
      const qs = require('./quality-service')
      const r = await qs.buscarAcaoPorRef(args.action_ref, token)
      if (!r) return { ok: false, motivo: `Ação ${args.action_ref} não encontrada.` }
      const reg = await qs.registarTrabalho(r.id, args, token)
      return { ok: true, acao: args.action_ref, registo: reg }
    },
  },
]

/** Executa uma tool pelo nome com o token do utilizador. Devolve {ok, data} ou {ok:false, error}. */
async function callTool(name, args, token) {
  const tool = TOOLS.find((t) => t.name === name) || LC_TOOLS.find((t) => t.name === name) || WRITE_TOOLS.find((t) => t.name === name)
  if (!tool) return { ok: false, error: `tool_desconhecida: ${name}` }
  // limita argumentos a campos do schema (defesa extra contra campos não previstos)
  const props = (tool.inputSchema.properties || {})
  const clean = {}
  for (const [k, v] of Object.entries(args || {})) if (Object.prototype.hasOwnProperty.call(props, k)) clean[k] = v
  try {
    const data = await tool.run(clean, token)
    return { ok: true, data }
  } catch (e) {
    return { ok: false, error: e.message || 'erro_tool' }
  }
}

module.exports = { TOOLS, ALL_TOOLS: [...TOOLS, ...LC_TOOLS], WRITE_TOOLS, ALL_TOOLS_WITH_WRITE: [...TOOLS, ...LC_TOOLS, ...WRITE_TOOLS], callTool, countPlan, listPlan, statsPlan, applyPeriod }