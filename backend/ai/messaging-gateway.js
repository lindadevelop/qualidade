require('dotenv').config();
// messaging-gateway.js — Abstração comum dos canais (Telegram/WhatsApp/Web).
// Converte eventos externos em IncomingMessage e respostas internas no formato do canal.
// A lógica de negócio/agente vive fora dos adapters (§12).
const { handleMessage } = require('./agent-orchestrator')
const { Pool } = require('pg')

const POOL = new Pool({
  host: '127.0.0.1', port: 5432, user: 'postgres',
  password: process.env.PGPASSWORD_DB || process.env.PGPASSWORD, database: 'samsys_qualidade',
})

/** Formato interno normalizado de uma mensagem recebida de um canal. */
class IncomingMessage {
  constructor({ channel, externalUserId, externalChatId, messageId, type = 'text', text, mediaRef, timestamp }) {
    this.channel = channel
    this.externalUserId = externalUserId
    this.externalChatId = externalChatId
    this.messageId = messageId
    this.type = type            // text | voice | callback
    this.text = text
    this.mediaRef = mediaRef
    this.timestamp = timestamp || new Date().toISOString()
  }
}

/** Formato interno de resposta a enviar a um canal. */
class OutgoingMessage {
  constructor({ text, buttons = [], parseMode = 'HTML' }) {
    this.text = text
    this.buttons = buttons      // [{text, callback_data|url}]
    this.parseMode = parseMode
  }
}

/* ------------------------------------------------ identidade(s) ------------------------------------------------ */

/** Procura a identidade do canal e devolve o user_id interno (ou null). */
async function findIdentity(channel, externalUserId) {
  const { rows } = await POOL.query(
    `select id, user_id from public.external_ai_identities
     where channel=$1 and external_user_id=$2 and is_active=true and revoked_at is null limit 1`,
    [channel, String(externalUserId)],
  )
  return rows[0] || null
}

/** Regista/atualiza "last seen" de uma identidade (chamado após interação autenticada). */
async function touchIdentity(id) {
  await POOL.query(`update public.external_ai_identities set last_seen_at=now() where id=$1`, [id]).catch(() => {})
}

/** Auditoria básica de interações de canais (sem guardar secrets/binário). */
async function logInteraction(entry) {
  try {
    await POOL.query(
      `insert into ai_action_logs (user_id, channel, tool_name, result_status)
       values ($1,$2,$3,$4)`,
      [entry.user_id || null, entry.channel || null, entry.tool_name || 'message', entry.result_status || 'ok'],
    )
  } catch { /* logs não críticos */ }
}

/**
 * Orquestra uma mensagem de um canal:
 *  - resolve identidade -> user interno
 *  - chama o agente (MCP tools, RLS)
 *  - regista auditoria
 * Retorna {userId, reply: OutgoingMessage}.
 */
async function processIncoming(message /* IncomingMessage */) {
  const identity = await findIdentity(message.channel, message.externalUserId)
  if (!identity) {
    return {
      userId: null,
      reply: new OutgoingMessage({
        text: 'O teu canal ainda não está ligado a uma conta do Programa de Ocorrências.\nGera um código na aplicação (Área » IA e Canais » Associar) e envia:\n/link <código>',
      }),
    }
  }
  let token
  try {
    // obter token do utilizador para o RLS (via auth-server local)
    const { getServiceTokenFor } = require('./channel-token')
    token = await getServiceTokenFor(identity.user_id)
  } catch (e) {
    return { userId: identity.user_id, reply: new OutgoingMessage({ text: 'Não consegui iniciar sessão no programa. Tenta novamente.' }) }
  }
  if (!token) return { userId: identity.user_id, reply: new OutgoingMessage({ text: 'Não consegui autenticar o teu utilizador. Contacta o administrador.' }) }

  // mensagens de voz -> STT local (Whisper) -> mesmo fluxo MCP do texto
  if (message.type === 'voice' && message.mediaRef) {
    const voice = require('./voice-service')
    if (!voice.ENABLED) {
      return { userId: identity.user_id, reply: new OutgoingMessage({ text: 'A função de voz está desativada neste momento. Envia por texto, por favor.' }) }
    }
    const tmp = voice.tmpPath('audio')
    const adapter = message.channel === 'slack'
      ? require('./slack-adapter')
      : message.channel === 'telegram' ? require('./telegram-adapter') : null
    if (!adapter) {
      return { userId: identity.user_id, reply: new OutgoingMessage({ text: 'Voz ainda não disponível neste canal. Envia por texto, por favor.' }) }
    }
    try {
      // nome do utilizador (para saudações/card)
      const nome = await nomeUtilizador(identity.user_id)
      await adapter.downloadFile(message.mediaRef, tmp)
      const tr = await voice.transcribe(tmp)
      const transcript = tr.text
      // pré-visualização da transcrição (configurável)
      const prefix = tr.show_transcription ? `🎙️ Reconhecido: "${transcript}"\n\n` : ''
      const r = await handleMessage(transcript, { token, userId: identity.user_id, history: [], userName: nome })
      await logInteraction({ user_id: identity.user_id, channel: message.channel, tool_name: (r.tools && r.tools[0] && r.tools[0].tool) || 'voice', result_status: r.type === 'error' ? 'error' : 'ok' })
      return { userId: identity.user_id, reply: new OutgoingMessage({ text: prefix + r.answer, parseMode: r.parseMode || 'HTML' }) }
    } catch (e) {
      console.error(`[voice] erro (${message.channel}):`, e.message || e)
      const msg = String(e.message || '')
      if (msg.includes('voz_desativada')) return { userId: identity.user_id, reply: new OutgoingMessage({ text: 'A função de voz está desativada.' }) }
      if (msg.includes('grande') || msg.includes('longo') || msg.includes('inválido') || msg.includes('falhou') || msg.includes('vazia'))
        return { userId: identity.user_id, reply: new OutgoingMessage({ text: 'Não consegui processar essa mensagem de voz. Tenta de novo com um áudio curto e claro.' }) }
      return { userId: identity.user_id, reply: new OutgoingMessage({ text: 'Não consegui processar a mensagem de voz. Tenta de novo.' }) }
    } finally {
      try { require('fs').unlinkSync(tmp) } catch { /* já removido */ }
    }
  }

  const r = await handleMessage(message.text, { token, userId: identity.user_id, history: [], userName: await nomeUtilizador(identity.user_id) })
  await logInteraction({ user_id: identity.user_id, channel: message.channel, tool_name: (r.tools && r.tools[0] && r.tools[0].tool) || null, result_status: r.type === 'error' ? 'error' : 'ok' })
  return { userId: identity.user_id, reply: new OutgoingMessage({ text: r.answer, parseMode: r.parseMode || 'HTML' }) }
}

/** Devolve o full_name do utilizador interno (para saudações/card). */
async function nomeUtilizador(userId) {
  if (!userId) return ''
  try {
    const { rows } = await POOL.query('select full_name from public.profiles where id=$1 limit 1', [userId])
    return (rows[0] && rows[0].full_name) || ''
  } catch { return '' }
}

module.exports = { IncomingMessage, OutgoingMessage, processIncoming, findIdentity, logInteraction }