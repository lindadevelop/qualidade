// shared-lists.js — listas de apoio (áreas, origens) via PostgREST COM O TOKEN DO UTILIZADOR (RLS).
// Usadas pelas tools MCP para resolver nomes sem inventar IDs (§15).
const http = require('http')

const REST_URL = process.env.SUPABASE_REST_URL || 'http://127.0.0.1:3001'

function rest(path, token) {
  return new Promise((resolve, reject) => {
    const u = new URL(REST_URL)
    const req = http.request(
      { hostname: u.hostname, port: u.port, path, method: 'GET', headers: { Authorization: `Bearer ${token}`, apikey: process.env.SUPABASE_ANON_KEY || 'anon', Accept: 'application/json' } },
      (res) => { let d = ''; res.on('data', (c) => (d += c)); res.on('end', () => { try { resolve(JSON.parse(d)) } catch { resolve([]) } }) },
    )
    req.on('error', reject)
    req.end()
  })
}

async function listAreas(token) {
  return rest('/quality_areas?select=id,name&active=eq.true&order=sort_order', token)
}
async function listOrigins(token) {
  return rest('/quality_origins?select=id,name&active=eq.true&order=sort_order', token)
}

module.exports = { listAreas, listOrigins }