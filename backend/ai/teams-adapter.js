// teams-adapter.js — Canal Microsoft Teams (Bot Framework, §11/Telegram-style).
// - POST /channels/teams/api/messages : recebe atividades do Bot Framework (Teams)
// - Valida o token de webhook (TEAMS_CHANNEL_TOKEN) — equivalente pragmático à
//   autenticação de APP ID do Teams em dev (sem infra Azure).
// - Converte atividades em IncomingMessage e envia OutgoingMessage.
// Toda a lógica de negócio vive no Messaging Gateway — aqui só transporte.
//
// NOTA Teams: a integração completa no Microsoft Teams requer uma app registada no
// Azure (Bot Framework App ID + Client Secret) e channel secret. Este adapter
// implementa o protocolo de transporte e a normalização; em dev usa TEAMS_CHANNEL_TOKEN
// para validar o webhook. Para produção real, trocar por validação JWT/App Secret do Teams.
const crypto = require('crypto')
const https = require('https')

// ---------- normalização de atividades do Bot Framework ----------
/**
 * Converte uma atividade do Bot Framework do Teams num IncomingMessage interno.
 * Apoia mensagens de texto, mensagens de "mention" e áudio (Fase 4).
 */
function normalizeActivity(activity) {
  if (!activity || activity.type !== 'message') return null
  // ID interno estável e neutro (não expor emails do Teams sem necessidade)
  const fromId = activity.from && activity.from.id ? String(activity.from.id) : null
  if (!fromId) return null
  const conversationId = activity.conversation && activity.conversation.id ? String(activity.conversation.id) : fromId
  const text = (activity.text || '').trim()
  const hasAttachment = Array.isArray(activity.attachments) && activity.attachments.length > 0
  const voiceMedia = hasAttachment ? activity.attachments[0].contentUrl || activity.attachments[0].contentType || 'attachment' : null
  // só text ou voz
  if (!text && !voiceMedia) return null
  return {
    type: voiceMedia && !text ? 'voice' : 'text',
    userId: fromId,
    chatId: conversationId,
    messageId: activity.id || `${fromId}|${activity.timestamp}`,
    text: text || '',
    mediaRef: voiceMedia ? 'teams-attachment' : null, // download real do áudio na Fase 4
  }
}

// ---------- validação do webhook (dev) ----------
/** Aceita o pedido se o header X-Teams-Token bater com TEAMS_CHANNEL_TOKEN. Em dev sem token, aceita. */
function webhookOk(req) {
  const expected = process.env.TEAMS_CHANNEL_TOKEN
  if (!expected) return true // dev sem token
  const got = req.headers['x-teams-token'] || ''
  try {
    return crypto.timingSafeEqual(Buffer.from(String(got)), Buffer.from(String(expected)))
  } catch { return false }
}

// ---------- envio (Bot Framework REST; em dev responde só ok no HTTP) ----------
function sendReply(serviceUrl, conversationId, activityId, text) {
  // Bot Framework: POST para o serviceUrl do canal com a atividade de resposta.
  // Em dev/local sem serviceUrl real, devolvemos uma resposta simulada.
  const url = serviceUrl && String(serviceUrl).startsWith('http') ? serviceUrl : null
  if (!url) return Promise.resolve({ simulated: true, text })
  return new Promise((resolve, reject) => {
    const payload = JSON.stringify({
      type: 'message',
      conversation: { id: conversationId },
      text,
    })
    const u = new URL(url)
    const lib = u.protocol === 'https:' ? https : require('http')
    const req = lib.request(
      { hostname: u.hostname, path: u.pathname, method: 'POST', headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(payload) } },
      (res) => { let d = ''; res.on('data', (c) => (d += c)); res.on('end', () => { try { resolve(JSON.parse(d)) } catch { resolve({ ok: res.statusCode < 400 }) } }) },
    )
    req.on('error', reject)
    req.write(payload)
    req.end()
  })
}

module.exports = { normalizeActivity, webhookOk, sendReply }