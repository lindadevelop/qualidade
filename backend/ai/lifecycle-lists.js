// lifecycle-lists.js — acesso read-only às tabelas lifecycle_* via PostgREST COM O TOKEN DO UTILIZADOR (RLS).
// Usado pelas tools MCP de pesquisa para expor candidaturas/vagas/tarefas/comunicações à IA (§15).
const http = require('http')

const REST_URL = process.env.SUPABASE_REST_URL || 'http://127.0.0.1:3001'

function rest(path, token) {
  return new Promise((resolve, reject) => {
    const u = new URL(REST_URL)
    const req = http.request(
      { hostname: u.hostname, port: u.port, path, method: 'GET', headers: { Authorization: `Bearer ${token}`, apikey: process.env.VITE_SUPABASE_ANON_KEY || 'anon', Accept: 'application/json' } },
      (res) => { let d = ''; res.on('data', (c) => (d += c)); res.on('end', () => { try { resolve(JSON.parse(d)) } catch { resolve([]) } }) },
    )
    req.on('error', reject)
    req.end()
  })
}
const enc = encodeURIComponent

// resolve reference (LCY-… / VG-…) para UUID, se necessário
async function resolveCasoId(ref, token) {
  if (!ref) return null
  const rows = await rest(`/lifecycle_casos?select=id&reference=eq.${enc(ref)}&limit=1`, token)
  return Array.isArray(rows) && rows.length ? rows[0].id : null
}
async function resolveVagaId(ref, token) {
  if (!ref) return null
  const rows = await rest(`/lifecycle_vagas?select=id&reference=eq.${enc(ref)}&limit=1`, token)
  return Array.isArray(rows) && rows.length ? rows[0].id : null
}

// ---- candidaturas (casos) ----
async function listCasos({ estado, search, limit } = {}, token) {
  let p = '/lifecycle_casos?select=reference,vaga_id,nome,email,telefone,origem,fonte,tipo,estado,cv_url,score,decisao_triagem,motivo_encerramento,data_entrada,funcao,equipa,aviso_duplicado,created_by&order=created_at.desc'
  const conds = []
  if (estado) conds.push(`estado=eq.${enc(estado)}`)
  if (search) conds.push(`nome=ilike.*${enc(search)}*`)
  if (conds.length) p += '&' + conds.join('&')
  if (limit) p += `&limit=${limit}`
  return rest(p, token)
}
async function listVagas({ estado, search } = {}, token) {
  let p = '/lifecycle_vagas?select=reference,titulo,departamento,funcao,local,tipo,motivo,data_desejada,estado,aprovado_em&order=created_at.desc'
  const conds = []
  if (estado) conds.push(`estado=eq.${enc(estado)}`)
  if (search) conds.push(`titulo=ilike.*${enc(search)}*`)
  if (conds.length) p += '&' + conds.join('&')
  return rest(p, token)
}
async function listTarefas(casoId, { gate, status } = {}, token) {
  let p = '/lifecycle_tarefas?select=*&order=created_at.asc'
  const conds = []
  if (casoId) conds.push(`caso_id=eq.${enc(casoId)}`)
  if (gate) conds.push(`gate=eq.${enc(gate)}`)
  if (status) conds.push(`status=eq.${enc(status)}`)
  if (conds.length) p += '&' + conds.join('&')
  return rest(p, token)
}
async function listComunicacoes(casoId, token) {
  let p = '/lifecycle_comunicacoes?select=ref,tipo,destino,template,estado,created_at&order=created_at.desc'
  if (casoId) p += `&caso_id=eq.${enc(casoId)}`
  return rest(p, token)
}

module.exports = { listCasos, listVagas, listTarefas, listComunicacoes, resolveCasoId, resolveVagaId }