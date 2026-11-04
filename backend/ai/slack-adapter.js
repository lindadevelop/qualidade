// slack-adapter.js — Canal Slack (via Socket Mode + Web API).
// Método mais simples para dev (websocket, sem HTTPS público), como o Telegram em polling.
//   - SLACK_BOT_TOKEN  : token xoxb-… (do App)
//   - SLACK_APP_TOKEN  : token xapp-… (Socket Mode)
//   - Escuta "message.im" (mensagens diretas ao bot) e "app_mention".
// Suporta também Events API (webhook) com verificação de assinatura X-Slack-Signature.
const { WebClient } = require('@slack/web-api')
const { SocketModeClient } = require('@slack/socket-mode')
const crypto = require('crypto')

let web
let socket
let running = false
let onMessage = async () => {}
let botUserId = null          // id do próprio bot (ignorar as mensagens dele)

async function buildClients() {
  const botToken = process.env.SLACK_BOT_TOKEN
  const appToken = process.env.SLACK_APP_TOKEN
  if (botToken && !web) {
    web = new WebClient(botToken)
    // identifica o user id do próprio bot para nunca processar as mensagens dele
    try {
      const a = await web.auth.test()
      botUserId = a.user_id || a.user || null
      if (botUserId) console.log('[slack] id do bot:', botUserId)
    } catch (e) { console.error('[slack] auth.test erro:', e.message) }
  }
  if (appToken && !socket) {
    socket = new SocketModeClient({ appToken, logLevel: 0 })
    socket.on('error', (e) => console.error('[slack] socket erro:', e.message || e))
  }
  // Socket Mode só precisa do app token (xapp-) para conectar
  return !!appToken
}

/** Normaliza um evento do Slack (message.im ou app_mention) num IncomingMessage. */
function normalizeEvent(event) {
  if (!event || event.type !== 'message') return null
  // ignora o próprio bot: subtype bot_message OU bot_id OU user é o bot
  const isBot =
    event.subtype === 'bot_message' ||
    event.bot_id ||
    (botUserId && (event.user === botUserId || event.bot_user_id === botUserId)) ||
    (event.app_id && !event.user) // mensagens de app sem user são do bot
  if (isBot) return null
  if (event.subtype === 'message_deleted' || event.subtype === 'message_changed') return null
  // áudio / voice clip: event.files[] com mimetype audio/* (ou file em messages_im)
  const files = Array.isArray(event.files) ? event.files : (event.message && Array.isArray(event.message.files) ? event.message.files : [])
  if (!files.length && event.message && event.message.file && /^audio\//.test(event.message.file.mimetype || '')) files.push(event.message.file)
  const audioFile = files.find((f) => f && /^audio\//.test(f.mimetype || ''))
  if (audioFile && audioFile.id) {
    return {
      type: 'voice',
      userId: String(event.user || event.message?.user || ''),
      chatId: String(event.channel || ''),
      messageId: String(event.ts || `${event.channel}|${event.user}|${Date.now()}`),
      text: (event.text || '').trim(),
      mediaRef: String(audioFile.id),
      mediaMime: audioFile.mimetype || null,
    }
  }
  const text = (event.text || '').trim()
  if (!text) return null
  return {
    type: 'text',
    userId: String(event.user || ''),
    chatId: String(event.channel || ''),
    messageId: String(event.ts || `${event.channel}|${event.user}|${Date.now()}`),
    text,
    mediaRef: null,
  }
}

/** Inicia o Socket Mode (apenas mensagens diretas e mentions). */
async function startSocketMode(handler) {
  onMessage = handler
  if (running) return { stop: () => {} }
  const ok = await buildClients()
  if (!ok) throw new Error('SLACK_APP_TOKEN (xapp-) é obrigatório para Socket Mode')

  // Data de arranque: ignora mensagens entregues em backfill pelo Slack
  // (reconnect/reinstall reentregam TODO o histórico do DM). Para além do
  // filtro por ts, descarta tudo durante DRAIN_S segundos após ligar (absorve
  // o flood inicial em bloco, sem responder), e depois só trata mensagens novas.
  const DRAIN_S = 60
  const bootTs = Date.now() / 1000

  socket.on('message', async ({ ack, event }) => {
    try { ack() } catch { /* se já ack'd */ }
    const isEvent = event && event.type === 'message'
    const channelType = event && (event.channel_type || (event.channel && event.channel[0] === 'D' ? 'im' : 'channel'))
    const evTs = event && event.ts ? parseFloat(event.ts) : 0
    const age = Date.now() / 1000 - evTs
    const inDrain = Date.now() / 1000 - bootTs < DRAIN_S
    if (isEvent && (channelType === 'im' || channelType === 'channel')
        && evTs >= bootTs              // mais recente que o arranque
        && age < 120                   // e antiga < 2 min (não é backfill)
        && !inDrain                    // e fora da janela de dreno inicial
    ) {
      const n = normalizeEvent(event)
      if (n) {
        // NUNCA deixar o handler rejeitar: se o envio falha (ex. rate-limit),
        // o socket-mode re-entrega a MESMA mensagem → loop infinito de flood.
        try { await onMessage(n) } catch (e) { console.error('[slack] handler erro:', e.message) }
      }
    }
  })
  await socket.start()
  running = true
  console.log('[slack] Socket Mode ativo (a ignorar histórico/backfill)')
  return { stop: () => { try { socket.disconnect() } catch {} } }
}

/** Envia uma mensagem a um canal (DM ou canal). */
async function send(channelId, text) {
  const botToken = process.env.SLACK_BOT_TOKEN
  if (!web || !botToken) throw new Error('SLACK_BOT_TOKEN não configurado')
  // o Slack interpreta markdown, não HTML — converte <b>/<i>/tags para markdown/plain
  const t = String(text || '')
    .replace(/<b>|<\/b>/g, '*')
    .replace(/<i>|<\/i>/g, '_')
    .replace(/<pre>|<\/pre>/g, '```')
    .replace(/<[^>]+>/g, '')
  await web.chat.postMessage({ channel: channelId, text: t })
  return { ok: true }
}

/** Descarrega um ficheiro/voice clip privado do Slack usando o token do bot. */
async function downloadFile(fileId, destPath) {
  if (!web) throw new Error('SLACK_BOT_TOKEN não configurado')
  const fs = require('fs')
  const info = await web.files.info({ file: fileId })
  const file = info && info.file
  if (!file || !file.url_private) throw new Error('slack_files_info_falhou')
  // alguns ficheiros estão sob auth (url_private_download); pedir como autenticado
  const url = file.url_private_download || file.url_private
  const res = await fetch(url, { headers: { Authorization: `Bearer ${process.env.SLACK_BOT_TOKEN}` } })
  if (!res.ok) throw new Error('slack_download_falhou')
  const buf = Buffer.from(await res.arrayBuffer())
  fs.writeFileSync(destPath, buf)
  return destPath
}

// ---------- Events API (opcional, para produção com HTTPS) ----------
/** Verifica a assinatura X-Slack-Signature (HMAC SHA-256 com o signing secret + timestamp). */
function signatureOk(req, rawBody) {
  const signing = process.env.SLACK_SIGNING_SECRET
  if (!signing) return true
  const ts = req.headers['x-slack-request-timestamp']
  const sig = req.headers['x-slack-signature']
  if (!ts || !sig) return false
  if (Math.abs(Date.now() / 1000 - Number(ts)) > 300) return false  // replay
  const base = `v0:${ts}:${rawBody}`
  const hmac = crypto.createHmac('sha256', signing).update(base).digest('hex')
  const expect = `v0=${hmac}`
  try { return crypto.timingSafeEqual(Buffer.from(expect), Buffer.from(String(sig))) } catch { return false }
}

/** Converte um event payload da Events API para IncomingMessage. */
function normalizeApiEvent(payload) {
  return normalizeEvent(payload && payload.event)
}

module.exports = { startSocketMode, normalizeEvent, normalizeApiEvent, send, signatureOk, buildClients, downloadFile }