// whatsapp-adapter.js — Canal WhatsApp (Cloud API oficial, §11).
// - GET /channels/whatsapp/webhook  : verificação (challenge) quando o Meta pede
// - POST /channels/whatsapp/webhook : recebe eventos (mensagens de texto, interactivos, áudio)
// - Valida assinatura X-Hub-Signature-256 (HMAC SHA-256 do WHATSAPP_APP_SECRET)
// - Converte updates em IncomingMessage e envia OutgoingMessage (Cloud API)
// Toda a lógica de negócio vive no Messaging Gateway — aqui só transporte.
const crypto = require('crypto')
const https = require('https')

// ---------- normalização ----------
const PHONE_PREFIXES = ['application', 'group'] // para permitir futuras extensões

function strip55(num) {
  // mantém só dígitos; remove país PT (+351) se presente no number
  const d = String(num || '').replace(/\D/g, '')
  return d.length > 9 ? d.slice(-9) : d
}

/**
 * Converte um payload de webhook do WhatsApp Cloud API num IncomingMessage interno.
 * Suporta mensagens de texto e interativas (botões/listas) e áudio (Fase 4/Whisper).
 */
function normalizeWebhook(payload) {
  if (!payload || payload.object !== 'whatsapp_business_account') return []
  const out = []
  for (const entry of payload.entry || []) {
    for (const change of entry.changes || []) {
      const wam = change.value && change.value.messages
      if (!wam) continue
      for (const m of wam) {
        const from = m.from // phone de origem
        const type = m.type || 'text'
        let text = null
        let voiceMedia = null
        if (type === 'text' && m.text) text = m.text.body
        else if (type === 'interactive' && m.interactive) {
          // respostas a botões/listas
          if (m.interactive.button_reply) text = m.interactive.button_reply.id || m.interactive.button_reply.title
          else if (m.interactive.list_reply) text = m.interactive.list_reply.id || m.interactive.list_reply.title
        } else if (type === 'audio') {
          voiceMedia = m.audio ? m.audio.id : null
          text = null
        } else if (type === 'image' && m.caption) text = m.caption
        // ignora outros tipos com segurança (status, ephemeral, etc.)
        if (text === null && !voiceMedia) continue
        out.push({
          type: voiceMedia ? 'voice' : 'text',
          userId: strip55(from),
          chatId: strip55(from),
          messageId: m.id,            // idempotência por message id
          text,
          mediaRef: voiceMedia,
        })
      }
    }
  }
  return out
}

/** True se a origem/assinatura for VÁLIDA (HMAC do app secret). Desliga em dev quando não há secret. */
function signatureOk(req, rawBody) {
  const appSecret = process.env.WHATSAPP_APP_SECRET
  if (!appSecret) return true // dev sem secret
  const sig = (req.headers['x-hub-signature-256'] || '').replace(/^sha256=/, '')
  if (!sig) return false
  const hmac = crypto.createHmac('sha256', appSecret).update(rawBody).digest('hex')
  try {
    return crypto.timingSafeEqual(Buffer.from(sig), Buffer.from(hmac))
  } catch { return false }
}

// ---------- Cloud API ----------
function graphReq(phoneNumberId, path, body) {
  const token = process.env.WHATSAPP_ACCESS_TOKEN
  if (!token) return Promise.reject(new Error('WHATSAPP_ACCESS_TOKEN não configurado'))
  return new Promise((resolve, reject) => {
    const payload = JSON.stringify(body || {})
    const p = `/v19.0/${phoneNumberId}/${path}`
    const req = https.request(
      { hostname: 'graph.facebook.com', path: p, method: 'POST', headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(payload), Authorization: `Bearer ${token}` } },
      (res) => { let d = ''; res.on('data', (c) => (d += c)); res.on('end', () => { try { resolve(JSON.parse(d)) } catch { resolve({ ok: false }) } }) },
    )
    req.on('error', reject)
    req.write(payload)
    req.end()
  })
}

/** Envia uma mensagem de texto (respeita o modelo simples de templates/replies). */
async function send(phone, text, opts = {}) {
  const pid = process.env.WHATSAPP_PHONE_NUMBER_ID
  if (!pid) return Promise.reject(new Error('WHATSAPP_PHONE_NUMBER_ID não configurado'))
  // o WhatsApp não renderiza HTML — remove tags mas mantém negrito via asteriscos
  const bodyTxt = String(text || '')
    .replace(/<b>|<\/b>/g, '*')
    .replace(/<pre>|<\/pre>/g, '```')
    .replace(/<[^>]+>/g, '')
  const body = {
    messaging_product: 'whatsapp',
    recipient_type: 'individual',
    to: `351${strip55(phone)}`,
    type: 'text',
    text: { body: bodyTxt },
  }
  if (opts.buttons && opts.buttons.length) {
    body.type = 'interactive'
    body.interactive = {
      type: 'button',
      body: { text },
      action: { buttons: opts.buttons.slice(0, 3).map((b) => ({ type: 'reply', reply: { id: b.callback_data || b.text, title: b.text.slice(0, 20) } })) },
    }
    delete body.text
  }
  return graphReq(pid, 'messages', body)
}

// ---------- webhook handlers ----------
/** Verificação inicial do webhook Meta (GET). Devolve o hub.challenge se o token bater. */
function challengeOk(query) {
  const verify = process.env.WHATSAPP_VERIFY_TOKEN
  if (!verify || !query) return null
  const mode = query.get ? query.get('hub.mode') : (query['hub.mode'])
  const token = query.get ? query.get('hub.verify_token') : (query['hub.verify_token'])
  const challenge = query.get ? query.get('hub.challenge') : (query['hub.challenge'])
  if (mode === 'subscribe' && token === verify) return challenge
  return null
}

/** Processa os eventos e encaminha para o handler comum. */
async function handleWebhook(payload, onMessage) {
  const msgs = normalizeWebhook(payload)
  const handled = []
  for (const m of msgs) {
    handled.push(await onMessage(m))
  }
  return { count: msgs.length }
}

module.exports = { send, handleWebhook, normalizeWebhook, signatureOk, challengeOk, strip55 }