require('dotenv').config();
require('dotenv').config({path:require('node:path').join(__dirname,'.env'),quiet:true});
const {startBackups}=require('./quality-backup');
const {createQualityBaseline}=require('./quality-baseline');
const {createStrategyAdministration}=require('./strategy-administration');
const {startQualityWorker}=require('./quality-outbox');
const {createDataMaintenance}=require('./data-maintenance');
const {hashPassword,verifyStoredPassword,createUserAdministration}=require('./user-administration');
// auth-server.js — auth local compatível com Supabase GoTrue (subconjunto usado pela app)
// Endpoints: /auth/v1/token?grant_type=password|refresh_token, /auth/v1/user,
// /auth/v1/logout, /auth/v1/recover, /auth/v1/updateuser (password)
// Liga diretamente ao PostgreSQL local. Só para desenvolvimento local.
const http = require('http');
const crypto = require('crypto');
const { Pool } = require('pg');

const DB = {
  host: '127.0.0.1', port: 5432, user: 'postgres',
  password: process.env.PGPASSWORD, database: 'samsys_qualidade',
};
const JWT_SECRET = process.env.JWT_SECRET;
const PORT = Number(process.env.AUTH_PORT || 3002);
const SITE_URL = 'http://localhost:5178';
const MAX_AGE = 60 * 60 * 24 * 7; // 7 dias

const pool = new Pool(process.env.QUALITY_DATABASE_URL ? {connectionString:process.env.QUALITY_DATABASE_URL} : DB);

// ---------- JWT HS256 ----------
function b64url(buf) { return Buffer.from(buf).toString('base64url'); }
function signJwt(payload) {
  const header = b64url(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const body = b64url(JSON.stringify(payload));
  const sig = crypto.createHmac('sha256', JWT_SECRET).update(`${header}.${body}`).digest();
  return `${header}.${body}.${b64url(sig)}`;
}
function verifyJwt(token) {
  try {
    const [h, b, s] = token.split('.');
    const expected = crypto.createHmac('sha256', JWT_SECRET).update(`${h}.${b}`).digest();
    if (!crypto.timingSafeEqual(expected, Buffer.from(s, 'base64url'))) return null;
    const claims=JSON.parse(Buffer.from(b, 'base64url').toString());
    return Number.isFinite(claims.exp)&&claims.exp>Math.floor(Date.now()/1000)?claims:null;
  } catch { return null; }
}

// ---------- password demo (espelha migration 0008) ----------
function demoHash(id, password) {
  return 'sq$' + crypto.createHash('sha256').update((password || '') + id).digest('hex');
}
function verifyPassword(row, password) {
  // hash demo: 'sq$' + sha256(password + id)
  return verifyStoredPassword(row,password);
}

// ---------- helpers ----------
function send(res, code, obj) {
  res.writeHead(code, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, apikey, x-organization-id, content-type', 'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS' });
  res.end(JSON.stringify(obj));
}
function readBody(req) {
  return new Promise((resolve,reject) => {
    let data='',size=0,failed=false;
    req.on('data',c=>{size+=c.length;if(size>15*1024*1024){if(!failed)reject(Object.assign(new Error('Pedido demasiado grande.'),{status:413}));failed=true;return}if(!failed)data+=c});
    req.on('end',()=>{if(failed)return;try{resolve(JSON.parse(data||'{}'))}catch{reject(Object.assign(new Error('JSON inválido.'),{status:400}))}});
    req.on('error',reject);
  });
}

function makeSession(user, expiresIn = 3600) {
  const now = Math.floor(Date.now() / 1000);
  const access = signJwt({
    iss: 'supabase', ref: 'local', role: 'authenticated',
    sub: user.id, email: user.email, sv:user.session_version||0,
    iat: now, exp: now + expiresIn, aud: 'authenticated',
  });
  const refresh = signJwt({
    iss: 'supabase', ref: 'local', role: 'authenticated',
    sub: user.id, sv:user.session_version||0, type: 'refresh_token', iat: now, exp: now + MAX_AGE, aud: 'authenticated',
  });
  return {
    access_token: access, token_type: 'bearer', expires_in: expiresIn,
    refresh_token: refresh, user: {
      id: user.id, aud: 'authenticated', role: 'authenticated',
      email: user.email, email_confirmed_at: new Date().toISOString(),
      phone: '', confirmed_at: new Date().toISOString(),
      user_metadata: { full_name: user.full_name },
      app_metadata: { provider: 'email', providers: ['email'] },
      created_at: user.created_at || new Date().toISOString(),
      updated_at: new Date().toISOString(),
    },
  };
}

const {createPasswordRecovery}=require('./password-recovery');
const passwordRecovery=createPasswordRecovery({pool,readBody,send});
const userAdministration=createUserAdministration({pool,verifyJwt,readBody,send});
const dataMaintenance=createDataMaintenance({pool,verifyJwt,readBody,send});
const qualityBaseline=createQualityBaseline({pool,verifyJwt,readBody,send});
const strategyAdministration=createStrategyAdministration({pool,verifyJwt,readBody,send});
startQualityWorker(pool);
if(!process.env.QUALITY_DATABASE_URL)startBackups(DB);
const server = http.createServer(async (req, res) => {
  if (req.method === 'OPTIONS') { send(res, 200, {}); return; }
  const url = new URL(req.url, `http://${req.headers.host}`);
  const path = url.pathname;
  const authHeader = req.headers.authorization || '';

  try {
    if(await passwordRecovery(req,res,path))return;
    if(await qualityBaseline(req,res,path))return;
    if(await dataMaintenance(req,res,path))return;
    if(await userAdministration(req,res,path))return;
    if(await strategyAdministration(req,res,path))return;
    // ---------- POST /auth/v1/token (password / refresh) ----------
    if (path === '/auth/v1/token' && req.method === 'POST') {
      const g = url.searchParams.get('grant_type');
      const body = await readBody(req);
      if (g === 'password') {
        const data = await pool.query(
          'select u.id, u.email, u.password_hash, p.full_name, p.role, p.active, p.organization_id, p.module_access, p.is_super_admin, p.session_version, u.created_at from auth.users u left join public.profiles p on p.id = u.id where lower(u.email) = lower($1)',
          [body.email]
        );
        if (!data.rows.length || !data.rows[0].active || !verifyPassword(data.rows[0], body.password)) {
          return send(res, 400, { error: 'invalid_grant', error_description: 'Credenciais inválidas', code: 400 });
        }
        await pool.query('update profiles set account_used=true where id=$1',[data.rows[0].id]);
        return send(res, 200, makeSession(data.rows[0]));
      }
      if (g === 'refresh_token') {
        const claims = verifyJwt(body.refresh_token || '');
        if (!claims || claims.type !== 'refresh_token') {
          return send(res, 400, { error: 'invalid_grant', error_description: 'Refresh token inválido ou expirado', code: 400 });
        }
        const data = await pool.query(
          'select u.id, u.email, p.full_name, p.role, p.active, p.organization_id, p.module_access, p.is_super_admin, p.session_version, u.created_at from auth.users u left join public.profiles p on p.id = u.id where u.id = $1',
          [claims.sub]
        );
        if (!data.rows.length || !data.rows[0].active || data.rows[0].session_version!==(claims.sv??0)) return send(res, 400, { error: 'invalid_grant', error_description: 'Utilizador não encontrado', code: 400 });
        return send(res, 200, makeSession(data.rows[0]));
      }
      return send(res, 400, { error: 'unsupported_grant_type', code: 400 });
    }

    // ---------- GET /auth/v1/settings (handshake do supabase-js) ----------
    if (path === '/auth/v1/settings' && req.method === 'GET') {
      return send(res, 200, {
        external: { language: 'pt', supported_languages: ['pt', 'en'], url: SITE_URL, apikey: 'local' },
        disable_signup: true, mailer_autoconfirm: true, phone_autoconfirm: true,
        sms_provider: '', allow_undocumented_flows: false,
      });
    }

    // ---------- GET /auth/v1/user ----------
    if (path === '/auth/v1/user' && req.method === 'GET') {
      const token = (authHeader.match(/^Bearer (.+)$/) || [])[1];
      const claims = verifyJwt(token || '');
      if (!claims || claims.type==='refresh_token') return send(res, 401, { error: 'invalid_jwt', msg: 'Token inválido ou expirado', code: 401 });
      const data = await pool.query(
        'select u.id, u.email, p.full_name, p.role, p.active, p.organization_id, p.module_access, p.is_super_admin, p.session_version, u.created_at from auth.users u left join public.profiles p on p.id = u.id where u.id = $1',
        [claims.sub]
      );
      if (!data.rows.length || !data.rows[0].active || data.rows[0].session_version!==(claims.sv??0)) return send(res, 401, { error: 'invalid_jwt', msg: 'Utilizador não encontrado', code: 401 });
      const u = data.rows[0];
      return send(res, 200, {
        id: u.id, aud: 'authenticated', role: 'authenticated', email: u.email,
        email_confirmed_at: new Date().toISOString(), phone: '', confirmed_at: new Date().toISOString(),
        user_metadata: { full_name: u.full_name }, app_metadata: { provider: 'email', providers: ['email'], profile_role:u.role, is_super_admin:u.is_super_admin, organization_id:u.organization_id, module_access:u.module_access },
        created_at: u.created_at, updated_at: new Date().toISOString(),
      });
    }

    // ---------- POST /auth/v1/logout ----------
    if (path === '/auth/v1/logout' && req.method === 'POST') {
      return send(res, 204, {});
    }

    // ---------- PUT /auth/v1/user (alterar password) ----------
    if (path === '/auth/v1/user' && req.method === 'PUT') {
      const token = (authHeader.match(/^Bearer (.+)$/) || [])[1];
      const claims = verifyJwt(token || '');
      if (!claims || claims.type==='refresh_token') return send(res, 401, { error: 'invalid_jwt', msg: 'Token inválido', code: 401 });
      const body = await readBody(req);
      if (body.password) {
        const valid=(await pool.query('select active,session_version from profiles where id=$1',[claims.sub])).rows[0];
        if(!valid?.active||valid.session_version!==(claims.sv??0))return send(res,401,{msg:'Sessão inválida.'});
        let hash;try{hash=hashPassword(body.password)}catch(e){return send(res,400,{msg:e.message})}
        const client=await pool.connect();try{await client.query('BEGIN');await client.query('update auth.users set password_hash=$1 where id=$2',[hash,claims.sub]);await client.query('update profiles set session_version=session_version+1 where id=$1',[claims.sub]);await client.query('COMMIT')}catch(e){await client.query('ROLLBACK');throw e}finally{client.release()}
      }
      return send(res, 200, { id: claims.sub, email: claims.email });
    }

    return send(res, 404, { error: 'not_found', msg: 'rota não encontrada', code: 404 });
  } catch (e) {
    console.error('[auth] erro:', e.message);
    return send(res, 500, { error: 'server_error', msg: 'Erro interno', code: 500 });
  }
});

server.listen(PORT, '127.0.0.1', () => console.log(`[auth] GoTrue-compatível a ouvir em http://127.0.0.1:${PORT}`));
