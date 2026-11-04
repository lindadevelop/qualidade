// telegram-adapter.js — Canal Telegram (primeiro canal externo, §10).
// Para dev/teste usa long-polling (getUpdates); em produção usa webhook (TELEGRAM_WEBHOOK_URL).
// Converte updates do Telegram em IncomingMessage e envia OutgoingMessage.
const http = require('http')
const https = require('https')
const fs = require('fs')

// ---------- telegram HTTP (https) ----------
function tgReq(method, body) {
  const token = process.env.TELEGRAM_BOT_TOKEN
  if (!token) return Promise.reject(new Error('TELEGRAM_BOT_TOKEN não configurado'))
  return new Promise((resolve, reject) => {
    const payload = JSON.stringify(body || {})
    const path = `/bot${token}/${method}`
    const req = https.request({ hostname: 'api.telegram.org', path, method: 'POST', headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(payload) } }, (res) => {
      let d = ''
      res.on('data', (c) => (d += c))
      res.on('end', () => { try { resolve(JSON.parse(d)) } catch { resolve({ ok: false }) } })
    })
    req.on('error', reject)
    req.write(payload)
    req.end()
  })
}

// ---------- polling (dev) ----------
let offset = 0
let running = false

function normalizeUpdate(u) {
  if (u.message) return { type: 'message', userId: String(u.message.from && u.message.from.id), chatId: String(u.message.chat && u.message.chat.id), messageId: String(u.message.message_id), text: u.message.text, voiceMedia: u.message.voice ? u.message.voice.file_id : null }
  if (u.callback_query && u.callback_query.data) return { type: 'callback', userId: String(u.callback_query.from.id), chatId: String(u.callback_query.message.chat.id), messageId: String(u.callback_query.message.message_id), text: u.callback_query.data, callbackId: u.callback_query.id }
  if (u.edited_message) return { type: 'edited', userId: String((u.edited_message.from || {}).id), chatId: String((u.edited_message.chat || {}).id), messageId: String(u.edited_message.message_id), text: u.edited_message.text }
  return null
}

async function getUpdates() {
  const r = await tgReq('getUpdates', { offset, timeout: 25 })
  if (r.ok && Array.isArray(r.result)) {
    for (const u of r.result) {
      if (u.update_id >= offset) offset = u.update_id + 1
      const n = normalizeUpdate(u)
      if (n) await onUpdate(n)
    }
  }
}

/** Callback injetado pelo gateway (processa uma mensagem normalizada). */
let onUpdate = async () => {}

/** Inicia o loop de polling (para dev/teste). */
async function startPolling(handler, intervalMs = 1000) {
  onUpdate = handler
  if (running) return
  running = true
  const loop = async () => {
    if (!running) return
    try { await getUpdates() } catch (e) { /* silencioso: rede ociosa do Telegram */ }
    setTimeout(loop, intervalMs)
  }
  loop()
  console.log('[telegram] long-polling ativo (dev)')
  return { stop: () => { running = false } }
}

/** Envia uma mensagem para um chat. */
async function send(chatId, text, opts = {}) {
  const body = { chat_id: chatId, text, parse_mode: opts.parseMode || 'HTML' }
  if (opts.buttons && opts.buttons.length) {
    body.reply_markup = { inline_keyboard: [opts.buttons.map((b) => (b.url ? { text: b.text, url: b.url } : { text: b.text, callback_data: b.callback_data || b.text }))] }
  }
  // converte blocos de marcação ```...``` em <pre> (HTML do Telegram) para a tabela renderizar
  if (body.parse_mode === 'HTML' && body.text.includes('```')) {
    const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    let out = ''
    const parts = String(body.text).split('```')
    for (let i = 0; i < parts.length; i++) {
      if (i % 2 === 1) out += '<pre>' + esc(parts[i]) + '</pre>'
      else out += parts[i] ? esc(parts[i]) : ''
    }
    body.text = out
  }
  return tgReq('sendMessage', body)
}

/** Descarrega um ficheiro do Telegram (file_id → file_path → bytes). */
async function downloadFile(fileId, destPath) {
  const token = process.env.TELEGRAM_BOT_TOKEN
  if (!token) throw new Error('TELEGRAM_BOT_TOKEN não configurado')
  const info = await tgReq('getFile', { file_id: fileId })
  if (!info.ok || !info.result || !info.result.file_path) throw new Error('telegram_getfile_falhou')
  const filePath = `${info.result.file_path}`.replace(/^\/+/, '')
  return new Promise((resolve, reject) => {
    const req = https.get({ hostname: 'api.telegram.org', path: `/file/bot${token}/${filePath}` }, (res) => {
      if (res.statusCode !== 200) { res.resume(); return reject(new Error('telegram_download_falhou')) }
      const out = fs.createWriteStream(destPath)
      res.pipe(out)
      out.on('finish', () => { out.close(); resolve(destPath) })
      out.on('error', reject)
    })
    req.on('error', reject)
    req.setTimeout(20000, () => { req.destroy(new Error('telegram_download_timeout')) })
  })
}

async function answerCallback(callbackId, text) {
  return tgReq('answerCallbackQuery', { callback_query_id: callbackId, text: text || '' })
}

// ---------- webhook (produção) ----------
async function handleWebhook(rawUpdate) {
  const n = normalizeUpdate(rawUpdate)
  if (!n) return { ok: true, ignored: true }
  await onUpdate(n)
  return { ok: true }
}

/** Valida secret do webhook (se configurado). */
function webhookSecretOk(req) {
  const secret = process.env.TELEGRAM_WEBHOOK_SECRET
  if (!secret) return true
  return (req.headers['x-telegram-bot-api-secret-token'] || '') === secret
}

module.exports = { send, startPolling, handleWebhook, webhookSecretOk, answerCallback, tgReq, downloadFile }