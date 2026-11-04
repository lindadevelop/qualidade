// ollama-service.js — cliente Ollama encapsulado (nunca o resto do código depende da API direta)
// Config resolve-se via env com defaults; trocar modelo não requer alterar código.
const http = require('http')
const https = require('https')

const CFG = {
  enabled: process.env.AI_ENABLED !== 'false',                       // default true
  baseUrl: process.env.OLLAMA_BASE_URL || 'http://localhost:11434',
  model: process.env.OLLAMA_MODEL || 'llama3.2:3b',
  timeoutMs: Number(process.env.OLLAMA_TIMEOUT || 60000),
  temperature: Number(process.env.OLLAMA_TEMPERATURE || 0.1),
  maxResultRows: Number(process.env.AI_MAX_RESULT_ROWS || 100),
  chatHistoryLimit: Number(process.env.AI_CHAT_HISTORY_LIMIT || 8),
}

function request(method, path, body, timeoutMs) {
  return new Promise((resolve, reject) => {
    const u = new URL(CFG.baseUrl)
    const lib = u.protocol === 'https:' ? https : http
    const payload = body ? JSON.stringify(body) : null
    const req = lib.request(
      {
        hostname: u.hostname, port: u.port, path, method,
        headers: { 'Content-Type': 'application/json' },
        timeout: timeoutMs ?? CFG.timeoutMs,
      },
      (res) => {
        let data = ''
        res.on('data', (c) => (data += c))
        res.on('end', () => {
          try { resolve(JSON.parse(data)) } catch { reject(new Error('Resposta inválida do Ollama')) }
        })
      },
    )
    req.on('timeout', () => { req.destroy(new Error('Timeout do Ollama')) })
    req.on('error', reject)
    if (payload) req.write(payload)
    req.end()
  })
}

/** healthcheck: Ollama disponível + modelo presente */
async function status() {
  try {
    const tags = await request('GET', '/api/tags', null)
    const models = (tags.models || []).map((m) => m.name)
    if (!models.length) return { available: false, modelAvailable: false, reason: 'Sem modelos' }
    const found = models.includes(CFG.model) || models.some((m) => m.startsWith(CFG.model + ':'))
    return { available: true, modelAvailable: found, model: CFG.model, reason: found ? null : 'Modelo não encontrado' }
  } catch (e) {
    return { available: false, modelAvailable: false, reason: e.message }
  }
}

/** Chat com resposta em JSON estruturado (pede explicitamente só JSON). */
async function chatJson(system, user) {
  const body = {
    model: CFG.model,
    messages: [
      { role: 'system', content: system },
      { role: 'user', content: user },
    ],
    stream: false,
    temperature: CFG.temperature,
    format: 'json',
  }
  const res = await request('POST', '/api/chat', body)
  const content = (res.message && res.message.content) || ''
  // extrair primeiro bloco JSON {...}
  const m = content.match(/\{[\s\S]*\}/)
  if (!m) throw new Error('JSON não encontrado na resposta do modelo')
  try { return JSON.parse(m[0]) } catch { throw new Error('JSON inválido na resposta do modelo') }
}

/** Chat para explicação (texto natural). */
async function chatText(system, user) {
  const body = {
    model: CFG.model,
    messages: [
      { role: 'system', content: system },
      { role: 'user', content: user },
    ],
    stream: false,
    temperature: Number(process.env.OLLAMA_EXPLAIN_TEMPERATURE || 0.2),
  }
  const res = await request('POST', '/api/chat', body)
  return (res.message && res.message.content) || ''
}

module.exports = { CFG, status, chatJson, chatText }