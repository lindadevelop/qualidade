// quality-service.js — Camada de serviços de domínio do Copiloto de Qualidade.
// §19 do doc: as regras de negócio NÃO vivem nas ferramentas MCP nem no frontend —
// vivem aqui, reutilizáveis pela aplicação web, API e MCP, de forma consistente.
// Regras 100% determinísticas em JS. A IA apenas propõe; o serviço valida e executa
// com o TOKEN do utilizador (RLS). Nunca recebe credenciais da BD.
const http = require('http')

const REST_URL = process.env.SUPABASE_REST_URL || 'http://127.0.0.1:3001'
const AK = process.env.SUPABASE_ANON_KEY || 'anon'

function rest(path, token, opts = {}) {
  return new Promise((resolve, reject) => {
    const u = new URL(REST_URL)
    const method = opts.method || 'GET'
    const headers = { Authorization: `Bearer ${token}`, apikey: AK, Accept: 'application/json' }
    if (opts.body) headers['Content-Type'] = 'application/json'
    if (opts.prefer) headers.Prefer = opts.prefer
    const req = http.request({ hostname: u.hostname, port: u.port, path, method, headers }, (res) => {
      let d = ''
      res.on('data', (c) => (d += c))
      res.on('end', () => {
        let json
        try { json = JSON.parse(d) } catch { json = d }
        resolve({ status: res.statusCode, data: json })
      })
    })
    req.on('error', reject)
    if (opts.body) req.write(JSON.stringify(opts.body))
    req.end()
  })
}

const today = () => new Date().toISOString().slice(0, 10)
const diffDias = (a) => { const t = new Date(String(a).slice(0, 10) + 'T00:00:00').getTime(); return isNaN(t) ? null : Math.ceil((Date.now() - t) / 86400000) }

/** Extrai o user id (sub) do JWT local validado (já verificado pelo gateway). */
function userIdFromToken(token) {
  try {
    const part = String(token || '').split('.')[1]
    if (!part) return null
    const pad = part.length % 4 ? 4 - (part.length % 4) : 0
    const json = Buffer.from(part + '='.repeat(pad), 'base64url').toString()
    const p = JSON.parse(json)
    return p.sub || p.user_id || p.id || null
  } catch { return null }
}

// ---------- Tipos de ação (catálogo fechado) ----------
const ACTION_TYPES = {
  CONTENCAO: 'Contenção imediata', CORRETIVA: 'Ação corretiva', PREVENTIVA: 'Ação preventiva',
  MELHORIA: 'Ação de melhoria', FORMACAO: 'Formação', ALTERACAO_DOCUMENTAL: 'Alteração documental',
  ALTERACAO_PROCESSO: 'Alteração de processo', VERIFICACAO: 'Verificação / auditoria',
  VALIDACAO_EFICACIA: 'Validação de eficácia', OUTRA: 'Outra ação',
}

/** Progresso do plano = média ponderada pelo esforço previsto das ações (§5). */
function calcularProgressoPlano(acoes, pesos = {}) {
  if (!Array.isArray(acoes) || !acoes.length) return { progresso: 0, origem: 'media', ponderado: false, nAcoes: 0 }
  let somaPeso = 0, somaProgresso = 0
  for (const a of acoes) {
    const p = a.horas_previstas != null ? Number(a.horas_previstas) : (pesos[a.tipo] || 1)
    somaPeso += p
    somaProgresso += Number(a.percent_execucao || 0) * p
  }
  if (!somaPeso) return { progresso: 0, origem: 'media', ponderado: false, nAcoes: acoes.length }
  const progresso = Math.round((somaProgresso / somaPeso) * 100) / 100
  return { progresso, origem: 'ponderada_esforco', ponderado: true, nAcoes: acoes.length }
}

/** Regras de encerramento da NC (§15). Devolve {pode, motivo, pendentes} por condição. */
async function avaliarEncerramento(occurrenceId, token) {
  const enc = encodeURIComponent
  const oc = await rest(`/quality_occurrences?select=id,reference,status&id=eq.${occurrenceId}&limit=1`, token)
  const occ = (oc.data && oc.data[0]) || null
  if (!occ) return { ok: false, motivo: 'Ocorrência não encontrada.' }
  if (occ.status === 'CLOSED') return { ok: true, motivo: 'NC já se encontra encerrada.', pendentes: [] }

  const acSel = `id,reference,status,percent_execucao,tipo,verificar_eficacia,eficacia_validada,evidencias_obrigatorias,deadline`
  const ac = await rest(`/quality_actions?select=${acSel}&occurrence_id=eq.${occ.id}&limit=500`, token)
  const acoes = Array.isArray(ac.data) ? ac.data : []
  if (!acoes.length) {
    return { ok: false, motivo: 'A NC ainda não pode ser encerrada: não tem ações registadas.', pendentes: ['Sem plano de ações'] }
  }

  const pendentes = []
  if (acoes.some((a) => a.status === 'BLOCKED')) pendentes.push(`Existem ações bloqueadas (ex.: ${acoes.find((a) => a.status === 'BLOCKED').reference})`)
  const naoConcluidas = acoes.filter((a) => a.status !== 'COMPLETED' && a.status !== 'CANCELLED')
  if (naoConcluidas.length) {
    const incompl = naoConcluidas.filter((a) => Number(a.percent_execucao || 0) < 100)
    pendentes.push(`${incompl.length ? incompl.map((a) => `${a.reference} (${a.percent_execucao}%)`).slice(0, 3).join(', ') + ' estão incompletas' : 'há ações por concluir'}`)
  }
  const semEvidObrigatoria = acoes.filter((a) => a.status === 'COMPLETED' && a.evidencias_obrigatorias)
  // evidências obrigatórias: o serviço deve confirmar existência via attachments; aqui assume verificação por chamada posterior
  const precisaEficacia = acoes.find((a) => a.verificar_eficacia && a.status === 'COMPLETED' && !a.eficacia_validada)
  if (precisaEficacia) pendentes.push(`Ação ${precisaEficacia.reference} concluída ainda sem validação de eficácia assinalada`)
  if (semEvidObrigatoria.length) pendentes.push(`${semEvidObrigatoria.length} ação(ões) obriga(m) evidência anexada`)

  if (pendentes.length) {
    return { ok: false, motivo: `A ${occ.reference} ainda não pode ser encerrada.`, pendentes }
  }
  return { ok: true, motivo: `A ${occ.reference} reúne as condições para encerramento.`, pendentes: [] }
}

/** Cria um Plano de Conformidade a partir de uma NC (draft ou persistido). */
async function criarPlano(occurrenceId, dados, token) {
  const body = {
    occurrence_id: occurrenceId,
    titulo: dados.titulo || null,
    descricao: dados.descricao || null,
    status: dados.status || 'RASCUNHO',
    responsavel_id: dados.responsavel_id || null,
    data_inicio: dados.data_inicio || today(),
    data_prevista_fim: dados.data_prevista_fim || null,
    esforco_previsto_h: dados.esforco_previsto_h || null,
    requer_aprovacao: dados.requer_aprovacao || false,
    origem: dados.origem || 'manual',
    sugerido_por_ia: !!dados.sugerido_por_ia,
    versao: dados.versao || 1,
  }
  const r = await rest(`/quality_compliance_plans?select=*`, token, { method: 'POST', body, prefer: 'return=representation' })
  return r.data && r.data[0] ? r.data[0] : r.data
}

/** Cria uma ação operacional ligada ao plano/NC. */
async function criarAcao(planoId, occurrenceId, acao, token) {
  const body = {
    occurrence_id: occurrenceId,
    plano_id: planoId,
    titulo: acao.titulo || acao.description || null,
    description: acao.description || acao.titulo || null,
    tipo: acao.tipo || null,
    resultado_esperado: acao.resultado_esperado || null,
    prioridade: acao.prioridade || null,
    criticidade: acao.criticidade || null,
    responsible_user_id: acao.responsible_user_id || null,
    colaboradores: acao.colaboradores || null,
    deadline: acao.deadline || null,
    data_inicio: acao.data_inicio || today(),
    horas_previstas: acao.horas_previstas || null,
    horas_realizadas: acao.horas_realizadas || 0,
    percent_execucao: acao.percent_execucao || 0,
    status: acao.status || 'TODO',
    verificar_eficacia: acao.verificar_eficacia || false,
    evidencias_obrigatorias: acao.evidencias_obrigatorias || false,
    requer_aprovacao: acao.requer_aprovacao || false,
    origem: acao.origem || 'manual',
    proposta_por_ia: !!acao.proposta_por_ia,
  }
  const r = await rest(`/quality_actions?select=*`, token, { method: 'POST', body, prefer: 'return=representation' })
  return r.data && r.data[0] ? r.data[0] : r.data
}

/** Regista trabalho/horas numa ação e atualiza o progresso + horas (§4, §5). */
async function registarTrabalho(actionId, registro, token) {
  // grava o work log
  const wl = await rest(`/quality_work_logs?select=*`, token, {
    method: 'POST',
    body: {
      action_id: actionId,
      logged_by: registro.logged_by || userIdFromToken(token) || null,
      descricao: registro.descricao || null,
      horas: registro.horas || 0,
      minutos: registro.minutos || 0,
      percent_antes: registro.percent_antes ?? null,
      percent_depois: registro.percent_depois ?? null,
      bloqueio: registro.bloqueio || null,
      next_step: registro.next_step || null,
    },
    prefer: 'return=representation',
  })
  // atualiza a ação: horas realizadas acumuladas + percentagem (se fornecida)
  const campos = {}
  // soma em JS: busca o valor atual e acumula
  const rAtual = await rest(`/quality_actions?select=horas_realizadas,percent_execucao&id=eq.${actionId}&limit=1`, token).catch(() => ({}))
  const acAtual = (Array.isArray(rAtual.data) && rAtual.data[0]) || {}
  const horasAtuais = Number(acAtual.horas_realizadas) || 0
  const acrescimo = Number(registro.horas) || (Number(registro.minutos) || 0) / 60
  if (acrescimo) campos.horas_realizadas = Math.round((horasAtuais + acrescimo) * 100) / 100
  if (registro.percent_depois != null) {
    campos.percent_execucao = Number(registro.percent_depois) || 0
    campos.progresso_origem = 'manual'
  }
  const patch = await rest(`/quality_actions?id=eq.${actionId}`, token, { method: 'PATCH', body: campos })
  return { work_log: wl.data && wl.data[0] ? wl.data[0] : wl.data, update: patch }
}

// ============================================================
// FLUXO DE ESCRITA PROPOSTA → APROVAÇÃO (§9)
// A IA NUNCA persiste diretamente: gera uma PROPOSTA (em memória,
// apenas com o token/utilizador), apresenta-a, e só após a confirmação
// explícita do utilizador o plano e as ações são persistidos + auditados.
// ============================================================

/** Resolve um utilizador por nome parcial (função/competência); SEM atribuir à força. */
async function resolverResponsavel(termo, token) {
  if (!termo) return null
  const p = await rest(`/profiles?select=id,full_name,role&or=(full_name.ilike.*${encodeURIComponent(termo)}*)&limit=5`, token).catch(() => [])
  const arr = Array.isArray(p.data) ? p.data : []
  if (arr.length === 1) return arr[0]
  if (arr.length > 1) return { ambiguo: true, candidatos: arr.map((x) => x.full_name) }
  return null
}

/**
 * Gera uma PROPOSTA de Plano de Conformidade para uma NC (não persiste).
 * Recolhe contexto (NC + ações) e devolve plano proposto + ações sugeridas.
 */
async function proporPlano(ncRef, opt = {}, token) {
  const occ = await buscarNc(ncRef, token)
  if (!occ) return { ok: false, motivo: `NC ${ncRef} não encontrada.` }
  const ac = await rest(`/quality_actions?select=id,reference,description,titulo,status,percent_execucao,responsible_user_id&occurrence_id=eq.${occ.id}&limit=200`, token).catch(() => ({}))
  const acoesExistentes = Array.isArray(ac.data) ? ac.data : []
  const rp = await resolverResponsavel(opt.responsavel, token)
  const proposta = {
    occurrence_id: occ.id,
    nc_ref: occ.reference,
    titulo: opt.titulo || `Plano de Conformidade — ${occ.reference}`,
    descricao: opt.descricao || `Plano para conduzir a ${occ.reference} até à conformidade.`,
    status: 'RASCUNHO',
    origem: 'ia',
    sugerido_por_ia: true,
    requer_aprovacao: opt.requer_aprovacao || false,
    responsavel_id: rp && !rp.ambiguo ? rp.id : null,
    responsavel_sugerido: opt.responsavel || null,
    acoes: (opt.acoes || []).map((a) => ({
      titulo: a.titulo || a.description || null,
      descricao: a.description || a.titulo || null,
      tipo: a.tipo || 'CORRETIVA',
      prioridade: a.prioridade || 'Média',
      percent_execucao: 0,
      deadline: a.deadline || null,
      horas_previstas: a.horas_previstas || null,
      status: 'TODO',
      verificar_eficacia: a.tipo === 'VALIDACAO_EFICACIA' || !!a.verificar_eficacia,
      origem: 'ia',
      proposta_por_ia: true,
      responsavel_sugerido: a.responsavel || opt.responsavel || null,
    })),
    acoes_existentes: acoesExistentes.length,
  }
  if (rp && rp.ambiguo) proposta.ambiguidade = { campo: 'responsavel', candidatos: rp.candidatos }
  return { ok: true, proposta }
}

/**
 * Confirma e PERSISTE uma proposta: cria o plano + as ações, em bloco.
 * Só deve ser chamada após o utilizador aprovar explicitamente (§9, §14).
 */
async function confirmarProposta(proposta, token, usuarioId) {
  if (!proposta) return { ok: false, motivo: 'Não há proposta em espera para confirmar.' }
  const plano = await criarPlano(proposta.occurrence_id, proposta, token)
  let acoes = []
  if (Array.isArray(proposta.acoes) && proposta.acoes.length) {
    for (const a of proposta.acoes) {
      const acao = await criarAcao(plano.id, proposta.occurrence_id, a, token)
      acoes.push(acao)
    }
  }
  // auditoria explícita (além do trigger por-tabela): assinala proposta IA + aprovação humana
  await rest(`/audit_log?select=id`, token, {
    method: 'POST',
    body: {
      entity_type: 'compliance_plan', entity_id: plano.id, action: 'plan_created_from_ia_proposal',
      new_data: { plano_id: plano.id, n_acoes: acoes.length, aprovado_por: usuarioId, aprovado_em: new Date().toISOString() },
      user_id: usuarioId,
    },
  }).catch(() => ({}))
  return { ok: true, plano, acoes }
}

/** Busca uma NC por referência (ou id). */
async function buscarNc(ncRef, token) {
  const enc = encodeURIComponent
  const key = /^[0-9a-f-]{36}$/i.test(ncRef || '') ? `id` : `reference`
  const r = await rest(`/quality_occurrences?select=*,quality_areas(name),quality_origins(name)&${key}=eq.${enc(ncRef)}&limit=1`, token).catch(() => ({}))
  return (Array.isArray(r.data) && r.data[0]) || null
}

/** Busca uma ação por referência (ou id). */
async function buscarAcaoPorRef(actionRef, token) {
  const enc = encodeURIComponent
  const key = /^[0-9a-f-]{36}$/i.test(actionRef || '') ? `id` : `reference`
  const r = await rest(`/quality_actions?select=*&${key}=eq.${enc(actionRef)}&limit=1`, token).catch(() => ({}))
  return (Array.isArray(r.data) && r.data[0]) || null
}

/** Estado detalhado de uma NC (para resumo/operação). */
async function estadoNc(ncRef, token) {
  const occ = await buscarNc(ncRef, token)
  if (!occ) return { ok: false, motivo: `NC ${ncRef} não encontrada.` }
  const ac = await rest(`/quality_actions?select=id,reference,titulo,description,tipo,status,percent_execucao,deadline,responsible_user_id,horas_previstas,horas_realizadas&occurrence_id=eq.${occ.id}&limit=200`, token).catch(() => ({}))
  const acoes = Array.isArray(ac.data) ? ac.data : []
  const encC = await avaliarEncerramento(occ.id, token)
  const plan = await rest(`/quality_compliance_plans?select=id,codigo,titulo,status,progresso&occurrence_id=eq.${occ.id}&limit=5&order=created_at.desc`, token).catch(() => ({}))
  return {
    ok: true,
    referência: occ.reference,
    tipo: occ.type, estado: occ.status,
    descricao: occ.description,
    causa: occ.cause_analysis,
    área: occ.quality_areas?.name, origem: occ.quality_origins?.name,
    plano: Array.isArray(plan.data) && plan.data[0] ? plan.data[0] : null,
    ações: acoes.map((a) => ({
      ref: a.reference, título: a.titulo || a.description, tipo: a.tipo, estado: a.status,
      progresso: a.percent_execucao, prazo: a.deadline, horas: `${a.horas_realizadas||0}/${a.horas_previstas||'—'}`,
    })),
    encerramento: encC,
  }
}

module.exports = {
  ACTION_TYPES, calcularProgressoPlano, avaliarEncerramento, criarPlano, criarAcao, registarTrabalho,
  proporPlano, confirmarProposta, estadoNc, buscarNc, buscarAcaoPorRef, resolverResponsavel, userIdFromToken, today, diffDias,
}