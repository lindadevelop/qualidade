require('dotenv').config();
// channel-token.js — Gera um access token (JWT) para um utilizador interno do programa,
// com o MESMO formato/segredo do auth-server, para que as ferramentas MCP respeitem o RLS
// (o PostgREST interpreta o JWT -> role authenticated + sub = user id).
// Serviço usado apenas pelo backend de canais — nunca exposto ao LLM ou ao cliente.
const crypto = require('crypto')
const { Pool } = require('pg')

const JWT_SECRET = process.env.JWT_SECRET || process.env.JWT_SECRET
const TOKEN_TTL = Number(process.env.CHANNEL_TOKEN_TTL || 3600) // 1h

const POOL = new Pool({
  host: '127.0.0.1', port: 5432, user: 'postgres',
  password: process.env.PGPASSWORD_DB || process.env.PGPASSWORD, database: 'samsys_qualidade',
})

function b64url(buf) { return Buffer.from(buf).toString('base64url') }
function signJwt(payload) {
  const header = b64url(JSON.stringify({ alg: 'HS256', typ: 'JWT' }))
  const body = b64url(JSON.stringify(payload))
  const sig = crypto.createHmac('sha256', JWT_SECRET).update(`${header}.${body}`).digest()
  return `${header}.${body}.${b64url(sig)}`
}

/**
 * Devolve um access token para `userId` (faz refetch do email/profile para encher claims).
 * Se o utilizador não existir/estiver inativo, devolve null.
 */
async function getServiceTokenFor(userId) {
  try {
    const { rows } = await POOL.query(
      `select u.id, u.email from auth.users u where u.id=$1 and exists(select 1 from public.profiles p where p.id=u.id)`,
      [userId],
    )
    const user = rows[0]
    if (!user) return null
    const now = Math.floor(Date.now() / 1000)
    return signJwt({
      iss: 'supabase', ref: 'local', role: 'authenticated',
      sub: user.id, email: user.email, iat: now, exp: now + TOKEN_TTL, aud: 'authenticated',
    })
  } catch (e) {
    console.error('[channel-token] erro:', e.message)
    return null
  }
}

module.exports = { getServiceTokenFor }