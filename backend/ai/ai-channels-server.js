// ai-channels-server.js — Camada de canais externos + endpoints MCP (SAMSYS|Qualidade)
// - POST /channels/telegram/webhook  : recebe updates do Telegram (produção)
// - POST /channels/telegram/poll     : dispara um ciclo de polling (dev/teste)
// - POST /channels/link/start        : gera código de associação (com token de utilizador autenticado)
// - POST /channels/link/confirm      : associa o canal usando o código (via bot ou app)
// - POST /channels/link/revoke       : revoga associação (via app, autenticado)
// - GET  /channels/status            : estado de cada canal (admin, autenticado)
// - POST /mcp/tools/list | /mcp/tools/call : interface programática MCP (autenticado por token)
//
// Segurança: tokens de bot nunca nos logs nem devolvidos; cada ação é associada a um
// utilizador interno; a IA recebe apenas tokens curtos de serviço (nunca credenciais).
const http = require('http')
const crypto = require('crypto')
const { Pool } = require('pg')

// carrega .env local (se existir) — chaves nunca versionadas, logo no arranque
try { require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') }) } catch {}

const PORT = Number(process.env.AI_CHANNELS_PORT || 3005)
const JWT_SECRET = process.env.JWT_SECRET || process.env.JWT_SECRET
const PENDING_TTL_MIN = Number(process.env.AI_PENDING_ACTION_TTL_MINUTES || 120)

const POOL = new Pool({
  host: '127.0.0.1', port: 5432, user: 'postgres',
  password: process.env.PGPASSWORD_DB || process.env.PGPASSWORD, database: 'samsys_qualidade',
})

const telegram = require('./telegram-adapter')
const whatsapp = require('./whatsapp-adapter')
const teams = require('./teams-adapter')
const slack = require('./slack-adapter')
const messaging = require('./messaging-gateway')
const mcpTools = require('./mcp-tools')
const { getServiceTokenFor } = require('./channel-token')

// ---------- JWT ----------
function b64url(buf) { return Buffer.from(buf).toString('base64url') }
function verifyJwt(token) {
  try {
    const [h, b, s] = token.split('.')
    const exp = crypto.createHmac('sha256', JWT_SECRET).update(`${h}.${b}`).digest()
    if (!crypto.timingSafeEqual(exp, Buffer.from(s, 'base64url'))) return null
    const p = JSON.parse(Buffer.from(b, 'base64url').toString())
    if (p.exp && p.exp * 1000 < Date.now()) return null
    return p
  } catch { return null }
}
function signJwt(payload) {
  const h = b64url(JSON.stringify({ alg: 'HS256', typ: 'JWT' }))
  const b = b64url(JSON.stringify(payload))
  const s = b64url(crypto.createHmac('sha256', JWT_SECRET).update(`${h}.${b}`).digest())
  return `${h}.${b}.${s}`
}

function json(res, code, obj) {
  res.writeHead(code, { 'Content-Type': 'application/json; charset=utf-8', 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-telegram-bot-api-secret-token', 'Access-Control-Allow-Methods': 'GET, POST, OPTIONS, DELETE' })
  res.end(JSON.stringify(obj))
}
function readBody(req) {
  return new Promise((resolve) => {
    let d = ''
    req.on('data', (c) => { d += c; if (d.length > 2e6) req.destroy() })
    req.on('end', () => { try { resolve(JSON.parse(d || '{}')) } catch { resolve({}) } })
  })
}
function readBodyRaw(req) {
  return new Promise((resolve) => {
    let d = ''
    req.on('data', (c) => { d += c; if (d.length > 2e6) req.destroy() })
    req.on('end', () => resolve(d))
  })
}

// ---------- helpers de identidade / associação ----------
function genCode() {
  // 6 dígitos evitando confusões (0/O, 1/I)
  const chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ'
  let code = ''
  const rnd = crypto.randomBytes(6)
  for (let i = 0; i < 6; i++) code += chars[rnd[i] % chars.length]
  return code
}

/** Cria um token de associação temporário (hash) e devolve o código legível. */
async function createLinkCode(userId, channel) {
  const code = genCode()
  const tokenHash = crypto.createHash('sha256').update(`${userId}|${channel}|${code}`).digest('hex')
  await POOL.query(
    `insert into ai_pending_actions (user_id, channel, tool_name, payload_json, confirmation_token_hash, status, expires_at)
     values ($1,$2,'link', $3, $4, 'pending', now() + ($5 || ' minutes')::interval)`,
    [userId, channel, JSON.stringify({ code }), tokenHash, String(PENDING_TTL_MIN)],
  )
  return code
}

/** Confirma uma associação: o utilizador envia /link <codigo> no canal. */
async function confirmLink(channel, externalUserId, code) {
  const rows = await POOL.query(
    `select id, user_id from ai_pending_actions
     where channel=$1 and tool_name='link' and status='pending'
       and expires_at > now() and payload_json->>'code'=$2
     order by created_at desc limit 1`,
    [channel, String(code).trim().toUpperCase()],
  )
  const action = rows.rows[0]
  if (!action) return { ok: false, error: 'codigo_invalido_ou_expirado' }
  // associa (upsert)
  await POOL.query(
    `insert into external_ai_identities (user_id, channel, external_user_id, verified_at, is_active)
     values ($1,$2,$3, now(), true)
     on conflict (channel, external_user_id)
     do update set user_id=excluded.user_id, verified_at=now(), revoked_at=null, is_active=true`,
    [action.user_id, channel, String(externalUserId)],
  )
  await POOL.query(`update ai_pending_actions set status='executed', executed_at=now() where id=$1`, [action.id])
  return { ok: true, userId: action.user_id }
}

// ---------- handler do Telegram (mensagens + callbacks + comandos) ----------
async function onTelegramUpdate(n) {
  // comandos de gestão
  if (n.type === 'message' && n.text) {
    const t = n.text.trim()
    if (t === '/start') {
      await telegram.send(n.chatId, 'Olá! Para ligares este chat à tua conta do Programa de Ocorrências, gera um código na aplicação (Área » IA e Canais » Associar Telegram) e envia:\n/link <código>')
      return
    }
    const linkM = t.match(/^\/link\s+([A-Za-z0-9]{6})/i)
    if (linkM) {
      const r = await confirmLink('telegram', n.userId, linkM[1])
      if (r.ok) { await telegram.send(n.chatId, 'Conta associada com sucesso! Já podes perguntar, por ex.: "Quantas ocorrências estão abertas?"') }
      else await telegram.send(n.chatId, 'Código inválido, já usado ou expirado. Gera um novo na aplicação.')
      return
    }
    if (t === '/logout' || t === '/sair') {
      await revokeByIdentity('telegram', n.userId)
      await telegram.send(n.chatId, 'Este chat foi desligado da conta. /start para voltar.')
      return
    }
  }
  // chamar o gateway para processar (identidade -> agente -> resposta)
  const incoming = new messaging.IncomingMessage({
    channel: 'telegram',
    externalUserId: n.userId,
    externalChatId: n.chatId,
    messageId: n.messageId,
    type: n.type === 'callback' ? 'callback' : (n.voiceMedia ? 'voice' : 'text'),
    text: n.text || '',
    mediaRef: n.voiceMedia || null,
  })
  const r = await messaging.processIncoming(incoming)
  if (r.reply) await telegram.send(n.chatId, r.reply.text, { parseMode: r.reply.parseMode })
  if (n.callbackId) await telegram.answerCallback(n.callbackId)
}

async function revokeByIdentity(channel, externalUserId) {
  await POOL.query(`update external_ai_identities set is_active=false, revoked_at=now() where channel=$1 and external_user_id=$2`, [channel, externalUserId])
}

// ---------- handler WhatsApp (eventos normalizados -> gateway) ----------
const seenWaMsgs = new Set() // idempotência por message_id (limite simples)
function pruneSeen() { if (seenWaMsgs.size > 5000) seenWaMsgs.clear() }

async function onWhatsAppUpdate(m) {
  if (seenWaMsgs.has(m.messageId)) return           // duplicados ignorados
  seenWaMsgs.add(m.messageId); pruneSeen()

  // associação por texto (/link <código>) — mesma lógica do Telegram
  if (m.type === 'text' && m.text) {
    const t = m.text.trim()
    const linkM = t.match(/^\/link\s+([A-Za-z0-9]{6})/i)
    if (linkM) {
      const r = await confirmLink('whatsapp', m.userId, linkM[1])
      if (r.ok) await whatsapp.send(m.chatId, 'Conta associada com sucesso! Já podes perguntar, por ex.: "Quantas ocorrências estão abertas?"')
      else await whatsapp.send(m.chatId, 'Código inválido, já usado ou expirado. Gera um novo na aplicação.')
      return
    }
    if (t === '/logout' || t === '/sair') {
      await revokeByIdentity('whatsapp', m.userId)
      await whatsapp.send(m.chatId, 'Este número foi desligado da conta.')
      return
    }
    if (t === '/start' || t === 'oi' || t === 'ola' || t === 'olá') {
      await whatsapp.send(m.chatId, 'Olá! Para ligares este número à tua conta do Programa de Ocorrências, gera um código na app (Área » IA e Canais » Associar WhatsApp) e envia:\n/link <código>')
      return
    }
  }

  const incoming = new messaging.IncomingMessage({
    channel: 'whatsapp',
    externalUserId: m.userId,
    externalChatId: m.chatId,
    messageId: m.messageId,
    type: m.type === 'voice' ? 'voice' : 'text',
    text: m.text || '',
    mediaRef: m.mediaRef || null,
  })
  const r = await messaging.processIncoming(incoming)
  if (r.reply) await whatsapp.send(m.chatId, r.reply.text)
}

// ---------- handler Teams (atividades normalizadas -> gateway) ----------
const seenTeamsMsgs = new Set()
function pruneTeamsSeen() { if (seenTeamsMsgs.size > 5000) seenTeamsMsgs.clear() }

async function onTeamsUpdate(m) {
  if (seenTeamsMsgs.has(m.messageId)) return
  seenTeamsMsgs.add(m.messageId); pruneTeamsSeen()

  // associação por texto (/link <código>)
  if (m.type === 'text' && m.text) {
    const t = m.text.trim()
    const linkM = t.match(/^\/link\s+([A-Za-z0-9]{6})/i)
    if (linkM) {
      const r = await confirmLink('teams', m.userId, linkM[1])
      if (r.ok) return { ok: true, text: 'Conta associada com sucesso! Já podes perguntar, por ex.: "Quantas ocorrências estão abertas?"' }
      return { ok: true, text: 'Código inválido, já usado ou expirado. Gera um novo na aplicação.' }
    }
    if (t === '/logout' || t === '/sair') {
      await revokeByIdentity('teams', m.userId)
      return { ok: true, text: 'Este chat foi desligado da conta.' }
    }
    if (t === '/start' || /^(oi|ola|olá|boa tarde|bom dia)/i.test(t)) {
      return { ok: true, text: 'Olá! Para ligares este chat à tua conta do Programa de Ocorrências, gera um código na app (Área » IA e Canais » Associar Teams) e envia:\n/link <código>' }
    }
  }

  const incoming = new messaging.IncomingMessage({
    channel: 'teams',
    externalUserId: m.userId,
    externalChatId: m.chatId,
    messageId: m.messageId,
    type: m.type === 'voice' ? 'voice' : 'text',
    text: m.text || '',
    mediaRef: m.mediaRef || null,
  })
  try {
    const r = await messaging.processIncoming(incoming)
    const txt = r.reply ? r.reply.text : 'Sem resposta.'
    // o Teams (TextBlock) renderiza markdown, não HTML — converte tags para markdown/plain
    const clean = String(txt || '')
      .replace(/<b>|<\/b>/g, '**')
      .replace(/<i>|<\/i>/g, '*')
      .replace(/<pre>|<\/pre>/g, '```')
      .replace(/<[^>]+>/g, '')
    return { ok: true, text: clean }
  } catch (e) {
    console.error('[teams] erro processIncoming:', e.message)
    return { ok: true, text: 'Não consegui processar a consulta. Tenta de novo.' }
  }
}

// ---------- handler Slack (mensagens normalizadas -> gateway) ----------
const seenSlackMsgs = new Set()
function pruneSlackSeen() { if (seenSlackMsgs.size > 5000) seenSlackMsgs.clear() }

async function onSlackUpdate(m) {
  if (!m || !m.userId) return
  if (seenSlackMsgs.has(m.messageId)) return
  seenSlackMsgs.add(m.messageId); pruneSlackSeen()

  // associação / comandos de texto
  if (m.type === 'text' && m.text) {
    const t = m.text.trim()
    const linkM = t.match(/^\/link\s+([A-Za-z0-9]{6})/i)
    if (linkM) {
      const r = await confirmLink('slack', m.userId, linkM[1])
      return { ok: true, text: r.ok ? 'Conta associada com sucesso! Já podes perguntar, por ex.: "Quantas ocorrências estão abertas?"' : 'Código inválido, já usado ou expirado. Gera um novo na aplicação.' }
    }
    if (t === '/logout' || t === '/sair') {
      await revokeByIdentity('slack', m.userId)
      return { ok: true, text: 'Este chat foi desligado da conta. /start para voltar.' }
    }
    if (t === '/start' || t === '/ajuda' || t === 'oi' || t === 'olá' || t === 'ola') {
      return { ok: true, text: 'Olá! Para ligares este chat à tua conta do Programa de Ocorrências, gera um código na app (Área » IA e Canais » Associar Slack) e envia:\n/link <código>' }
    }
  }

  const incoming = new messaging.IncomingMessage({
    channel: 'slack',
    externalUserId: m.userId,
    externalChatId: m.chatId,
    messageId: m.messageId,
    type: m.type === 'voice' ? 'voice' : 'text',
    text: m.text || '',
    mediaRef: m.mediaRef || null,
  })
  const r = await messaging.processIncoming(incoming)
  return { ok: true, text: r.reply ? r.reply.text : 'Sem resposta.' }
}

// ---------- router ----------
const server = http.createServer(async (req, res) => {
  if (req.method === 'OPTIONS') { json(res, 204, {}); return }
  const url = new URL(req.url, `http://${req.headers.host}`)
  const path = url.pathname
  const token = (req.headers.authorization || '').match(/^Bearer (.+)$/)?.[1]

  // ----- webhook Telegram (produção; valida secret) -----
  if (req.method === 'POST' && path === '/channels/telegram/webhook') {
    if (!telegram.webhookSecretOk(req)) return json(res, 403, { error: 'forbidden' })
    const body = await readBody(req)
    const r = await telegram.handleWebhook(body)
    return json(res, 200, r)
  }

  // ----- webhook WhatsApp: verificação (GET, challenge do Meta) -----
  if (req.method === 'GET' && path === '/channels/whatsapp/webhook') {
    const challenge = whatsapp.challengeOk(url.searchParams)
    if (challenge === null) return json(res, 403, { error: 'verificação inválida' })
    res.writeHead(200, { 'Content-Type': 'text/plain' })
    res.end(String(challenge))
    return
  }
  // ----- webhook WhatsApp: eventos (POST, valida assinatura) -----
  if (req.method === 'POST' && path === '/channels/whatsapp/webhook') {
    const raw = await readBodyRaw(req)
    if (!whatsapp.signatureOk(req, raw)) return json(res, 403, { error: 'assinatura inválida' })
    let payload
    try { payload = JSON.parse(raw) } catch { return json(res, 400, { error: 'bad json' }) }
    if (payload && payload.object === 'whatsapp_business_account') {
      // confirmação de entrega/ler — responde sempre 200 (o Meta reenvia se falhar)
      await whatsapp.handleWebhook(payload, onWhatsAppUpdate)
    }
    return json(res, 200, { ok: true })   // sempre 200 p/ evitar reentregas
  }

  // ----- webhook Teams (Bot Framework) -----
  if (req.method === 'POST' && path === '/channels/teams/api/messages') {
    if (!teams.webhookOk(req)) return json(res, 403, { error: 'forbidden' })
    const body = await readBody(req)
    // ping de verificação do Bot Framework
    if (body && body.type === 'ping') return json(res, 200, {})
    const n = teams.normalizeActivity(body)
    if (n) {
      const reply = await onTeamsUpdate(n)
      if (reply && reply.ok) {
        // devolve a resposta ao Bot Framework (activity reply)
        return json(res, 200, { type: 'message', text: reply.text })
      }
    }
    return json(res, 200, {})  // sempre 200 p/ evitar reenvios
  }
  // ----- verificação simples do webhook Teams (dev) -----
  if (req.method === 'GET' && path === '/channels/teams/health') {
    return json(res, 200, { ok: true, teams: env('TEAMS_ENABLED', '') === 'true' })
  }

  // ----- webhook Slack (Events API, opcional; Socket Mode é o default em dev) -----
  if (req.method === 'POST' && path === '/channels/slack/events') {
    const raw = await readBodyRaw(req)
    if (!slack.signatureOk(req, raw)) return json(res, 403, { error: 'assinatura inválida' })
    let body = {}
    try { body = JSON.parse(raw || '{}') } catch { return json(res, 400, { error: 'bad json' }) }
    if (body.type === 'url_verification') return json(res, 200, { challenge: body.challenge })   // verificação
    const n = slack.normalizeApiEvent(body)
    if (n) {
      const replyData = await onSlackUpdate(n)
      if (replyData && replyData.text && n.chatId) await slack.send(n.chatId, replyData.text).catch(() => {})
    }
    return json(res, 200, { ok: true })   // responde sempre 200 (o Slack reenvia se falhar)
  }

  // ----- dispara/consulta polling (dev/teste) -----
  if (req.method === 'POST' && path === '/channels/telegram/poll') {
    if (env('TELEGRAM_ENABLED', '') !== 'true') return json(res, 200, { ok: false, reason: 'telegram_disabled' })
    return json(res, 200, { ok: true })
  }

  // ----- associar (gerar código) — autenticado -----
  if (req.method === 'POST' && path === '/channels/link/start') {
    const claims = token ? verifyJwt(token) : null
    if (!claims) return json(res, 401, { error: 'unauthorized' })
    const body = await readBody(req)
    const channel = body.channel || 'telegram'
    try {
      const code = await createLinkCode(claims.sub, channel)
      return json(res, 200, { code, expires_min: PENDING_TTL_MIN })
    } catch (e) { return json(res, 500, { error: e.message }) }
  }

  // ----- confirmar via API (opcional; o bot já trata /link) -----
  if (req.method === 'POST' && path === '/channels/link/confirm') {
    const body = await readBody(req)
    const r = await confirmLink(body.channel || 'telegram', body.external_user_id, body.code)
    return json(res, r.ok ? 200 : 400, r)
  }

  // ----- revogar (autenticado) -----
  if (req.method === 'POST' && path === '/channels/link/revoke') {
    const claims = token ? verifyJwt(token) : null
    if (!claims) return json(res, 401, { error: 'unauthorized' })
    const body = await readBody(req)
    await POOL.query(`update external_ai_identities set is_active=false, revoked_at=now() where user_id=$1 and channel=$2`, [claims.sub, body.channel || 'telegram'])
    return json(res, 200, { ok: true })
  }

  // ----- status dos canais (admin, autenticado) -----
  if (req.method === 'GET' && path === '/channels/status') {
    const claims = token ? verifyJwt(token) : null
    if (!claims) return json(res, 401, { error: 'unauthorized' })
    return json(res, 200, {
      telegram: { enabled: env('TELEGRAM_ENABLED', '') === 'true', webhook: env('TELEGRAM_WEBHOOK_URL', ''), mode: env('TELEGRAM_WEBHOOK_URL', '') ? 'webhook' : 'polling' },
      whatsapp: { enabled: env('WHATSAPP_ENABLED', '') === 'true', webhook: env('WHATSAPP_WEBHOOK_URL', ''), mode: env('WHATSAPP_WEBHOOK_URL', '') ? 'webhook' : 'off' },
      teams: { enabled: env('TEAMS_ENABLED', '') === 'true', webhook: env('TEAMS_WEBHOOK_URL', ''), mode: env('TEAMS_WEBHOOK_URL', '') ? 'webhook' : 'webhook' },
      slack: { enabled: env('SLACK_ENABLED', '') === 'true', mode: env('SLACK_APP_TOKEN', '') ? 'socket' : 'events', webhook: '/channels/slack/events' },
      audio: { enabled: env('VOICE_ENABLED', '') === 'true' || env('WHISPER_ENABLED', '') === 'true', stt: process.env.STT_PROVIDER || 'local', model: process.env.STT_MODEL || 'small', tts: (process.env.TTS_ENABLED || 'false') === 'true' },
      mcp: { enabled: env('MCP_ENABLED', 'true') === 'true', tools: mcpTools.ALL_TOOLS.map((t) => t.name) },
    })
  }

  // ----- interface MCP programática (list + call), autenticado -----
  if (req.method === 'POST' && (path === '/mcp/tools/list' || path === '/mcp/tools/call')) {
    const claims = token ? verifyJwt(token) : null
    if (!claims) return json(res, 401, { error: 'unauthorized' })
    const body = await readBody(req)
    if (path.endsWith('/list')) return json(res, 200, {
      read: mcpTools.ALL_TOOLS.map((t) => ({ name: t.name, description: t.description, inputSchema: t.inputSchema })),
      write: (mcpTools.WRITE_TOOLS || []).map((t) => ({ name: t.name, description: t.description, inputSchema: t.inputSchema })),
      nota: 'As ferramentas write SÓ persistem após confirmação explícita do utilizador (fluxo proposta -> aprovação).',
    })
    const r = await mcpTools.callTool(body.name, body.args, token)
    return json(res, r.ok ? 200 : 200, r) // 200 com {ok:false, error} para o LLM não rebentar
  }

  return json(res, 404, { error: 'not_found' })
})

// ---------- env helper ----------
function env(k, d) { const v = process.env[k]; return v === undefined ? d : v }

// ---------- boot ----------
// Guarda anti-duplo: Socket Mode do Slack/Telegram é um websocket independente da
// porta HTTP — se houver outro processo ai-channels já vivo (porta :3005 ocupada),
// NÃO ligar os canais, senão vários clientes respondem à mesma mensagem → flood.
function isPortOpen(port) {
  const net = require('net')
  return new Promise((resolve) => {
    const s = net.connect({ port, host: '127.0.0.1' })
    s.once('connect', () => { s.destroy(); resolve(true) })
    s.once('error', () => resolve(false))
    setTimeout(() => { try { s.destroy() } catch {}; resolve(false) }, 1500)
  })
}
(async () => {
  const taken = await isPortOpen(PORT)
  if (taken && env('FORCE_SINGLE', '') !== 'true') {
    console.error(`[channels] ABORTA : já existe outro processo em :${PORT} (evita flood de canais). Morte-o primeiro ou use FORCE_SINGLE=true.`)
    process.exit(1)
  }
  bootChannels()
  server.listen(PORT, '127.0.0.1', () => console.log(`[channels] Canais IA a ouvir em http://127.0.0.1:${PORT}`))
})()

function bootChannels() {
if (env('VOICE_ENABLED', '') === 'true' || env('WHISPER_ENABLED', '') === 'true') {
  try { require('./voice-service').warmup() } catch (e) { console.error('[channels] voice warmup erro:', e.message) }
}
if (env('TELEGRAM_ENABLED', '') === 'true' && env('TELEGRAM_BOT_TOKEN', '')) {
  if (!env('TELEGRAM_WEBHOOK_URL', '')) {
    telegram.startPolling(onTelegramUpdate).catch((e) => console.error('[channels] polling erro:', e.message))
  }
}
if (env('SLACK_ENABLED', '') === 'true' && env('SLACK_APP_TOKEN', '')) {
  slack.startSocketMode(async (n) => {
    const replyData = await onSlackUpdate(n)
    if (replyData && replyData.text && n.chatId) {
      try { await slack.send(n.chatId, replyData.text) } catch (e) { console.error('[slack] envio erro:', e.message) }
    }
  }).catch((e) => console.error('[channels] slack socket erro:', e.message))
}
}

module.exports = { server }