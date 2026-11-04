// intent-catalog.js — catálogo fechado de intents permitidos (§6) + catálogo de dados (§7)
// Adaptado ao modelo real da SAMSYS|Qualidade (ocorrências NC/OM, áreas, origens, ações).
// EXTENSÍVEL POR CÓDIGO: adicionar entradas aqui para novas capacidades, nunca por prompt.

const INTENTS = {
  occurrence_count: {
    desc: 'Contagem de ocorrências (NC/OM)',
    allowGroupBy: ['type', 'status', 'area', 'origin', 'responsible'],
    metric: 'count',
  },
  occurrence_list: {
    desc: 'Listagem controlada de ocorrências',
    allowGroupBy: null,
    metric: 'list',
  },
  occurrence_statistics: {
    desc: 'Agrupamentos e estatísticas de ocorrências',
    allowGroupBy: ['type', 'status', 'area', 'origin', 'responsible', 'month'],
    metric: 'count',
  },
  occurrence_comparison: {
    desc: 'Comparação entre períodos',
    allowGroupBy: ['type', 'status', 'area', 'origin'],
    metric: 'count',
  },
  occurrence_trend: {
    desc: 'Evolução temporal (agrupado por mês)',
    allowGroupBy: ['month'],
    metric: 'count',
  },
  occurrence_average_resolution_time: {
    desc: 'Tempo médio de resolução',
    allowGroupBy: ['type', 'priority', 'area'],
    metric: 'avg_days',
  },
  occurrence_stale: {
    desc: 'Ocorrências sem atualização há X dias',
    allowGroupBy: null,
    metric: 'list',
  },
  occurrence_unassigned: {
    desc: 'Ocorrências sem responsável atribuído',
    allowGroupBy: null,
    metric: 'list',
  },
  occurrence_top_areas: {
    desc: 'Áreas com mais ocorrências',
    allowGroupBy: ['area'],
    metric: 'count',
  },
  occurrence_top_origins: {
    desc: 'Origens mais frequentes',
    allowGroupBy: ['origin'],
    metric: 'count',
  },
  occurrence_open_actions: {
    desc: 'Ações em aberto / em atraso',
    allowGroupBy: ['status'],
    metric: 'count',
  },
  occurrence_anomaly_analysis: {
    desc: 'Deteção descritiva de alterações (período atual vs anterior)',
    allowGroupBy: null,
    metric: 'count',
  },
}

// Campos autorizados para o modelo (nomes técnicos escondidos do utilizador final)
const DATA_CATALOG = {
  occurrences: {
    label: 'Ocorrências (NC/OM)',
    fields: {
      reference: 'Referência (ex.: NC-2026-0001)',
      type: 'Tipo: NC (Não Conformidade) ou OM (Oportunidade de Melhoria)',
      status: 'Estado: OPEN=Aberta, IN_PROGRESS=Em curso, AWAITING_EFFECTIVENESS=A aguardar eficácia, CLOSED=Encerrada',
      area_name: 'Área/Processo (ex.: Desenvolvimento, Sistemas, Comercial, Financeiro, PHC, Sage, Logística, Administração)',
      origin_name: 'Origem (ex.: Auditoria Interna, Auditoria Externa, Reclamação, Processo Interno, Revisão pela Gestão, Melhoria Interna, Outra)',
      responsible_name: 'Responsável (nome do utilizador)',
      occurrence_date: 'Data da ocorrência',
      created_at: 'Data de criação',
      updated_at: 'Última atualização',
      closed_at: 'Data de fecho',
      description: 'Descrição do problema',
      cause_analysis: 'Análise de causa',
      effectiveness_status: 'Resultado da eficácia: EFFECTIVE=Eficaz, NOT_EFFECTIVE=Não eficaz',
    },
  },
  actions: {
    label: 'Ações do plano de ação',
    fields: {
      reference: 'Referência da ação',
      description: 'Descrição da ação',
      status: 'Estado: TODO=Por iniciar, IN_PROGRESS=Em curso, COMPLETED=Concluída',
      deadline: 'Prazo',
      responsible_name: 'Responsável da ação',
    },
  },
}

// Campos nunca expostos ao modelo/queries
const SENSITIVE_FIELDS = ['id_interno', 'audit_log.*', 'profiles.avatar_url']

module.exports = { INTENTS, DATA_CATALOG, SENSITIVE_FIELDS }