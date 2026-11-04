# Integração de Voz — Gateway MCP (SAMSYS|Qualidade)

A voz é **apenas um novo canal de entrada**. Depois da transcrição, o sistema comporta-se
exatamente como se o utilizador tivesse escrito a mesma frase: o áudio converge para o mesmo
`handleMessage(...)` usado pelas mensagens de texto, com as mesmas tools MCP, as mesmas
permissões RLS e o mesmo contexto de conversa.

## Arquitetura

```
Telegram / Slack
   │  mensagem de voz / ficheiro áudio
   ▼
adaptador de canal (TelegramVoiceAdapter / SlackVoiceAdapter)
   │  download seguro (file_id / files.info)
   ▼
voice-service.js  (AudioConverter: FFmpeg → wav 16 kHz mono)
   │
   ▼
whisper-daemon.py (faster-whisper local, modelo carregado UMA vez)
   │  texto transcrito
   ▼
messaging-gateway.processIncoming()  →  agent-orchestrator.handleMessage()
   ▼
Programa da Qualidade / tools MCP (read-only, RLS)
   ▼
resposta em texto (TTS opcional, desativado por defeito)
```

Sem duplicação de regras de negócio: **não existe um segundo processador de voz** — texto e
voz convergem para `handleMessage(message, ...)`.

## Ficheiros

| Ficheiro | Papel |
|---|---|
| `backend/ai/voice-service.js` | Camada de voz: STT local, conversão FFmpeg, TTS (interface), limites/limpeza |
| `backend/ai/whisper-daemon.py` | Daemon Python que carrega o Whisper **uma vez** e transcreve por stdio |
| `backend/ai/telegram-adapter.js` | `downloadFile` (getFile→bytes) + normalize de `message.voice`/`audio` |
| `backend/ai/slack-adapter.js` | `downloadFile` (files.info privado) + deteção de ficheiros `audio/*` (voice clips) |
| `backend/ai/messaging-gateway.js` | Fluxo de voz: download → STT → **mesmo** `handleMessage` → resposta |
| `backend/.env.example` | Variáveis de voz (sem segredos) |

## Requisitos / instalação

- **FFmpeg** (conversão para wav 16 kHz mono): `winget install Gyan.FFmpeg` ou `ffmpeg.org`
- **faster-whisper** (Python) no `python` que o Node invoca (`VOICE_PYTHON`):
  `python -m pip install faster-whisper`
- Verificar: `python -c "import faster_whisper"`

## Configuração (`.env`, nunca versionar segredos)

```ini
# --- Voz (STT local) ---
VOICE_ENABLED=true
STT_PROVIDER=local
STT_MODEL=small            # tiny | base | small | medium  (small recomendado p/ pt-PT)
STT_LANGUAGE=pt            # pt | auto
STT_DEVICE=cpu             # cpu | gpu | auto
STT_COMPUTE_TYPE=int8_float32
VOICE_SHOW_TRANSCRIPTION=true
VOICE_MAX_DURATION_SECONDS=300
VOICE_MAX_FILE_MB=20
VOICE_DELETE_AFTER_PROCESSING=true

# --- TTS (opcional, desativado) ---
TTS_ENABLED=false
TTS_REPLY_MODE=text        # text | audio | both

# --- Motor Python do Whisper (opcional; default `python`) ---
# VOICE_PYTHON=C:\...\python.exe
```

## Funcionamento por canal

### Telegram
- `message.voice` (e `message.audio`) → `file_id` → `getFile` → download → transcreve.
- Responde no mesmo chat. Texto continua intacto.

### Slack (Socket Mode)
- Ficheiros/voice clips com `mimetype audio/*` em `event.files[]` (ou `file` em `message.im`)
  → `files.info` → download privado com o token do bot → transcreve.
- Responde no mesmo DM/canal/thread.

## Segurança e privacidade

- **Local**: nunca envia áudio para OpenAI/Google/Azure sem configuração explícita.
- Nomes temporários aleatórios; **nunca** comandos shell montados com input do utilizador
  (usa `execFile(ffmpeg, [...])` com argumentos separados).
- Limites de duração e tamanho; timeout por download.
- Áudio eliminado após processamento por defeito (`VOICE_DELETE_AFTER_PROCESSING`).
- Sem tokens/segredos em logs; pedidos MCP usam o token de serviço curto do utilizador (RLS).

## Comandos de teste

```bash
cd backend/ai
# transcrição de um ficheiro local (mp3/ogg/wav)
VOICE_ENABLED=true STT_MODEL=tiny node _test_voice.js "/caminho/audio.mp3"
```

## Troubleshooting

- **`int8 compute type not supported`** → usar `STT_DEVICE=cpu` e `STT_COMPUTE_TYPE=int8_float32`.
- **Modelo demora a carregar no 1º pedido** → normal em CPU; depois é reutilizado (daemon).
- **`Cannot find module faster-whisper`** → instalar no `VOICE_PYTHON` usado pelo Node.
- **Transcrição fraca** → trocar `STT_MODEL` para `base`/`small`/`medium` (melhor pt-PT).

## Fases

- ✅ FASE 1 — Telegram Voice → Whisper local → MCP → texto
- ✅ FASE 2 — Slack Audio/Voice Clip → Whisper local → MCP → texto
- ⏳ FASE 3/4 — TTS local opcional (piper), resposta `text|audio|both` (interface preparada, desativado)