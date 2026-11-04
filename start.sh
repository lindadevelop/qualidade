#!/usr/bin/env bash
# SAMSYS|Qualidade — arranca o stack local numa janela:
#   1. PostgreSQL (portátil)  2. PostgREST (API)  3. auth-server  4. api-proxy (Kong)
#   5. ai-assistant (Ollama)  6. frontend (Vite preview ou dev)
# Cada serviço em background; os logs vão para backend/*.log

set -u
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

# 1. PostgreSQL
if ! pgportable/pgsql/bin/pg_isready.exe -h 127.0.0.1 -p 5432 >/dev/null 2>&1; then
  pgportable/pgsql/bin/pg_ctl.exe -D "$ROOT/pgdata" -l "$ROOT/pg.log" -o "-p 5432 -c listen_addresses=localhost" start
  echo "[1] PostgreSQL iniciado"
fi

# 2. PostgREST :3001
if ! (netstat -an | grep ":3001 " | grep -q LISTENING); then
  pgportable/pgsql/bin/postgrest.exe "$ROOT/postgrest.conf" > "$ROOT/backend/postgrest.log" 2>&1 &
  echo "[2] PostgREST :3001 deu start"
fi

# 3. auth-server :3002
if ! (netstat -an | grep ":3002 " | grep -q LISTENING); then
  (cd backend && node auth-server.js) > backend/auth.log 2>&1 &
  echo "[3] auth-server :3002 deu start"
fi

# 4. api-proxy :8000
if ! (netstat -an | grep ":8000 " | grep -q LISTENING); then
  (cd backend && node api-proxy.js) > backend/proxy.log 2>&1 &
  echo "[4] api-proxy :8000 deu start"
fi

# 5. ai-assistant :3004
if ! (netstat -an | grep ":3004 " | grep -q LISTENING); then
  (cd backend && node ai/ai-assistant-server.js) > backend/ai.log 2>&1 &
  echo "[5] assistente IA :3004 deu start"
fi

# 6. ai-channels (Telegram/WhatsApp/Teams/Slack) :3005
if ! (netstat -an | grep ":3005 " | grep -q LISTENING); then
  (cd backend && node ai/ai-channels-server.js) > backend/channels.log 2>&1 &
  echo "[6] canais IA :3005 deu start"
fi

# 7. frontend
if [ ! -d frontend/dist ]; then
  (cd frontend && npm run build) || echo "[7] falhou build do frontend"
fi
: ${PORT:=5178}
(cd frontend && npm run preview -- --port $PORT) > frontend/preview.log 2>&1 &
echo "[7] frontend em http://localhost:$PORT"

echo
echo "Stack iniciado. Frontend: http://localhost:$PORT"
echo "Canais IA em http://localhost:3005 (MCP tools read-only)"
echo "Para parar: fechar esta janela / matar os processos node e postgres."