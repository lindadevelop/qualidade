const {identity,canReadFile}=require('./file-access');
// cv-processor-server.js — processamento de CVs (upload -> texto)
// Porta 3006. Exposto pelo proxy em /cv/.
// Rotas:
//   POST /cv/extract  { document_path }  -> extrai texto (pymupdf) + OCR fallback
//   GET  /cv/health                      -> { ok, ocr_available }
const http = require('http');
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
try { require('dotenv').config(); } catch { /* dotenv opcional */ }

const PORT = 3006;
const UPLOAD_DIR = path.join(__dirname, 'data', 'uploads');
// ---- Fila de processamento assíncrono de CVs (Fila perspistente em BD) ----
// Config via env (nunca no frontend). Leituras seguras: usa token do request, RLS.
const QUEUE = {
  enabled: process.env.CV_QUEUE_ENABLED !== 'false',
  maxConcurrent: Number(process.env.CV_MAX_CONCURRENT_JOBS || 2),
  maxUploadFiles: Number(process.env.CV_MAX_UPLOAD_FILES || 10),
  maxFileSizeMb: Number(process.env.CV_MAX_FILE_SIZE_MB || 15),
  maxRetries: Number(process.env.CV_JOB_MAX_RETRIES || 2),
  jobTimeoutMs: Number(process.env.CV_JOB_TIMEOUT || 1200000),
  staleTimeoutMs: Number(process.env.CV_STALE_JOB_TIMEOUT || 3600000),
  pollIntervalMs: Number(process.env.CV_STATUS_POLL_INTERVAL || 3000),
  retentionDays: Number(process.env.CV_COMPLETED_RETENTION_DAYS || 7),
};
const REST_URL = process.env.SUPABASE_REST_URL || 'http://127.0.0.1:3001';
// REST com o token do utilizador -> RLS aplica-se (nunca acesso direto à BD)
function rest(token, path, { method = 'GET', body, prefer } = {}) {
  return new Promise((resolve, reject) => {
    const u = new URL(REST_URL);
    const req = require('http').request({
      hostname: u.hostname, port: u.port, path, method,
      headers: {
        'Content-Type': 'application/json',
        apikey: 'anon',
        ...(prefer ? { Prefer: 'return=representation' } : {}),
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
    }, (res) => {
      let data = '';
      res.on('data', (c) => (data += c));
      res.on('end', () => {
        let json = null;
        try { json = JSON.parse(data); } catch { /* texto */ }
        resolve({ status: res.statusCode, data: json ?? data });
      });
    });
    req.on('error', reject);
    if (body !== undefined) req.write(typeof body === 'string' ? body : JSON.stringify(body));
    req.end();
  });
}
const REST_BASE = (token) => ({
  createJob: (p) => rest(token, '/lifecycle_cv_jobs', { method: 'POST', body: p }),
  getJob: (id) => rest(token, `/lifecycle_cv_jobs?id=eq.${id}&select=*`, {}),
  updateJob: (id, patch) => rest(token, `/lifecycle_cv_jobs?id=eq.${id}`, { method: 'PATCH', body: { ...patch, updated_at: new Date().toISOString() } }),
  listJobs: () => rest(token, '/lifecycle_cv_jobs?select=*&order=created_at.desc&limit=200', {}),
});

// python que DEVE ter pymupdf: .env (PYTHON_BIN) → fallback explícito para o venv local → 'python' do PATH
const KNOWN_PY = 'C:\\Users\\carlo\\AppData\\Local\\hermes\\hermes-agent\\venv\\Scripts\\python.exe';
function hasPymupdf(py) {
  try {
    const { spawnSync } = require('child_process');
    const r = spawnSync(py, ['-c', 'import pymupdf'], { encoding: 'utf8', timeout: 20000 });
    return r.status === 0;
  } catch { return false; }
}
let PYTHON = process.env.PYTHON_BIN;
if (PYTHON && fs.existsSync(PYTHON) && hasPymupdf(PYTHON)) { /* ok */ }
else if (hasPymupdf(KNOWN_PY)) { PYTHON = KNOWN_PY; }
else { PYTHON = 'python'; }
console.log(`[cv] PYTHON_BIN -> ${PYTHON}`);
const DAEMON = path.join(__dirname, 'ai', 'cv-text-daemon.py');
const TESSERACT = process.env.TESSERACT_BIN || '';

// daemon persistente de extração (carrega pymupdf uma vez)
let daemon = null;
let queue = [];
function getDaemon() {
  if (daemon) return daemon;
  daemon = spawn(PYTHON, ['-u', DAEMON], {
    stdio: ['pipe', 'pipe', 'inherit'],
    env: { ...process.env, ...(process.env.TESSDATA_PREFIX ? { TESSDATA_PREFIX: process.env.TESSDATA_PREFIX } : {}), ...(TESSERACT ? { TESSERACT_BIN: TESSERACT } : {}) },
  });
  daemon.on('exit', () => { daemon = null; });
  daemon.stdout.on('data', (chunk) => {
    const lines = chunk.toString().split('\n').filter(Boolean);
    for (const l of lines) {
      const job = queue.shift();
      if (!job) continue;
      try { job.resolve(JSON.parse(l)); } catch (e) { job.resolve({ ok: false, error: 'resposta inválida' }); }
    }
  });
  return daemon;
}

function extractText(pdfPath) {
  return new Promise((resolve, reject) => {
    const d = getDaemon();
    const job = { resolve, reject };
    queue.push(job);
    d.stdin.write(JSON.stringify({ path: pdfPath, ocr: !!TESSERACT }) + '\n');
  });
}

function json(res, code, obj) {
  res.writeHead(code, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
  res.end(JSON.stringify(obj));
}

// valida que o ficheiro existe e é um PDF real (magic)
function validatePdf(p) {
  if (!fs.existsSync(p)) return 'Ficheiro não encontrado no armazenamento.';
  const fd = fs.openSync(p, 'r');
  const buf = Buffer.alloc(5);
  fs.readSync(fd, buf, 0, 5, 0);
  fs.closeSync(fd);
  if (buf[0] === 0x25 && buf[1] === 0x50 && buf[2] === 0x44 && buf[3] === 0x46 && buf[4] === 0x2d) return null;
  return 'O ficheiro não é um PDF válido.';
}

const server = http.createServer(async (req, res) => {
  if (req.method === 'OPTIONS') { res.writeHead(204, {'Access-Control-Allow-Origin':'*'}); res.end(); return; }
  const url = new URL(req.url, 'http://localhost');
  try {
    const caller=url.pathname==='/cv/health'?null:await identity(req);
    if(url.pathname!=='/cv/health'&&(!caller||(caller.app_metadata.profile_role!=='admin'&&!caller.app_metadata.module_access?.lifecycle))){json(res,403,{error:'Sessão ou módulo não autorizado.'});return}
    if (req.method === 'POST' && url.pathname === '/cv/extract') {
      let body = '';
      for await (const c of req) body += c;
      const { document_path } = JSON.parse(body || '{}');
      if (!document_path) { json(res, 400, { error: 'document_path em falta.' }); return; }
      // o storage guarda em data/uploads/<hash>.pdf; document_path pode ser /storage/v1/object/<hash>.pdf
      const fileUser=await identity(req);if(!fileUser||!await canReadFile(document_path,fileUser,req.headers.authorization||'')){json(res,403,{error:'Sem acesso a este ficheiro.'});return}
      const hash = path.basename(document_path);
      const full = path.join(UPLOAD_DIR, hash);
      const err = validatePdf(full);
      if (err) { json(res, 400, { error: err }); return; }
      const t0 = Date.now();
      const r = await extractText(full);
      json(res, 200, {
        document_path,
        hash: hash.replace('.pdf', ''),
        text: r.text || '',
        has_text: !!r.has_text,
        pages: r.pages || 0,
        ocr_used: !!r.ocr_used,
        duration_ms: Date.now() - t0,
        error: r.error || null,
      });
      return;
    }
    if (req.method === 'GET' && url.pathname === '/cv/health') {
      json(res, 200, { ok: true, ocr_available: !!(TESSERACT && fs.existsSync(TESSERACT)), tesseract_bin: TESSERACT || null });
      return;
    }
    // ---- Fase 3: análise do CV com o Ollama (JSON estruturado, ASSÍNCRONO) ----
    // POST /cv/analyze -> cria um job e devolve {job_id} de imediato (o Ollama
    // é lento: 3-10 min em CPU; nunca bloquear o pedido HTTP/frontend).
    if (req.method === 'POST' && url.pathname === '/cv/analyze') {
      let body = '';
      for await (const c of req) body += c;
      const { text, document_path } = JSON.parse(body || '{}');
      if (!text || !text.trim()) { json(res, 400, { error: 'Sem texto do CV para analisar (o PDF pode ser uma digitalização sem OCR).' }); return; }
      const job = { id: crypto.createHash('sha256').update(text.slice(0, 200) + '|' + Date.now()).digest('hex').slice(0, 16), state: 'pending', text, document_path, result: null, error: null, created_ms: Date.now() };
      job.owner_id=caller.id;
      JOBS.set(job.id, job);
      // processa em background (sem bloquear a resposta)
      runAnalyzeJob(job);
      json(res, 202, { job_id: job.id, state: 'pending', status_url: `/cv/job/${job.id}` });
      return;
    }
    // GET /cv/job/<id> -> estado do job (polling)
    const jobMatch = url.pathname.match(/^\/cv\/job\/([0-9a-f]{16})$/);
    if (req.method === 'GET' && jobMatch) {
      const j = JOBS.get(jobMatch[1]);
      if (!j || j.owner_id!==caller.id && !caller.app_metadata.is_super_admin) { json(res, 404, { error: 'Job não encontrado.' }); return; }
      if (j.state === 'done') {
        json(res, 200, { job_id: j.id, state: 'done', document_path: j.document_path || null, duration_ms: Date.now() - j.created_ms, model: OLLAMA.model, prompt_version: OLLAMA.cvPromptVersion, ...j.result });
      } else if (j.state === 'error') {
        json(res, 200, { job_id: j.id, state: 'error', error: j.error });
      } else {
        json(res, 200, { job_id: j.id, state: 'pending', elapsed_ms: Date.now() - j.created_ms });
      }
      return;
    }
    // ---- Fase 4: comparação explicável do CV com a vaga (ASSÍNCRONO) ----
    if (req.method === 'POST' && url.pathname === '/cv/match') {
      let body = '';
      for await (const c of req) body += c;
      const { text, analysis, vaga } = JSON.parse(body || '{}');
      if (!vaga || !vaga.titulo) { json(res, 400, { error: 'Dados da vaga em falta (titulo/requisitos).' }); return; }
      if (!text && !analysis) { json(res, 400, { error: 'Sem texto nem análise do CV.' }); return; }
      const job = { id: crypto.createHash('sha256').update((vaga.titulo || '') + '|' + (text || '').slice(0, 100) + '|' + Date.now()).digest('hex').slice(0, 16), state: 'pending', text, analysis, vaga, result: null, error: null, created_ms: Date.now() };
      job.owner_id=caller.id;
      JOBS.set(job.id, job);
      runMatchJob(job);
      json(res, 202, { job_id: job.id, state: 'pending', status_url: `/cv/job/${job.id}` });
      return;
    }
    // ---- Fila persistente de processamento de CVs ----
    if (QUEUE.enabled && url.pathname === '/cv/queue' && req.method === 'POST') { enqueueCv(req, res); return; }
    if (QUEUE.enabled && url.pathname === '/cv/queue' && req.method === 'GET') { listQueue(req, res); return; }
    const qMatch = url.pathname.match(/^\/cv\/queue\/([0-9a-f-]{36})$/);
    if (QUEUE.enabled && qMatch) {
      if (req.method === 'GET') { getQueueJob(req, res, qMatch[1]); return; }
      if (req.method === 'POST') {
        // ações: ?action=cancel|retry|view
        const action = url.searchParams.get('action');
        if (action === 'cancel') { cancelQueueJob(req, res, qMatch[1]); return; }
        if (action === 'retry') { retryQueueJob(req, res, qMatch[1]); return; }
        if (action === 'view') { viewQueueJob(req, res, qMatch[1]); return; }
        if (action === 'archive') { archiveQueueJob(req, res, qMatch[1]); return; }
        json(res, 400, { error: 'Ação desconhecida (cancel|retry|view|archive).' }); return;
      }
    }
    json(res, 404, { error: 'not_found' });
  } catch (e) {
    json(res, 500, { error: e.message });
  }
});

// ================= Fila de processamento assíncrono de CVs =================
// Ao contrário de /cv/analyze (jobs em memória), esta fila é PERSISTENTE em BD:
// sobrevive ao fecho do popup/página/navegador e a novas autenticações.
// O utilizador envia os PDFs -> a app chama /cv/queue (uma chamada por ficheiro,
// no mesmo upload) que cria um registo na BD e devolve 202 imediatamente.
let ativos = 0;                 // jobs a correr agora (limite = QUEUE.maxConcurrent)
const cancelFlags = new Map();  // job_id -> cancelamento pedido (na próxima etapa segura)

function authToken(req) {
  const a = req.headers.authorization || '';
  return a.startsWith('Bearer ') ? a.slice(7) : '';
}
function extractBearer(req) { return authToken(req) }

async function enqueueCv(req, res) {
  const token = extractBearer(req);
  if (!token) { json(res, 401, { error: 'Sem token de autenticação.' }); return; }
  let body = '';
  for await (const c of req) body += c;
  const { file_name, file_path, file_hash, file_size, file_mime, caso_id, vaga_id, empresa_id } = JSON.parse(body || '{}');
  if (!file_path) { json(res, 400, { error: 'file_path em falta.' }); return; }
  const fileUser=await identity(req);if(!fileUser||!await canReadFile(file_path,fileUser,req.headers.authorization||'')){json(res,403,{error:'Sem acesso a este ficheiro.'});return}
  const hash = path.basename(file_path);
  const full = path.join(UPLOAD_DIR, hash);
  const err = validatePdf(full);
  if (err) { json(res, 400, { error: err }); return; }
  // hash duplicado já em fila/processamento -> devolve o job existente (evita reenvio)
  if (file_hash || hash) {
    const r = await rest(token, `/lifecycle_cv_jobs?file_hash=eq.${encodeURIComponent(file_hash || hash.replace('.pdf',''))}&or=(status.eq.QUEUED,status.eq.UPLOADING,status.eq.EXTRACTING,status.eq.OCR,status.eq.ANALYZING,status.eq.VALIDATING,status.eq.DEDUPLICATING,status.eq.CREATING)&select=id&limit=1`, {});
    const arr = Array.isArray(r.data) ? r.data : [];
    if (arr.length) { json(res, 202, { job_id: arr[0].id, status: 'QUEUED', duplicado_envio: true }); return; }
  }
  const r = await rest(token, '/lifecycle_cv_jobs', { method: 'POST', body: {
    file_name: file_name || hash, file_path, file_hash: file_hash || hash.replace('.pdf',''),
    file_size: file_size || null, file_mime: file_mime || 'application/pdf',
    caso_id: caso_id || null, vaga_id: vaga_id || null,
    company_id: empresa_id || null, status: 'QUEUED', etapa: 'queued',
  }, prefer: true });
  if (r.status >= 400) { json(res, r.status, { error: (r.data && r.data.message) || 'Falha ao criar o trabalho.' }); return; }
  const row = Array.isArray(r.data) ? r.data[0] : (r.data && r.data[0]) || r.data;
  const job = { id: row.id, file_path, file_name: file_name || hash, caso_id, vaga_id, company_id: empresa_id };
  // lança o worker (honra a concorrência); a resposta já foi dada
  json(res, 202, { job_id: row.id, status: 'QUEUED', status_url: `/cv/queue/${row.id}` });
  scheduleJob(job, token);
}
async function scheduleJob(job, token) {
  cancelFlags.set(job.id, false);
  // se exceder o limite, espera em fila local (a BD já está QUEUED)
  while (ativos >= QUEUE.maxConcurrent) await new Promise((r) => setTimeout(r, 250));
  await processJob(job, token);
}
async function processJob(job, token) {
  ativos++;
  job._t0 = Date.now();
  const api = REST_BASE(token);
  try {
    await api.updateJob(job.id, { status: 'EXTRACTING', etapa: 'extracting', started_at: new Date().toISOString(), progress: 10 });
    const full = path.join(UPLOAD_DIR, path.basename(job.file_path));
    const ext = await extractText(full);
    if (cancelFlags.get(job.id)) { await api.updateJob(job.id, { status: 'CANCELLED', etapa: 'cancelled', cancel_requested_at: new Date().toISOString(), progress: 0 }); return; }
    // sem texto extraível e falhou a extração -> marca erro sem afetar os restantes
    if (!ext.ok) { throw new Error(ext.error || 'Falha ao extrair o texto do PDF.'); }
    if (!ext.has_text && !ext.ocr_used) {
      await api.updateJob(job.id, { status: 'ERROR', etapa: 'error', error_message: 'O PDF não contém texto extraível nem OCR disponível.', progress: 0 });
      return;
    }
    await api.updateJob(job.id, { status: 'ANALYZING', etapa: 'analyzing', extracted_text: ext.text || '', progress: 45 });
    // Watchdog: certifica que o Ollama responde antes de lançar a inferência (reinicia se morto).
    if (!(await ensureOllamaAlive())) {
      throw new Error('Ollama não está a responder (health-check falhou após reinício). Tenta novamente mais tarde.');
    }
    const result = await analyzeWithOllama(ext.text || '');
    if (cancelFlags.get(job.id)) { await api.updateJob(job.id, { status: 'CANCELLED', etapa: 'cancelled', progress: 0 }); return; }
    const analysis = result.data || {};
    await api.updateJob(job.id, {
      status: 'DONE', etapa: 'done', finished_at: new Date().toISOString(),
      duration_ms: Math.max(1, Date.now() - job._t0), progress: 100,
      analysis_json: analysis,
      model_ia: OLLAMA.model, prompt_version: OLLAMA.cvPromptVersion,
    });
  } catch (e) {
    // tentativas
    try {
      const jrow = (await api.getJob(job.id));
      const arr = Array.isArray(jrow.data) ? jrow.data : [];
      const cur = arr[0] || { attempt: 0 };
      const attempt = (cur.attempt || 0) + 1;
      if (attempt <= QUEUE.maxRetries) {
        await api.updateJob(job.id, { status: 'QUEUED', etapa: 'queued', attempt, error_message: null });
        // re-schedule após short delay
        setTimeout(() => scheduleJob(job, token), 2000);
      } else {
        await api.updateJob(job.id, { status: 'ERROR', etapa: 'error', attempt, error_message: e.message, error_details: { stack: String(e.stack || '').slice(0, 1000) } });
      }
    } catch { await api.updateJob(job.id, { status: 'ERROR', etapa: 'error', error_message: e.message }); }
  } finally {
    ativos--;
    cancelFlags.delete(job.id);
  }
}
async function listQueue(req, res) {
  const token = extractBearer(req);
  const status = req.url.match(/[?&]status=([^&]+)/) ? decodeURIComponent(req.url.match(/[?&]status=([^&]+)/)[1]) : '';
  const api = REST_BASE(token);
  const r = await api.listJobs();
  let rows = Array.isArray(r.data) ? r.data : [];
  // omitir arquivados (validados/cancelados consumidos) a menos que ?inclusive=arquivados
  const inclArquivados = /[?&]inclusive=arquivados/.test(req.url);
  if (!inclArquivados) rows = rows.filter((j) => !j.arquivado_at);
  if (status) rows = rows.filter((j) => j.status === status);
  json(res, 200, { jobs: rows, total: rows.length });
}
async function getQueueJob(req, res, id) {
  const token = extractBearer(req);
  const r = await rest(token, `/lifecycle_cv_jobs?id=eq.${id}&select=*`, {});
  const arr = Array.isArray(r.data) ? r.data : [];
  if (!arr.length) { json(res, 404, { error: 'Trabalho não encontrado.' }); return; }
  json(res, 200, arr[0]);
}
async function cancelQueueJob(req, res, id) {
  const token = extractBearer(req);
  const r = await rest(token, `/lifecycle_cv_jobs?id=eq.${id}&select=status`, {});
  const arr = Array.isArray(r.data) ? r.data : [];
  if (!arr.length) { json(res, 404, { error: 'Trabalho não encontrado.' }); return; }
  const st = arr[0].status;
  const now = new Date().toISOString();
  if (['QUEUED', 'UPLOADING'].includes(st)) {
    // na fila: cancela imediatamente e não cria ficha
    cancelFlags.set(id, true);
    await rest(token, `/lifecycle_cv_jobs?id=eq.${id}`, { method: 'PATCH', body: { status: 'CANCELLED', etapa: 'cancelled', cancelled_at: now, cancelled_by: (JSON.parse(req.headers['x-user'] || 'null') || {}).id || null } });
    json(res, 200, { ok: true, status: 'CANCELLED' }); return;
  }
  // CANCEL_REQUESTED pendente já existe: o cancelamento anterior não evoluiu (Ollama
  // congelado/morto). Cancelar definitivamente -> CANCELLED e sair da fila.
  if (st === 'CANCEL_REQUESTED') {
    cancelFlags.set(id, true);
    await rest(token, `/lifecycle_cv_jobs?id=eq.${id}`, { method: 'PATCH', body: { status: 'CANCELLED', etapa: 'cancelled', cancelled_at: now, finished_at: now, arquivado_at: now, viewed: true, cancelled_by: (JSON.parse(req.headers['x-user'] || 'null') || {}).id || null } });
    json(res, 200, { ok: true, status: 'CANCELLED', forca: true }); return;
  }
  // em processamento (ou aguardando na fila local): pedir cancelamento seguro
  cancelFlags.set(id, true);
  await rest(token, `/lifecycle_cv_jobs?id=eq.${id}`, { method: 'PATCH', body: { status: 'CANCEL_REQUESTED', etapa: 'cancel_requested', cancel_requested_at: now, cancel_requested_by: (JSON.parse(req.headers['x-user'] || 'null') || {}).id || null } });
  json(res, 200, { ok: true, status: 'CANCEL_REQUESTED' });
}
async function retryQueueJob(req, res, id) {
  const token = extractBearer(req);
  const r = await rest(token, `/lifecycle_cv_jobs?id=eq.${id}&select=*`, {});
  const arr = Array.isArray(r.data) ? r.data : [];
  if (!arr.length) { json(res, 404, { error: 'Trabalho não encontrado.' }); return; }
  const j = arr[0];
  cancelFlags.set(id, false);
  await rest(token, `/lifecycle_cv_jobs?id=eq.${id}`, { method: 'PATCH', body: { status: 'QUEUED', etapa: 'queued', attempt: (j.attempt || 0), error_message: null, finished_at: null } });
  scheduleJob({ id, file_path: j.file_path, file_name: j.file_name, caso_id: j.caso_id, vaga_id: j.vaga_id, company_id: j.company_id }, token);
  json(res, 200, { ok: true, status: 'QUEUED' });
}
async function viewQueueJob(req, res, id) {
  await rest(extractBearer(req), `/lifecycle_cv_jobs?id=eq.${id}`, { method: 'PATCH', body: { viewed: true } });
  json(res, 200, { ok: true });
}
async function archiveQueueJob(req, res, id) {
  // Fecha o job: sai da fila ativa (arquivado_at preenchido) mas mantém o histórico/auditoria.
  await rest(extractBearer(req), `/lifecycle_cv_jobs?id=eq.${id}`, { method: 'PATCH', body: { arquivado_at: new Date().toISOString(), viewed: true } });
  json(res, 200, { ok: true });
}

// ---------- Fase 3: Ollama (config via env, nunca em código) ----------
const OLLAMA = {
  model: process.env.OLLAMA_CV_MODEL || process.env.OLLAMA_MODEL || 'llama3.2:3b',
  baseUrl: process.env.OLLAMA_BASE_URL || 'http://localhost:11434',
  timeoutMs: Number(process.env.OLLAMA_CV_TIMEOUT || 1200000),
  temperature: Number(process.env.OLLAMA_CV_TEMPERATURE || 0.0),
  cvPromptVersion: process.env.OLLAMA_CV_PROMPT_VERSION || '1.0',
};

// jobs em memória (execução única por servidor; suficientes para um ambiente local)
const JOBS = new Map();
async function runAnalyzeJob(job) {
  try {
    const result = await analyzeWithOllama(job.text);
    job.state = 'done';
    job.result = result;
  } catch (e) {
    job.state = 'error';
    job.error = e.message;
  }
}
async function runMatchJob(job) {
  try {
    const result = await matchWithOllama(job.text, job.analysis, job.vaga);
    job.state = 'done';
    job.result = result;
  } catch (e) {
    job.state = 'error';
    job.error = e.message;
  }
}

// ---------- deteção de língua do CV (EN vs PT) ----------
const PT_WORDS = ['currículo', 'licenciatura', 'mestrado', 'experiência', 'formação', 'competências', 'portugal', 'línguas', 'habilitações', 'contactos', 'nacionalidade', 'objetivos', 'empresa', 'cargo', 'funções'];
const EN_WORDS = ['curriculum', 'resume', 'bachelor', 'master', 'experience', 'education', 'skills', 'portugal', 'languages', 'nationality', 'objectives', 'company', 'position', 'summary', 'internship'];
function detectLanguage(text) {
  const t = (text || '').toLowerCase();
  let pt = 0, en = 0;
  for (const w of PT_WORDS) if (t.includes(w)) pt++;
  for (const w of EN_WORDS) if (t.includes(w)) en++;
  // heurística adicional: artigos/palavras curtas comuns
  const ptShort = (t.match(/\b(na|no|das|dos|em|com|para|uma|um)\b/g) || []).length;
  const enShort = (t.match(/\b(the|of|and|in|for|with|as|an)\b/g) || []).length;
  return (en + enShort) > (pt + ptShort) ? 'en' : 'pt';
}

const CV_SYSTEM_PROMPT_BASE = `És um extrator de dados de currículos (CV). Responde APENAS com JSON válido, sem Markdown, sem código à volta.
Regras obrigatórias:
- Usa null quando o dado não existe no CV. Não inventes dados.
- Separa factos de inferências: cada campo pode conter {value, confidence (0-1), evidence, source_page, status}.
- status: "extracted" (dito no CV), "inferred" (deduzido), "manually_confirmed", "manually_corrected", "unavailable".
- Mantém nomes próprios como estão. Normaliza datas sem inventar componentes (ex. "2023" ou "2023-06" se o CV só disser isso).
- NUNCA inventes níveis de competência, anos de experiência, datas, funções ou motivos de saída.
- Nunca uses características protegidas como critério: idade, sexo, género, estado civil, religião, origem étnica, orientação sexual, saúde, filiação sindical, fotografia.
- identifica informação em falta (missing_information) e contradições (contradictions) com citações do texto.
- Sugere perguntas de entrevista (suggested_interview_questions) relevantes e não discriminatórias.
- RESPONDE NO MESMO IDIOMA DO CV: se o CV estiver em inglês, escreve todos os textos (summary, descriptions, interview questions, missing_information) em INGLÊS, preservando o texto original sem traduzir; se o CV estiver em português, responde em PORTUGUÊS.
- Não inventes nem corriges o idioma: usa exatamente as palavras do CV onde existirem.

Estrutura mínima de resposta (schema ECV 1.0):
{
  "schema_version": "1.0",
  "document_language": "pt",
  "candidate": {},
  "contacts": {},
  "professional_summary": {},
  "work_experience": [],
  "education": [],
  "certifications": [],
  "skills": [],
  "languages": [],
  "projects": [],
  "preferences": {},
  "references": [],
  "missing_information": [],
  "contradictions": [],
  "suggested_interview_questions": [],
  "extraction_warnings": [],
  "overall_confidence": 0.0
}
Cada item de listas (work_experience, education, certifications, skills, languages, projects, references) deve ter os campos com {value, confidence, evidence, source_page, status} onde aplicável.
preferences só deve ser preenchido se o CV o declarar explicitamente (expectativa salarial, regime, localização, etc.); caso contrário fica {} e regista em missing_information.
"document_language" deve refletir a língua real do CV (pt ou en).`;

function buildSystemPrompt(lang) {
  return CV_SYSTEM_PROMPT_BASE + `\nO CV deste pedido está em ${lang === 'en' ? 'INGLÊS' : 'PORTUGUÊS'} — responde nesse idioma e define "document_language" como "${lang}".`;
}

function callOllama(system, user) {
  return new Promise((resolve, reject) => {
    const http = require('http');
    const u = new URL(OLLAMA.baseUrl);
    const payload = JSON.stringify({
      model: OLLAMA.model,
      messages: [
        { role: 'system', content: system },
        { role: 'user', content: user },
      ],
      stream: false,
      temperature: OLLAMA.temperature,
      format: 'json',
    });
    let done = false;
    const finish = (fn, val) => { if (!done) { done = true; clearTimeout(watchdog); fn(val); } };
    // Watchdog GARANTIDO: mesmo que o socket não dispare, rejeita após timeoutMs.
    const watchdog = setTimeout(() => finish(reject, new Error(`Timeout do Ollama (${OLLAMA.timeoutMs}ms) — reinicie o servidor Ollama`)), OLLAMA.timeoutMs);
    const req = http.request({ hostname: u.hostname, port: u.port, path: '/api/chat', method: 'POST', headers: { 'Content-Type': 'application/json' }, timeout: OLLAMA.timeoutMs }, (res) => {
      let data = '';
      let size = 0;
      res.on('data', (c) => {
        data += c; size += c.length;
        if (size > 4 * 1024 * 1024) { req.destroy(new Error('Resposta do Ollama demasiado grande (>4MB)')); }
      });
      res.on('end', () => { try { finish(resolve, JSON.parse(data)); } catch { finish(reject, new Error('Resposta inválida do Ollama')); } });
    });
    req.on('timeout', () => req.destroy(new Error('Timeout do Ollama')));
    req.on('error', (e) => finish(reject, e));
    req.write(payload);
    req.end();
  });
}

// ---------- Watchdog do Ollama: health-check + auto-restart se morto ----------
// Evita a fila presa para sempre quando o Ollama fica silencioso (o que aconteceu em produção).
const OLLAMA_AUTO_RESTART = String(process.env.CV_OLLAMA_AUTO_RESTART || 'true').toLowerCase() !== 'false';
const OLLAMA_HEALTH_TIMEOUT = Number(process.env.OLLAMA_HEALTH_TIMEOUT || 8000);
let ollamaFails = 0; // reinícios já tentados consecutivamente
function ollamaIsUp() {
  return new Promise((resolve) => {
    const http = require('http');
    const u = new URL(OLLAMA.baseUrl);
    const req = http.get({ hostname: u.hostname, port: u.port, path: '/api/tags', timeout: OLLAMA_HEALTH_TIMEOUT }, (res) => {
      res.resume();
      res.on('end', () => resolve(res.statusCode === 200));
    });
    req.on('timeout', () => { req.destroy(); resolve(false); });
    req.on('error', () => resolve(false));
  });
}
function restartOllama() {
  return new Promise((resolve) => {
    if (!OLLAMA_AUTO_RESTART) { resolve(false); return; }
    const { spawn } = require('child_process');
    let cmd, args;
    if (process.platform === 'win32') { cmd = 'taskkill'; args = ['/F', '/IM', 'ollama.exe']; }
    else { cmd = 'pkill'; args = ['-f', 'ollama serve']; }
    const kill = spawn(cmd, args, { stdio: 'ignore' });
    kill.on('close', () => {
      const up = spawn('ollama', ['serve'], { stdio: 'ignore', detached: true });
      up.unref();
      setTimeout(resolve, 4000, true); // dá tempo ao servidor a subir
    });
  });
}
async function ensureOllamaAlive() {
  if (await ollamaIsUp()) { ollamaFails = 0; return true; }
  if (ollamaFails >= 2) { return false; } // não reinicia em loop infinito
  ollamaFails++;
  console.log(`[cv] Ollama não responde — a reiniciar (tentativa ${ollamaFails})…`);
  await restartOllama();
  const up = await ollamaIsUp();
  if (up) { ollamaFails = 0; console.log('[cv] Ollama reiniciado e a responder.'); return true; }
  return false;
}

async function analyzeWithOllama(text) {
  const lang = detectLanguage(text);
  const res = await callOllama(buildSystemPrompt(lang), `Texto do CV (${lang}):\n${text.slice(0, 30000)}`);
  const content = (res.message && res.message.content) || '';
  const m = content.match(/\{[\s\S]*\}/);
  if (!m) throw new Error('JSON não encontrado na resposta do modelo');
  let parsed;
  try { parsed = JSON.parse(m[0]); }
  catch {
    // 2ª tentativa: remover quebras de linha dentro de strings e espaços soltos que o modelo possa ter introduzido
    const cleaned = m[0]
      .replace(/\n\s*/g, ' ')
      .replace(/,\s*}/g, '}')
      .replace(/\}\s*,\s*"/g, '},"');
    try { parsed = JSON.parse(cleaned); } catch { throw new Error('JSON inválido na resposta do modelo'); }
  }
  return { ok: true, data: parsed };
}

// ---------- Fase 4: comparação explicável com a vaga ----------
const MATCH_SYSTEM_PROMPT = `És um assistente de recrutamento. Compara o currículo (CV) de um candidato com a vaga e devolve APENAS JSON válido, sem Markdown.
Regras obrigatórias:
- Nunca decides a contratação: a decisão final é sempre humana. A tua saída é uma recomendação assistiva.
- NUNCA uses características protegidas como critério de pontuação ou exclusão: idade, sexo, género, fotografia, estado civil, gravidez, religião, origem étnica ou racial, orientação sexual, opinião política, deficiência, saúde, filiação sindical, morada como indicador socioeconómico, ou qualquer outro dado legalmente protegido.
- Sê explícito: para cada requisito indica se foi encontrado no CV (e com que evidência) ou está em falta.
- Pontua cada categoria de 0 a 100 com justificação curta.
- Preenche: competencias_encontradas[], competencias_em_falta[], alertas[] (discrepâncias relevantes), perguntas_entrevista[] (não discriminatórias), recomendacao_ia dependente só de requisitos legítimos da vaga (obrigatórios/preferenciais de competências, experiência, formação, idiomas e disponibilidade quando for requisito legítimo).

Estrutura de resposta:
{
  "score_global": 0.0,
  "score_requisitos": 0.0,
  "score_preferenciais": 0.0,
  "score_competencias": 0.0,
  "score_experiencia": 0.0,
  "score_formacao": 0.0,
  "score_idiomas": 0.0,
  "score_disponibilidade": 0.0,
  "competencias_encontradas": ["..."],
  "competencias_em_falta": ["..."],
  "razao": [{"requisito": "...", "tipo": "obrigatorio", "encontrado": true, "evidencia": "...", "origem": "skill|experiencia|formacao|idioma"}],
  "alertas": ["..."],
  "perguntas_entrevista": ["..."],
  "recomendacao_ia": "favoravel|neutra|desfavoravel",
  "resumo": "parágrafo curto de justificação, no idioma do CV"
}`;

async function matchWithOllama(text, analysis, vaga) {
  const lang = detectLanguage(text || '') || (analysis && analysis.document_language) || 'pt';
  const req = JSON.stringify({ titulo: vaga.titulo, requisitos: vaga.requisitos || {}, descricao: vaga.descricao || null });
  const cvCtx = analysis ? `Análise estruturada do CV:\n${JSON.stringify(analysis).slice(0, 20000)}` : `Texto do CV:\n${(text || '').slice(0, 20000)}`;
  const user = `VAGA:\n${req}\n\nCANDIDATO:\n${cvCtx}\n\nCompara e devolve o JSON de avaliação explicável.`;
  const res = await callOllama(MATCH_SYSTEM_PROMPT + `\nO CV está em ${lang === 'en' ? 'inglês' : 'português'} — escreve o "resumo" nesse idioma.`, user);
  const content = (res.message && res.message.content) || '';
  const m = content.match(/\{[\s\S]*\}/);
  if (!m) throw new Error('JSON não encontrado na resposta do modelo');
  let parsed;
  try { parsed = JSON.parse(m[0]); }
  catch {
    const cleaned = m[0].replace(/\n\s*/g, ' ').replace(/,\s*}/g, '}').replace(/\}\s*,\s*"/g, '},"');
    try { parsed = JSON.parse(cleaned); } catch { throw new Error('JSON inválido na resposta do modelo'); }
  }
  return { ok: true, data: parsed };
}

server.listen(PORT, () => {
  console.log(`[cv] CV processor a ouvir em :${PORT}`);
  // Recuperação no arranque: jobs interrompidos por reinício (estado ativo + sem fim)
  // são marcados como ERROR ('Tentar novamente') em vez de ficarem presos para sempre.
  recoverStaleJobs();
  // Recuperação periódica: jobs em CANCEL_REQUESTED que ficaram presos (Ollama congelou
  // no cancelamento e nunca evoluiu) são concluídos automaticamente, saindo da fila.
  // Sem isto ficavam visíveis indefinidamente como "a processar".
  setInterval(recoverStaleJobs, QUEUE.recoverIntervalMs || 15 * 60 * 1000);
});

// Jobs ativos sem finished_at há >CV_STALE_JOB_TIMEOUT são marcados como ERROR no boot.
async function recoverStaleJobs() {
  try {
    if (!QUEUE.enabled) return;
    const minutos = Math.max(1, Math.round(QUEUE.staleTimeoutMs / 60000));
    const r = await rest('', `/rpc/cv_recover_stale_jobs`, { method: 'POST', body: { p_interrupted_minutes: minutos } });
    let n = 0;
    if (typeof r.data === 'number') n = r.data;
    else if (Array.isArray(r.data)) n = Number((r.data[0] || {})['cv_recover_stale_jobs'] ?? r.data[0] ?? 0);
    else if (r.data && typeof r.data === 'object') n = Number(r.data['cv_recover_stale_jobs'] ?? r.data.recovered ?? 0);
    console.log(`[cv] Recuperação de jobs interrompidos: ${n} trabalho(s) marcados como 'Tentar novamente'.`);
  } catch (e) {
    console.log(`[cv] Aviso: recuperação de jobs falhou (${e.message}).`);
  }
}