// api-proxy.js — proxy Supabase-compatível (papel do Kong)
// Roteia: /auth/v1/* -> auth-server (3002) | /rest/v1/* -> PostgREST (3001) | /storage/v1/* -> (placeholder)
// O supabase-js com VITE_SUPABASE_URL=http://localhost:8000 usa /auth/v1 + /rest/v1 automaticamente.
const http = require('http');

const TARGETS = {
  '/auth/v1/': 'http://127.0.0.1:3002',
  '/rest/v1/': 'http://127.0.0.1:3001',
  '/storage/v1/': 'http://127.0.0.1:3003',
  '/ai/': 'http://127.0.0.1:3004',
  '/channels/': 'http://127.0.0.1:3005',
  '/mcp/': 'http://127.0.0.1:3005',
  '/cv/': 'http://127.0.0.1:3006',
  '/ppt/': 'http://127.0.0.1:3007',
};
const PORT = 8000;

const server = http.createServer(async (req, res) => {
  // CORS (como o Supabase)
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'authorization, apikey, x-organization-id, x-client-info, x-supabase-api-version, content-type, accept, accept-profile, content-profile, prefer, range, x-hub-signature-256, x-telegram-bot-api-secret-token, x-teams-token');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS, HEAD');
  res.setHeader('Access-Control-Expose-Headers', 'Content-Range, Range');

  if (req.method === 'OPTIONS') { res.writeHead(204); res.end(); return; }

  // Validate current session for API calls; module grants are read on every request.
  const requestPath = new URL(req.url,'http://localhost').pathname;
  const module = requestPath.startsWith('/cv/') ? 'lifecycle' : requestPath.startsWith('/ppt/') ? 'strategy' : requestPath.startsWith('/ai/') ? 'quality' : null;
  if ((module && !requestPath.endsWith('/health')) || requestPath.startsWith('/rest/v1/')) {
    try {
      const response = await fetch('http://127.0.0.1:3002/auth/v1/user', {headers:{Authorization:req.headers.authorization||''},signal:AbortSignal.timeout(5000)});
      if(!response.ok){res.writeHead(401,{'Content-Type':'application/json'});res.end(JSON.stringify({message:'Sessão inválida. Inicia sessão novamente.'}));return}
      const user=await response.json(), access=user.app_metadata;
      if(module && access?.profile_role!=='admin' && access?.module_access?.[module]!==true){res.writeHead(403,{'Content-Type':'application/json'});res.end(JSON.stringify({message:'Sem acesso a este módulo.'}));return}
    }catch{res.writeHead(503,{'Content-Type':'application/json'});res.end(JSON.stringify({message:'Não foi possível validar a sessão.'}));return}
  }

  // escolher destino por prefixo; reescrever path apenas para o PostgREST (o auth/storage esperam o prefixo)
  console.log(`[proxy] ${req.method} ${req.url} (origin: ${req.headers.origin || 'none'})`);
  let target = null, path = req.url;
  for (const [prefix, t] of Object.entries(TARGETS)) {
    if (req.url.startsWith(prefix)) {
      target = t;
      if (t === 'http://127.0.0.1:3001') {
        // PostgREST: remove o prefixo /rest/v1 e mantém query string
        const rest = req.url.slice(prefix.length);
        path = rest.startsWith('/') ? rest : '/' + rest;
      }
      // auth (/auth/v1) e storage (/storage/v1): preserva o path original
      break;
    }
  }
  if (!target) { res.writeHead(404, { 'Content-Type': 'application/json' }); res.end(JSON.stringify({ code: 'not_found' })); return; }

  // encaminhar pedido (path reescrito para o serviço-alvo)
  const dest = new URL(target);
  const options = {
    hostname: dest.hostname, port: dest.port, method: req.method,
    path, headers: { ...req.headers, host: dest.host },
  };
  const proxy = http.request(options, (pres) => {
    res.writeHead(pres.statusCode, pres.headers);
    pres.pipe(res);
  });
  proxy.on('error', (e) => { res.writeHead(502, { 'Content-Type': 'application/json' }); res.end(JSON.stringify({ code: 'bad_gateway', msg: e.message })); });
  req.pipe(proxy);
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`[api-proxy] Supabase-compatível a ouvir em http://127.0.0.1:${PORT}`);
  console.log('  /auth/v1  -> GoTrue local (3002)');
  console.log('  /rest/v1  -> PostgREST (3001)');
  console.log('  /storage/v1 -> storage (3003)');
});