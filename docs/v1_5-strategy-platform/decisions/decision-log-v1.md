# Log de Decisões — Plataforma Estratégica Samsys v1.5

## 2026-09-30 — Passos 1-4 implementados

### Decisão 0: Foco exclusivo em SAMSYS|Qualidade
- **Contexto:** Utilizador pediu "foca-te apenas na qualidade, pf".
- **Decisão:** Desenvolver apenas SAMSYS|Qualidade. AssistSys e gestsys são mantidos funcionais, não desenvolvidos.
- **Impacto:** Passos 1-4 da Plataforma Estratégica foram implementados no SAMSYS|Qualidade.

### Decisão 1: Implementação manual (subagent Codex sem créditos)
- **Contexto:** O subagent Codex falhou com `HTTP 402 Insufficient account funds` no trabalho anterior.
- **Decisão:** Continuar a implementação manualmente, guiando um novo subagent com instruções muito específicas.
- **Impacto:** O novo subagent conseguiu implementar os passos 1-4 com sucesso, mas os processos background que iniciou (api-proxy, ppt-generator, preview) morreram quando ele terminou.

### Decisão 2: Processos SAMSYS reiniciados manualmente
- **Contexto:** Subagent inicia serviços em background; estes são terminados quando o subagent finaliza.
- **Decisão:** Reiniciar `api-proxy` (:8000), `ppt-generator` (:3007) e `npm run preview` (:5178) manualmente nesta sessão.
- **Impacto:** Todos os endpoints voltaram a responder 200; PPT gera e faz download via túnel.

### Decisão 3: Porta 3000 — gestsys vs WhatsApp connector do Hermes
- **Contexto:** O processo `whatsapp-connector` do Hermes ressuscita e ocupa `127.0.0.1:3000`, impedindo o gestsys.
- **Decisão:** Matar o processo do Hermes e reiniciar o preview do gestsys na porta 3000.
- **Risco:** O WhatsApp connector pode voltar a ocupar a porta 3000. Se isso acontecer, o gestsys cai novamente.
- **Possível solução futura:** Mudar o gestsys para outra porta (ex: 3001) e atualizar o túnel, ou configurar o Hermes para usar outra porta.

### Decisão 4: Vite preview proxy para `/ppt`
- **Contexto:** O frontend precisa de aceder ao serviço de PPT em `/ppt/generate` e `/ppt/download/<id>`.
- **Decisão:** Adicionar proxy no `vite.config.ts` do preview para encaminhar `/ppt` para `http://127.0.0.1:8000` (api-proxy), que por sua vez encaminha para `http://127.0.0.1:3007` (ppt-generator).
- **Impacto:** A geração de PPT funciona tanto localmente como via túnel Cloudflare.
