# Estado Funcional — SAMSYS|Qualidade com Plataforma Estratégica v1.5

**Data:** 2026-09-30  
**Versão testada (registo original):** v1.5 passos 1-4
**Foco:** exclusivamente SAMSYS|Qualidade (AssistSys e gestsys mantidos funcionalmente, não desenvolvidos)

---

## Atualização de desenvolvimento — 2026-10-01

As sete páginas antes assinaladas como em desenvolvimento/planeadas dispõem agora de gestão funcional, com migração 0052. Ver [módulos operacionais](modulos-operacionais-v1_5.md) para funcionalidades, testes e limitações dos conectores externos.

## Atualização de desenvolvimento — 2026-09-30

O utilizador confirmou que o push anterior já foi efetuado. Foram desenvolvidos os workflows e correções descritos em [workflows-v1_5.md](workflows-v1_5.md), com migração 0051 e testes de domínio, SQL, navegador e exportação. As secções abaixo conservam o diagnóstico anterior como histórico; o estado de instalação/serviços deve ser consultado na nota de instalação da nova entrega.

## 1. Stack em funcionamento

| Serviço | Porta local | Estado |
|---------|-------------|--------|
| PostgreSQL | 5432 | ✓ a aceitar ligações |
| PostgREST | 3001 | ✓ 200 |
| Auth server | 3002 | ✓ login devolve token |
| API proxy | 8000 | ✓ a reencaminhar /auth, /rest, /ppt |
| PPT generator | 3007 | ✓ health 200, gera .pptx |
| Frontend SAMSYS | 5178 | ✓ preview ativo |
| AssistSys | 8090 | ✓ túnel ativo |
| gestsys | 3000 | ✓ túnel ativo (com ressalvas de conflito de porta) |

**Túneis Cloudflare (voláteis):**
- SAMSYS|Qualidade: `https://progressive-suburban-entity-twelve.trycloudflare.com`
- AssistSys: `https://sandra-obtaining-adjustments-closed.trycloudflare.com`
- gestsys: `https://org-diy-society-mold.trycloudflare.com`

---

## 2. Funcionalidades entregues (passos 1-4)

### 2.1 Documentação e arquitetura
- Criada estrutura `docs/v1_5-strategy-platform/` com:
  - `README.md` — índice e escopo
  - `coverage/coverage-matrix-v1.md` — matriz de cobertura dos requisitos v1.5
  - `architecture/data-model-v1.md` — modelo de dados estendido
  - `architecture/execution-plan-v1.md` — fases A-E
  - `decisions/decision-log-v1.md` — registo de decisões
  - `tests/estado-funcional-v1.md` — este documento

### 2.2 Modelo de dados
Aplicada migration `supabase/migrations/0050_strategy_platform_v1_5.sql` com as tabelas:
- `organizations`
- `strategic_cycles`
- `strategic_pillars`
- `swot_campaigns`
- `swot_items`
- `tows_crossings`
- `risk_opportunities`
- `strategic_objectives`
- `strategic_actions`
- `kpis`, `kpi_targets`, `kpi_results`
- `meetings`, `decisions`
- `brand_kits`
- `generated_files`
- `app_versions`, `feature_flags`

Seed aplicado com:
- 2 organizações: Samsys e AcmeCorp
- 1 campanha SWOT demo
- 1 risco, 1 objetivo, 1 KPI, 1 reunião

### 2.3 Frontend — rotas e páginas
Todas as rotas abaixo carregam (200 OK) e apresentam UI:
- `/login` — autenticação
- `/dashboard` — dashboard principal
- `/estrategia` e `/estrategia/swot` — SWOT interativo
- `/estrategia/tows` — TOWS
- `/estrategia/riscos` — Riscos e Oportunidades
- `/estrategia/plano` — Plano Estratégico
- `/estrategia/kpis` — KPIs
- `/reunioes` — Reuniões
- `/apresentacoes` — Apresentações e geração de PPT
- `/administracao` com tab "Estratégia v1.5" para ativar/desativar o módulo

### 2.4 SWOT funcional
- Seleção de campanha por organização
- Visualização em 4 quadrantes (Forças, Fraquezas, Oportunidades, Ameaças)
- Criar/editar/eliminar itens SWOT
- Campos: título, descrição, impacto, probabilidade
- Dados persistidos em `swot_items`

### 2.5 Brand Engine
- `useBrandKit.ts` aplica cores da organização a CSS variables em runtime
- Fallback para tema padrão Samsys
- `useOrganization.ts` mantém organização ativa no localStorage

### 2.6 Geração de PowerPoint
- Serviço Node `backend/ppt-generator.js` (:3007)
- Template Python `backend/ppt-template.py` com python-pptx
- Endpoint `POST /ppt/generate` — gera .pptx a partir da organização
- Endpoint `GET /ppt/download/<id>` — download do ficheiro
- Registo do ficheiro gerado em `generated_files`
- Tamanho típico: ~40 KB
- Testado com sucesso localmente e via túnel Cloudflare

### 2.7 Admin v1.5
- Tab "Estratégia v1.5" na Administração
- Toggle para mostrar/ocultar o módulo no menu
- Estado persistido em `app_settings` e localStorage

---

## 3. Testes realizados

### 3.1 Rotas (via túnel Cloudflare)
Todas responderam 200:
```
/login                    200
/estrategia               200
/estrategia/swot          200
/estrategia/tows          200
/estrategia/riscos        200
/estrategia/plano         200
/estrategia/kpis          200
/apresentacoes            200
/reunioes                 200
```

### 3.2 API / autenticação
- Login via `/auth/v1/token?grant_type=password` — 200, devolve access_token
- Listagem de organizações via `/rest/v1/organizations` — 200, 2 organizações
- Campanhas SWOT via `/rest/v1/swot_campaigns` — 200

### 3.3 Geração de PPT
- `POST /ppt/generate` com `organization_id` — 200
- Download do .pptx gerado — 200, `Content-Type: application/vnd.openxmlformats-officedocument.presentationml.presentation`, ~40 KB

### 3.4 Build de produção
- `npm run build` — concluído com sucesso (`✓ built in 1.71s`)
- Preview levantado sobre a build de produção

---

## 4. Ficheiros criados / alterados

### Criados
- `frontend/src/types/strategy.ts`
- `frontend/src/services/strategy.ts`
- `frontend/src/composables/useOrganization.ts`
- `frontend/src/composables/useBrandKit.ts`
- `frontend/src/pages/strategy/StrategySwotPage.vue`
- `frontend/src/pages/strategy/StrategyTowsPage.vue`
- `frontend/src/pages/strategy/StrategyRisksPage.vue`
- `frontend/src/pages/strategy/StrategyPlanPage.vue`
- `frontend/src/pages/strategy/StrategyKpiPage.vue`
- `frontend/src/pages/strategy/PresentationsPage.vue`
- `frontend/src/pages/strategy/MeetingsPage.vue`
- `backend/ppt-generator.js`
- `backend/ppt-template.py`

### Alterados
- `backend/api-proxy.js` — adicionada rota `/ppt -> :3007`
- `frontend/vite.config.ts` — proxy `/ppt` no preview
- `frontend/src/router/index.ts` — novas rotas estratégia + admin
- `frontend/src/layouts/AppLayout.vue` — menu e seletor de organização
- `frontend/src/pages/AdminPage.vue` — tab Estratégia v1.5
- `frontend/src/stores/settings.ts` — toggle strategyVisivel
- `frontend/src/style.css` — ajustes de variáveis
- `frontend/src/types/database.ts` — tipos complementares

---

## 5. Limitações e ressalvas

1. **Túneis Cloudflare são voláteis.** Se o túnel do SAMSYS mudar, é necessário atualizar `frontend/.env` com o novo URL e refazer `npm run build`.
2. **Serviços não são persistentes como serviço Windows.** O api-proxy (:8000) e o ppt-generator (:3007) foram reiniciados manualmente; não sobrevivem a reboot sem os scripts de arranque automático.
3. **gestsys na porta 3000 entra em conflito com o WhatsApp connector do Hermes.** O processo do Hermes ressuscita e ocupa `127.0.0.1:3000`, fazendo o gestsys cair. Solução provisória: matar o processo do Hermes e reiniciar o preview do gestsys. Solução definitiva: mudar o gestsys para outra porta (ex: 3001) ou configurar o Hermes para não usar a 3000.
4. **Processos background iniciados por subagent morrem quando ele termina.** Foi necessário reiniciar manualmente api-proxy, ppt-generator e preview após conclusão do subagent.
5. **Páginas TOWS, Riscos, Plano e KPIs são estruturais.** Têm UI e CRUD service, mas ainda não foram preenchidas com workflows completos de validação humana.
6. **Push anterior concluído**, confirmado pelo utilizador em 2026-09-30.

---

## 6. Próximos passos sugeridos

1. **Validar UI interativa do SWOT** com dados reais e corrigir eventuais bugs de UX.
2. **Completar workflows:** TOWS cruzamentos, Riscos (matriz de impacto/probabilidade), Plano (objetivos → ações), KPIs (targets e resultados).
3. **Adicionar validação humana obrigatória** antes de persistir alterações críticas (regra: "IA nunca decisória").
4. **Estabilizar serviços** com arranque automático via scripts/VBS ou outra porta para o gestsys.
5. **Testar exportação PPT** com conteúdos reais e melhorar o template visual.
6. **Push anterior concluído.** Esta nova entrega tem alterações próprias a rever e versionar.

---

## 7. Credenciais

Todas as credenciais, tokens, chaves API e passwords permanecem fora deste documento. Ver ficheiros `.env` locais e `postgrest.conf`, que não devem ser versionados.

## 2026-10-01 — Administração e limpeza independente

- Hierarquia aplicada: único superadministrador `geral@samsys.pt`; administradores por empresa; utilizadores por empresa e permissões de Qualidade, LifeCycle e Estratégia.
- Migração 0053 aplicada: utilizadores e dados legados associados à Samsys; sessões versionadas; edição de utilizadores e senhas.
- Migração 0054 aplicada: limpeza operacional independente por empresa/programa em Administração → Limpeza de dados, com contagens, frase de confirmação e senha.
- Preserva configurações, utilizadores, auditorias e ficheiros físicos; remove referências operacionais. Dependências externas e CV ativos bloqueiam a limpeza.
- Validação: 162 verificações transacionais revertidas e formulário no navegador; compilação de produção concluída. Nenhuma limpeza real executada.


## Atualização 01/10/2026 — Qualidade v2.5

Candidato `0.5.0-rc.1` disponível no funil existente. Fluxo Auditoria → NC/OM → tratamento → ações/evidências → eficácia/encerramento implementado e testado, incluindo aprovações, prazos, anulação, reabertura e isolamento por empresa. 50 verificações de integração e E2E com API real passaram. Migrations 0055/0056 aplicadas sem eliminar dados.

Estado de produção: pendente de UAT, configuração/validação SMTP e validação operacional. Não confundir candidato de testes com release aprovada. Relatório completo: `IMPLEMENTATION_REPORT_V2_5.md`; operação e UAT: `docs/quality-v2_5/OPERACAO_E_UAT.md`.

## Atualização 0.5.0-rc.4 — 04/10/2026
Deltas Qualidade e Estratégia publicados. Estado por requisito e limites documentados em docs/quality-v2_5/Estado_Deltas_rc4.md. Migrações 0059, 0060 e 0061; 103 verificações de integração, 16 testes unitários, 9 verificações de percursos no navegador e 14 verificações de acesso local/público aprovadas. Logótipo oficial Samsys pendente do ficheiro original. Aceitação humana por realizar com o guia Word.

## Atualização 06/10/2026 — Plataforma Estratégica rc5

Delta PE-D01 a PE-D11 implementado conforme relatório `docs/quality-v2_5/Estado_Delta_Estrategia_rc5.md`. Novas campanhas usam áreas temáticas, quotas por participante/contexto, submissão final e validação da organização/equipa destino antes da consolidação. Campanhas anteriores mantêm regras originais explicitamente identificadas. Proteções de equipas/ciclos, filtros de membros, tipografia e histórico reforçados. 121 testes de integração, 16 unitários, 10 verificações no navegador e 14 de acesso/leitura aprovados. Guia não técnico rc5 disponível. O PDF de 02/10 reenviado coincide com o DOCX anteriormente tratado (119 parágrafos comparados). Configuração dos ativos no kit predefinido Samsys continua a confirmar; funcionalidade de upload considerada encerrada por PE-D01.

## REV02 publicada em 07/10/2026 — 0.5.0-rc.6

Aplicada a migração 0063 com cópia de segurança e preservação dos registos existentes. Novas campanhas têm blocos por equipa e um bloco corporativo, progresso nominal, conclusão com exceção auditada e importação contextual por linha. Incluídas correções de administração transversal, identidade visual, descrição opcional e proteção de templates usados. Campanhas anteriores preservam as regras originais; rascunhos sem contributos podem ser atualizados.

Validação: 135 verificações de integração, 16 testes unitários, 19 verificações de navegador/visuais e 14 verificações locais/públicas passaram. Recuperação de senha com SMTP local e novo login passou; envio externo no ambiente público pendente de configuração. Estado por ID, evidências e ficheiros em `docs/quality-v2_5/Estado_REV02_rc6.md`.
