#!/usr/bin/env bash
# =============================================================================
# tunnel.sh — SAMSYS|Qualidade
# Recria o túnel Cloudflare para acesso externo e atualiza a app automaticamente.
#
# Fluxo:
#   1. Mata o cloudflared que apontava para :5178 (se existir)
#   2. Cria um novo quick tunnel para http://localhost:5178
#   3. Captura o novo hostname https://xxx.trycloudflare.com
#   4. Atualiza VITE_SUPABASE_URL e allowedHosts no frontend
#   5. Rebuild do frontend com o novo hostname
#   6. Reinicia o preview do Vite na porta 5178
#
# Uso:
#   bash tunnel.sh          # Portugal Continental (default)
#   bash tunnel.sh -v       # verbose
#   bash tunnel.sh --help
# =============================================================================
set -euo pipefail

CLOUDFLARED_BIN="/c/Users/carlo/.hermes/scripts/cloudflared"
PORT="5178"
PROXY_URL="http://127.0.0.1:8000"
VERBOSE=0

# ---- ajuda --------------------------------------------------------------
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
fi
[[ "${1:-}" == "-v" ]] && VERBOSE=1

log() { echo -e "\033[1;36m[tunnel]\033[0m $*"; }
vlog() { [[ $VERBOSE -eq 1 ]] && echo "[verbose] $*"; }
die() { echo -e "\033[1;31m[tunnel] ERRO:\033[0m $*" >&2; exit 1; }

cd "$(dirname "$0")/frontend" 2>/dev/null || die "não encontro frontend/ (roda a partir de samsys-qualidade/)"

# ---- 1. matar cloudflared(s) da porta -----------------------------------
log "A limpar túneis anteriores da porta $PORT..."
for pid in $(netstat -ano 2>/dev/null | grep ":$PORT " | grep LISTENING | awk '{print $5}' | sort -u); do
  # identifica se é o processo do preview (node) ou um cloudflared — não matar o preview agora
  vlog "LISTENER na $PORT: pid $pid"
done

# matar cloudflared cuja linha de comando aponte para esta porta
for pid in $(powershell -NoProfile -Command "
  Get-CimInstance Win32_Process -Filter 'Name = \"cloudflared.exe\"' |
  Where-Object { \$_.CommandLine -match 'localhost:$PORT' } |
  Select-Object -ExpandProperty ProcessId
" 2>/dev/null | tr -d '\r'); do
  [[ -n "$pid" ]] && { taskkill /F /PID "$pid" >/dev/null 2>&1 && log "  cloudflared antigo $pid encerrado"; }
done
sleep 1

# ---- 2. criar novo túnel ------------------------------------------------
LOG_FILE="$(mktemp)"
log "A criar novo quick tunnel para :$PORT..."
"$CLOUDFLARED_BIN" tunnel --url "http://localhost:$PORT" --no-autoupdate >"$LOG_FILE" 2>&1 &
TUN_PID=$!
log "  PID do túnel: $TUN_PID"

# espera pelo hostname (até ~30s)
HOSTNAME=""
for i in $(seq 1 30); do
  HOSTNAME="$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$LOG_FILE" | head -1 || true)"
  [[ -n "$HOSTNAME" ]] && break
  sleep 1
done

[[ -z "$HOSTNAME" ]] && { [[ $VERBOSE -eq 1 ]] && cat "$LOG_FILE"; die "não foi possível obter o hostname do túnel."; }

log "Novo túnel: $HOSTNAME"

# ---- 3. atualizar config (allowedHosts) ---------------------------------
NEW_HOST="$(echo "$HOSTNAME" | sed 's|https://||')"
log "A atualizar vite.config.ts (allowedHosts += $NEW_HOST)..."
python - "$NEW_HOST" <<'PYEOF'
import sys, re
host = sys.argv[1]
path = "vite.config.ts"
src = open(path, encoding="utf-8").read()

def fix_allowed(m):
    # m.group(1) é o conteúdo completo [ ... ] da lista
    inner = m.group(1)
    if host in inner:
        return m.group(0)
    # remove o fecho ] e acrescenta o host novo antes dele
    body = inner[:-1].rstrip()
    sep = ", " if body.strip() not in ("", "[", "[]") else ""
    return f"allowedHosts: {body}{sep}{host!r}]"

out = re.sub(r"allowedHosts: (\[[^\]]*\])", fix_allowed, src)
open(path, "w", encoding="utf-8").write(out)
print("vite.config.ts atualizado")
PYEOF

# ---- 4. rebuild com o novo VITE_SUPABASE_URL -----------------------------
log "Rebuild do frontend com VITE_SUPABASE_URL=$HOSTNAME..."
VITE_SUPABASE_URL="$HOSTNAME" npm run build 2>&1 | tail -3

# ---- 5. reiniciar preview na :5178 --------------------------------------
log "A reiniciar o preview do Vite em :$PORT..."
# matar preview anterior (node vite preview nesta porta)
PREV_PIDS=$(powershell -NoProfile -Command "
  Get-CimInstance Win32_Process | Where-Object {
    \$_.Name -eq 'node.exe' -and \$_.CommandLine -match 'preview' -and \$_.CommandLine -match '$PORT'
  } | Select-Object -ExpandProperty ProcessId
" 2>/dev/null | tr -d '\r')
for p in $PREV_PIDS; do [[ -n "$p" ]] && taskkill /F /PID "$p" >/dev/null 2>&1; done
sleep 1

nohup npx vite preview --host 0.0.0.0 --port "$PORT" >/tmp/qual_preview.log 2>&1 &
log "Preview reiniciado (PID $!)."

echo ""
log "════════════════════════════════════════════════════════"
log "  SAMSYS|Qualidade está ONLINE"
log "  URL externo : $HOSTNAME"
log "  URL local   : http://localhost:$PORT"
log "  backend     : $PROXY_URL (proxy /auth /rest /ai)"
log "  túnel PID   : $TUN_PID"
log "════════════════════════════════════════════════════════"
echo "Novo hostname da Qualidade: $HOSTNAME"