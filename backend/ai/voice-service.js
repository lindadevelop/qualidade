// voice-service.js — Camada de voz (Speech-to-Text local + TTS opcional).
// - STT: faster-whisper (local, CPU), modelo carregado UMA vez e reutilizado.
// - Conversão de áudio: FFmpeg (wav 16 kHz mono) com sanitização de ficheiros.
// - TTS: interface preparada (piper/offline) mas DESATIVADO por defeito.
// Segurança: nomes temporários aleatórios, limites de tamanho/duração, eliminação
// após processamento; nunca constroem comandos shell com input do utilizador.
const fs = require('fs')
const os = require('os')
const path = require('path')
const crypto = require('crypto')
const { execFile } = require('child_process')
const { promisify } = require('util')
const exec = promisify(execFile)

// ---------------- configuração ----------------
const ENABLED = (process.env.VOICE_ENABLED || process.env.WHISPER_ENABLED || '').toLowerCase() === 'true'
const STT_MODEL = process.env.STT_MODEL || 'small'
const STT_LANGUAGE = process.env.STT_LANGUAGE || 'pt'
const STT_DEVICE = process.env.STT_DEVICE || 'cpu'
const STT_COMPUTE_TYPE = process.env.STT_COMPUTE_TYPE || 'int8_float32'
const MAX_DURATION_S = Number(process.env.VOICE_MAX_DURATION_SECONDS || 300)
const MAX_FILE_MB = Number(process.env.VOICE_MAX_FILE_MB || 20)
const DELETE_AFTER = (process.env.VOICE_DELETE_AFTER_PROCESSING || 'true').toLowerCase() !== 'false'
const SHOW_TRANSCRIPTION = (process.env.VOICE_SHOW_TRANSCRIPTION || 'true').toLowerCase() === 'true'
const TMP_DIR = path.join(os.tmpdir(), 'samsys-voice')

// ---------------- STT: daemon faster-whisper (modelo carregado UMA vez) ----------------
const { spawn } = require('child_process')
const PYTHON = process.env.VOICE_PYTHON || 'python'
let daemon = null
let daemonQueue = []

function ensureDaemon() {
  if (!ENABLED) return null
  if (daemon && !daemon.killed) return daemon
  const daemonPath = require('path').join(__dirname, 'whisper-daemon.py')
  daemon = spawn(PYTHON, ['-u', daemonPath], {
    env: {
      ...process.env,
      STT_MODEL, STT_LANGUAGE, STT_DEVICE, STT_COMPUTE_TYPE,
    },
    cwd: __dirname,
  })
  daemon.stderr.on('data', (d) => {
    const s = String(d).trim(); if (s) console.log('[whisper]', s)
  })
  daemon.on('exit', () => { daemon = null })
  // dispatcher: recebe respostas JSON por linha e resolve em FIFO
  let buf = ''
  daemon.stdout.on('data', (chunk) => {
    buf += chunk.toString()
    let idx
    while ((idx = buf.indexOf('\n')) >= 0) {
      const line = buf.slice(0, idx); buf = buf.slice(idx + 1)
      const job = daemonQueue.shift()
      if (!job) continue
      try {
        const parsed = JSON.parse(line)
        parsed.ok ? job.resolve({ ok: true, text: parsed.text }) : job.reject(new Error(parsed.error || 'stt_erro'))
      } catch (e) { job.reject(new Error('stt_resposta_invalida')) }
    }
  })
  daemon.on('error', (e) => {
    for (const j of daemonQueue) j.reject(new Error('stt_proc_erro: ' + e.message))
    daemonQueue = []; daemon = null
  })
  return daemon
}

function sttPython(path) {
  return new Promise((resolve, reject) => {
    const d = ensureDaemon()
    if (!d) return reject(new Error('voz_desativada'))
    daemonQueue.push({ resolve, reject })
    try { d.stdin.write(JSON.stringify({ path }) + '\n') } catch (e) { daemonQueue.pop(); reject(new Error('stt_stdin_erro')) }
  })
}

/**
 * Pré-aquece a camada de voz no arranque do servidor: inicia o daemon e obriga o
 * Whisper a carregar o modelo para que o 1º pedido não demore (download do modelo
 * e carregamento em CPU podem exceder o timeout do long-polling do Telegram).
 */
function warmup() {
  if (!ENABLED) return
  try {
    const d = ensureDaemon()
    if (d) d.stdin.write(JSON.stringify({ path: '__warmup__' }) + '\n')
    console.log('[voice] pré-aquecido (daemon Whisper iniciado)')
  } catch (e) { console.error('[voice] warmup erro:', e.message) }
}

// ---------------- helpers de ficheiro (seguros) ----------------
function tmpPath(ext) {
  if (!fs.existsSync(TMP_DIR)) fs.mkdirSync(TMP_DIR, { recursive: true })
  return path.join(TMP_DIR, `${crypto.randomBytes(8).toString('hex')}.${ext || 'bin'}`)
}
function cleanup(...paths) {
  for (const p of paths) if (p) fs.promises.unlink(p).catch(() => {})
}

/** Usa a duração do ficheiro (ffprobe) para limites; devolve {seconds} ou null. */
function probeDuration(file) {
  return new Promise((resolve) => {
    exec('ffprobe', ['-v', 'quiet', '-show_entries', 'format=duration', '-of', 'csv=p=0', file])
      .then(({ stdout }) => resolve(parseFloat(String(stdout).trim())))
      .catch(() => resolve(null))
  })
}

/** Converte áudio para wav 16 kHz mono via FFmpeg (sem shell: execFile). */
async function toWav(input) {
  const out = tmpPath('wav')
  try {
    await exec('ffmpeg', ['-y', '-i', input, '-ar', '16000', '-ac', '1', '-f', 'wav', out])
    return out
  } catch (e) {
    cleanup(out)
    throw new Error('conversao_audio_falhou')
  }
}

/** Valida tamanho (bytes) e duração antes de transcrever. */
async function validateAudio(input) {
  const st = await fs.promises.stat(input).catch(() => null)
  if (!st) throw new Error('ficheiro_audio_invalido')
  if (st.size > MAX_FILE_MB * 1024 * 1024) throw new Error(`audio_demasiado_grande (máx ${MAX_FILE_MB} MB)`)
  const dur = await probeDuration(input)
  if (dur !== null && dur > MAX_DURATION_S) throw new Error(`audio_demasiado_longo (máx ${Math.round(MAX_DURATION_S / 60)} min)`)
  return { size: st.size, duration_s: dur }
}

// ---------------- API principal ----------------
/**
 * Transcreve um ficheiro de áudio local.
 * @param {string} inputPath  ficheiro (ogg/opus/mp3/m4a/wav/webm)
 * @param {object} [opts] {showTranscription}  devolve texto + metadados
 */
async function transcribe(inputPath, opts = {}) {
  if (!ENABLED) throw new Error('voz_desativada')
  if (!fs.existsSync(inputPath)) throw new Error('ficheiro_audio_invalido')
  const meta = await validateAudio(inputPath)
  const wav = inputPath.toLowerCase().endsWith('.wav') ? inputPath : await toWav(inputPath)
  let out
  try {
    out = await sttPython(wav)
  } finally {
    if (wav !== inputPath) cleanup(wav)
    if (DELETE_AFTER) cleanup(inputPath)
  }
  const text = (out.text || '').trim()
  if (!text) throw new Error('transcricao_vazia')
  return { text, engine: `faster-whisper/${STT_MODEL}`, ...meta, show_transcription: opts.showTranscription ?? SHOW_TRANSCRIPTION }
}

// ---------------- TTS (opcional, desativado por defeito) ----------------
const TTS_ENABLED = (process.env.TTS_ENABLED || 'false').toLowerCase() === 'true'
const TTS_REPLY_MODE = process.env.TTS_REPLY_MODE || 'text' // text | audio | both

/** Interface TTSService.synthesize(text) — motor trocável no futuro (piper). */
async function synthesize(text) {
  if (!TTS_ENABLED || !text) return null
  // Placeholder: preparado mas não obrigatório; quando ativo e sem motor configurado, devolve null
  return null
}

module.exports = { transcribe, synthesize, ENABLED, TTS_ENABLED, TTS_REPLY_MODE, validateAudio, toWav, tmpPath, warmup }