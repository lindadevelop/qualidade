const {identity,claimFile,canReadFile}=require('./file-access');
// storage-server.js — serviço de ficheiros (papel do Storage do Supabase)
// Porta 3003. Guarda ficheiros em ./data/uploads com nome seguro e serve-os.
// Rotas:
//   POST /storage/v1/object/cv           -> { path, size }  (multipart não exigido: raw body)
//   GET  /storage/v1/object/<path>       -> serve o ficheiro
//   GET  /storage/v1/object/signed/<path>?expires=3600 -> URL temporária (simples)
const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const PORT = 3003;
const UPLOAD_DIR = path.join(__dirname, 'data', 'uploads');
const MAX_SIZE = 15 * 1024 * 1024; // 15 MB
fs.mkdirSync(UPLOAD_DIR, { recursive: true });

const ALLOWED_EXT = ['.pdf'];

function safeName(name) {
  const base = path.basename(name || '').replace(/[^\w.\-]/g, '_');
  return base;
}

function detectMime(buf) {
  // assinatura real (magic bytes)
  if (buf.length >= 5 && buf[0] === 0x25 && buf[1] === 0x50 && buf[2] === 0x44 && buf[3] === 0x46 && buf[4] === 0x2d) return 'application/pdf';
  return null;
}

const server = http.createServer(async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'authorization, apikey, content-type');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  if (req.method === 'OPTIONS') { res.writeHead(204); res.end(); return; }

  const url = new URL(req.url, 'http://localhost');
  try {
    const user=await identity(req);
    if(!user){res.writeHead(401);res.end(JSON.stringify({error:'Sessão inválida.'}));return}
    if(user.app_metadata.profile_role!=='admin'&&!user.app_metadata.module_access?.lifecycle&&!user.app_metadata.module_access?.quality){res.writeHead(403);res.end();return}
    // ---- POST upload ----
    if (req.method === 'POST' && url.pathname.startsWith('/storage/v1/object/')) {
      const chunks = [];
      let size = 0;
      for await (const c of req) {
        size += c.length;
        if (size > MAX_SIZE) { res.writeHead(413, {'Content-Type':'application/json'}); res.end(JSON.stringify({error:'Ficheiro demasiado grande (máx. 15 MB).'})); return; }
        chunks.push(c);
      }
      const buf = Buffer.concat(chunks);
      const mime = detectMime(buf);
      if (mime !== 'application/pdf') { res.writeHead(415, {'Content-Type':'application/json'}); res.end(JSON.stringify({error:'Só são aceites PDFs reais.'})); return; }
      const hash = crypto.createHash('sha256').update(buf).digest('hex');
      const target = path.join(UPLOAD_DIR, hash + '.pdf');
      fs.writeFileSync(target, buf);
      await claimFile(hash+'.pdf',user);
      const p = '/storage/v1/object/' + hash + '.pdf';
      res.writeHead(200, {'Content-Type':'application/json'});
      res.end(JSON.stringify({ path: p, size: buf.length, hash, mime }));
      return;
    }

    // ---- GET serve ficheiro ----
    if (req.method === 'GET' && url.pathname.startsWith('/storage/v1/object/')) {
      const rest = url.pathname.replace('/storage/v1/object/', '');
      if (!rest || rest.includes('..')) { res.writeHead(404); res.end(); return; }
      if(!await canReadFile(rest,user,req.headers.authorization||'')){res.writeHead(403);res.end(JSON.stringify({error:'Sem acesso a este ficheiro.'}));return}
      const file = path.join(UPLOAD_DIR, path.basename(rest));
      if (!fs.existsSync(file)) { res.writeHead(404, {'Content-Type':'application/json'}); res.end(JSON.stringify({error:'Ficheiro não encontrado.'})); return; }
      const buf = fs.readFileSync(file);
      res.writeHead(200, { 'Content-Type': 'application/pdf', 'Content-Length': buf.length });
      res.end(buf);
      return;
    }

    res.writeHead(404); res.end(JSON.stringify({error:'not_found'}));
  } catch (e) {
    res.writeHead(500, {'Content-Type':'application/json'}); res.end(JSON.stringify({ error: e.message }));
  }
});

server.listen(PORT, () => console.log(`[storage] Storage a ouvir em :${PORT} (dir ${UPLOAD_DIR})`));