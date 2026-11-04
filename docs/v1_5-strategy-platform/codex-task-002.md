# Codex Task 002 — Passos 1-4 da Plataforma Estratégica v1.5 no SAMSYS|Qualidade

## Contexto
- Repositório: `C:\a\samsys-qualidade`
- Stack: Vue 3 + TypeScript + Vite + Bootstrap 5 + Pinia + PostgREST local portátil + PostgreSQL 17
- Túnel ativo SAMSYS: `https://progressive-suburban-entity-twelve.trycloudflare.com`
- `.env` frontend já atualizado com o URL do túnel.
- Migration `0050_strategy_platform_v1_5.sql` e seed `seed_v1_5.sql` aplicados.
- Páginas placeholder já existem em `frontend/src/pages/strategy/` e `frontend/src/pages/admin/`.

## Objetivo desta tarefa
Implementar os passos 1, 2, 3 e 4:

### Passo 1 — SWOT funcional
- Criar composable/service `frontend/src/services/strategy.ts` com funções CRUD para:
  - `organizations`, `swot_campaigns`, `swot_items`
- Tornar `StrategySwotPage.vue` funcional:
  - Listar campanhas da organização ativa.
  - Ao selecionar uma campanha, mostrar os 4 quadrantes (Forças, Fraquezas, Oportunidades, Ameaças).
  - Permitir adicionar/editar/remover itens SWOT dentro de cada quadrante.
  - Campos: título, descrição, impacto (baixo/médio/alto), probabilidade, equipa impactada.
- Usar a tabela `organizations` para definir a "organização ativa" (guardar em `localStorage` ou Pinia store).

### Passo 2 — Brand Engine aplicado na UI
- Ler o `brand_kits` da organização ativa via API.
- Aplicar cores dinamicamente via CSS variables no `:root` (primary, secondary, background, text, accent, fonts).
- Atualizar `AppLayout.vue`, `LoginPage.vue` e páginas estratégicas para usar as CSS variables.
- Criar `frontend/src/composables/useBrandKit.ts`.
- Garantir fallback para o tema Samsys atual quando não houver Brand Kit.

### Passo 3 — Percurso SWOT → TOWS → Riscos → Plano → KPI
- Criar serviços para `tows_crossings`, `risk_opportunities`, `strategic_objectives`, `strategic_actions`, `kpis`, `kpi_targets`, `kpi_results`.
- Tornar funcionais as páginas:
  - `StrategyTowsPage.vue`: gerar cruzamentos SO/ST/WO/WT a partir dos itens SWOT; listar/editar propostas.
  - `StrategyRisksPage.vue`: listar/criar riscos e oportunidades derivados de itens SWOT ou TOWS.
  - `StrategyPlanPage.vue`: listar objetivos estratégicos e ações associadas.
  - `StrategyKpiPage.vue`: listar KPIs, metas e resultados; gráfico simples com ApexCharts.
- Criar fluxo de navegação sequencial entre páginas (botões "Próximo" / "Anterior").

### Passo 4 — POC PowerPoint real
- Criar endpoint no backend `backend/ppt-generator.js` usando `python-pptx` (via shell exec de Node) para gerar `.pptx` a partir de:
  - Dados da organização ativa
  - Itens SWOT
  - Riscos/Oportunidades
  - Objetivos/KPIs
  - Decisões/Reunião
- Endpoint: `POST /ppt/generate` — recebe JSON com `organization_id` e `meeting_id` (opcional), devolve URL do ficheiro gerado.
- Guardar ficheiros em `backend/generated-pptx/`.
- Criar página `PresentationsPage.vue` com botão "Gerar PPT" e download.
- Adicionar rota/proxy no `api-proxy.js` se necessário.

## Regras
- NÃO matar processos de AssistSys `:8090` nem gestsys `:3000`.
- Podes reiniciar apenas o preview SAMSYS `:5178` se necessário.
- Antes de fazer build, verifica se `frontend/.env` tem `VITE_SUPABASE_URL` correto.
- Não persistir segredos em ficheiros.
- Não fazer git push.
- Ao terminar, devolver: ficheiros criados/alterados, estado do build, URLs testados.
