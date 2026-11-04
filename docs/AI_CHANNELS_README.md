# Assistente IA + Canais (MCP · Ollama · Telegram · WhatsApp)

Evolução do **Programa de Gestão de Ocorrências** para ser consultável por linguagem
natural através da interface web, do **Telegram** e (futuramente) do **WhatsApp**,
tudo com execução local (Ollama) e sem acesso direto da IA à base de dados.

> Implementado até à **Fase 3** (MCP read-only + Ollama + associação de identidade +
> Telegram com consultas). As Fases 4–5 (voz/Whisper, escrita com confirmação) e 6
> (WhatsApp) são preparadas na arquitetura, com pontos de extensão já no código.

---

## Arquitetura

```
Telegram ──┐                 ┌──► Ollama (LLM local)  ── identifica intenção / escolhe tools
Web Chat ──┼► Messaging Gateway ► Agente (agent-orchestrator)
WhatsApp ──┘      │                           │
                  │                     MCP Tools (mcp-tools.js)
                  │                           │
             Identidade/autorização      Serviços da app (PostgREST + RLS)
                  │                           │
                  └──────────────►  Base de dados (PostgreSQL local)
```

**Regra de ouro:** nenhum canal, bot ou modelo executa SQL livre nem recebe
credenciais. Todas as consultas passam por `executePlan()` que usa o **access token
do utilizador** (PostgREST aplica o RLS real da app). A IA pode até receber um token
curto de serviço por utilizador (`channel-token.js`), nunca as chaves da BD.

---

## Ficheiros (backend/ai/)

| Ficheiro | Papel |
|---|---|
| `mcp-tools.js` | Tools MCP **read-only** sobre o domínio real + execução com RLS |
| `agent-orchestrator.js` | Agente: interpretação determinística + Ollama, resposta pt-PT |
| `messaging-gateway.js` | Abstração comum de canal (Incoming/Outgoing + identidade + auditoria) |
| `telegram-adapter.js` | Adaptador Telegram (long-polling dev + webhook produção) |
| `ai-channels-server.js` | HTTP server `:3005` — webhook, associação, revogação, MCP, status |
| `channel-token.js` | Token de serviço por utilizador (para RLS) |
| `shared-lists.js` | Listas de áreas/origens (resolver nomes sem inventar) |
| `ollama-service.js` | Cliente Ollama (reutilizado) |

**Migrations novas:** `0012_ai_channels.sql` (external_ai_identities +
ai_action_logs + ai_pending_actions), `0013_ai_search_text.sql` (pesquisa full-text
na RPCA `ai_occurrence_search`).

## Camada MCP (server) — portas/endpoints

O proxy (`api-proxy.js :8000`) roteia:
- `/mcp/tools/list` · `/mcp/tools/call` → **3005** (interface MCP, autenticada por JWT)
- `/channels/status`, `/channels/link/start|confirm|revoke`, `/channels/telegram/webhook` → **3005**

Tools read-only disponíveis (17):

| Tool | Descrição |
|---|---|
| `get_occurrences_summary` | Contagens abertas/curso/eficácia/encerradas/total |
| `search_occurrences` | Lista com filtros (estado, tipo, área, origem, responsável, período, pesquisa) e paginação |
| `get_occurrence` | Uma ocorrência por referência/ID |
| `get_open_occurrences` | Em aberto |
| `get_critical_occurrences` | Críticas (sem responsável) |
| `get_occurrences_statistics` | Agrupamento por tipo/estado/área/origem/responsável/mês |
| `get_area_occurrences` | Por área |
| `get_responsible_workload` | Carga por responsável |
| `get_available_areas` / `get_available_origins` | Listas de apoio (resolver nomes) |
| `get_dashboard_summary` | KPIs + distribuição por área/origem |
| `lc_search_candidates` | Candidaturas LifeCycle por estado/nome (referência LCY, nome, estado, função, equipa) |
| `lc_get_candidate` | Uma candidatura + tarefas + comunicações por referência LCY |
| `lc_list_vagas` | Vagas (VG, título, departamento, tipo, estado) |
| `lc_candidate_tasks` | Tarefas de admissão/offboarding/estágio (filtro gate P0/P1, status) |
| `lc_candidate_communications` | Comunicações E01-E12 registadas (evidência de envio) |
| `lc_pool_summary` | Resumo do pool: contagem por estado e por tipo |

As tools `lc_*` acedem às tabelas `lifecycle_*` **com o token do utilizador (RLS)** — qualidade e LifeCycle RH estão acessíveis à IA para pesquisa.

Nenhuma tool executa escrita. Intenções de escrita são detetadas e respondidas como
"pendente de confirmação" sem executar (Fase 5 preparada com `ai_pending_actions`).

---

## Instalação/configuração local

### 1. Ollama (modelo sugerido)
```bash
# O modelo recomendado depende do hardware. Com ~2–4 GB VRAM:
ollama pull llama3.2:3b     # usado por defeito; configurável via OLLAMA_MODEL
# Para hardware mais modesto: ollama pull llama3.2:1b
```

### 2. Variáveis (`.env` em backend/)
```ini
OLLAMA_BASE_URL=http://127.0.0.1:11434
OLLAMA_MODEL=llama3.2:3b
MCP_ENABLED=true
TELEGRAM_ENABLED=true
TELEGRAM_BOT_TOKEN=<do BotFather>
# sem TELEGRAM_WEBHOOK_URL ⇒ usa long-polling (ótimo para dev/Internet temporária)
```

### 3. Bot Telegram
1. No Telegram, fala com **@BotFather** → `/newbot` → nome → username.
2. Copia o token para `TELEGRAM_BOT_TOKEN`.

> Para **produção/HTTPS**, define `TELEGRAM_WEBHOOK_URL` e um
> `TELEGRAM_WEBHOOK_SECRET`, e aponta o webhook:
> `https://api.telegram.org/bot<TOKEN>/setWebhook?url=<WH_URL>&secret_token=<SECRET>`
> (o servidor valida `X-Telegram-Bot-Api-Secret-Token`).
> Em dev, omite a URL — o `telegram-adapter` usa `getUpdates` (long-polling).

### 4. WhatsApp (Cloud API — quando ativado)

O WhatsApp usa o **mesmo Messaging Gateway** que o Telegram (mesma lógica de agente,
MCP, permissões e auditoria). Não há duplicação de código de negócio.

**Passos para ativar (é necessário ter a app do Meta configurada):**
1. Cria uma app em **developers.facebook.com** e liga um **número WhatsApp Business**
   (acesso à WhatsApp Cloud API).
2. Copia para `backend/.env`:
   ```ini
   WHATSAPP_ENABLED=true
   WHATSAPP_ACCESS_TOKEN=<token de acesso longo>
   WHATSAPP_PHONE_NUMBER_ID=<id do número>
   WHATSAPP_VERIFY_TOKEN=<token de verificação que escolhes>
   WHATSAPP_APP_SECRET=<App Secret do Meta>
   WHATSAPP_WEBHOOK_URL=https://dominio.pt/channels/whatsapp/webhook
   ```
3. Regista o **webhook** no painel da app Meta, apontando para o URL acima. O Meta faz um
   **GET de verificação** (challenge) — o servidor valida `hub.verify_token` e responde
   com o `hub.challenge`. Todos os eventos POST são validados pela **assinatura
   `X-Hub-Signature-256`** (HMAC do App Secret).
4. O webhook precisa de HTTPS público (ex.: o túnel Cloudflare já usado na app).

**Associação:** igual ao Telegram — o utilizador gera um código em *Administração →
IA e Canais → Gerar código* (canal WhatsApp) e envia `link <código>` para o número da
empresa. A maior diferença é que o WhatsApp não aceita botões livres como o Telegram;
usam-se respostas interativas (botões) que o `whatsapp-adapter` já normaliza.

**Endpoints:** `GET/POST /channels/whatsapp/webhook` (verificação + eventos).

> Em dev, sem `WHATSAPP_APP_SECRET`, a verificação de assinatura é omissa (mode "off").
> ***WHATSAPP_ENABLED=false*** por omissão — não ativa sem credenciais reais.

### 4b. Microsoft Teams (Bot Framework — pronta a ativar)

O Teams reutiliza o **mesmo Messaging Gateway**; o adapter `teams-adapter.js` converte
as **atividades do Bot Framework** (json `type: message`) em `IncomingMessage` interno.

**Rota:** `POST /channels/teams/api/messages` (webhook do bot Teams) · `GET /channels/teams/health`.

- Validação em dev pelo token `TEAMS_CHANNEL_TOKEN` (header `X-Teams-Token`).
- Em **produção**, o Teams/Bot Framework usa autenticação própria (App ID + Client
  Secret + validação JWT) — basta trocar a `webhookOk()` pela verificação de login do
  Teams à frente do mesmo handler.
- Associação igual: `/link <código>`; ping (`type: 'ping'`) respondido com 200.

**Para ativar:** criar uma app no **Azure Bot Framework** e configurar o endpoint como
`https://dominio.pt/channels/teams/api/messages`, com `TEAMS_ENABLED=true` e o secret.

### 4c. Slack (Socket Mode — pronto a ativar)

O Slack usa o **mesmo Messaging Gateway**. Dois modos:
- **Socket Mode (recomendado para dev)** — websocket, **não precisa de HTTPS público**
  (como o Telegram em polling). Requer `SLACK_BOT_TOKEN` (xoxb-) e `SLACK_APP_TOKEN` (xapp-).
- **Events API** — webhook `POST /channels/slack/events` com verificação de assinatura
  `X-Slack-Signature` (se `SLACK_SIGNING_SECRET` estiver definido).

Capta mensagens diretas ao bot (`message.im`) e mentions (`app_mention`); ignora
mensagens do próprio bot e edições. Associação igual: `/link <código>`.

**Para ativar:** criar uma **App Slack** (api.slack.com/apps) com Socket Mode ligado e
scopes `chat:write` e `message.im`; colocar os tokens em `SLACK_*` com `SLACK_ENABLED=true`.

### 5. Canais + auditoria (BD)
A migration `0012` cria as tabelas e as policies RLS. Já aplicada localmente.

---

## Como associar uma conta (seguro)

1. Na app → **Administração → IA e Canais → Gerar código** (o admin gera um código
   de 6 caracteres, válido ~10 min).
2. No Telegram, envia ao bot: `/link <código>`.
3. O bot associa o `telegram_user_id` ao utilizador interno e responde "Conta associada".

Regras de segurança da associação:
- **Nunca** auto-associa por número/email coincidente (o código é a autorização).
- Duplicar o mesmo código é rejeitado (idempotência — `ai_pending_actions`).
- `/logout` ou "Revogar" na app desliga o canal (`revoked_at`, `is_active=false`).
- Auditoria fica em `ai_action_logs` (quem, canal, tool, resultado).

---

## Exemplos de conversa (consultas)

```
"Quantas ocorrências estão abertas?"
  → Abertas: 28 · Em curso: 25 · A aguardar eficácia: 3 · Encerradas: 2 · Total: 30.
"Mostra as NC na área de Desenvolvimento"
  → 5 ocorrência(s): NC-2026-0021 — Desenvolvimento — IN_PROGRESS; …
"Quais as áreas com mais ocorrências?"
  → Desenvolvimento=8, Financeiro=5, Sistemas=5, …
"Mostra as origens" / "Qual é o dashboard?"
  → LPIs & distribuição por área/origem.
"Mostra a ocorrência NC-2026-0001"
  → detalhe da ocorrência.
"cria uma ocorrência …" → ⛔ "precisa de confirmação (funcionalidade em preparação)"
```

---

## Testes executados (resultados reais)

- RPC `ai_occurrence_search` com pesquisa `NC-2026-0001` → devolve a ocorrência. ✅
- Agrupamento por área → `[Desenvolvimento 8, Financeiro 5, Sistemas 5, …]`. ✅
- `get_occurrences_summary` → abertas 28 / encerradas 2 / total 30. ✅
- `get_available_areas/get_available_origins` → listas reais. ✅
- Associação de conta: código gerado → confirmado; código errado rejeitado;
  código repetido rejeitado (idempotência). ✅
- Agente: "quantas abertas" → 28 (exato); escrita → bloquemada como pendente. ✅
- MCP via proxy (`:8000/mcp/tools/call`) com o token do utilizador → dados reais. ✅

---

## Limitações / próximas fases

- **Telegram real** não testado de ponta a ponta até haver `TELEGRAM_BOT_TOKEN`.
- **Voz/Whisper** (Fase 4): o adapter já distingue `voice` e devolve "em preparação";
  a integração Whisper local fica em `WHISPER_*`.
- **Escrita com confirmação** (Fase 5): `ai_pending_actions` + fluxo confirm/cancel
  já desenhados; falta ligar as tools de escrita.
- **WhatsApp** (Fase 6): mesmo Gateway; basta implementar o adapter e as env vars.

## Segurança (resumo)

- IA **sem** acesso SQL/credenciais; tudo via PostgREST + RLS.
- Apenas tools da lista; argumentos filtrados pelos schemas.
- Nada de `execute_sql`/`raw_query`/shell/fs.
- Segredos só em env; tokens de bot nunca nos logs.
- Conteúdos da BD tratados como dados (não instruções).
- Podem adicionar-se limites de taxa por identidade/empresa no gateway.