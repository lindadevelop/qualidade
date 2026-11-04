require('dotenv').config();
// ai/_alert-worker.js — calcula as prioridades atuais e imprime um resumo (JSON).
// Usado pelo ai-alerts.js (agendado) para gerar o conteúdo a enviar por canal.
const { Pool } = require('pg')

async function main() {
  const POOL = new Pool({ host: '127.0.0.1', port: 5432, user: 'postgres', password: process.env.PGPASSWORD_DB || process.env.PGPASSWORD, database: 'samsys_qualidade' })
  try {
    const { rows } = await POOL.query("select id, full_name from public.profiles where role in ('management','quality','admin') limit 1")
    if (!rows.length) { console.log('sem utilizador para alertas'); return }
    const { getServiceTokenFor } = require('./channel-token')
    const token = await getServiceTokenFor(rows[0].id)
    const { calcularPrioridades } = require('./consultor-service')
    const r = await calcularPrioridades(token, 5)
    const linha = r.prioridades.map((p) => `${p.prioridade}:${p.reference}`).join(', ')
    console.log(JSON.stringify({ hoje: r.hoje, total: r.total, top: linha, prioridades: r.prioridades }))
  } catch (e) { console.error('[alert-worker] erro:', e.message) }
  finally { await POOL.end() }
}

main()