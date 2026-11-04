# SAMSYS|Qualidade — Architecture

> Sistema de Gestão da Qualidade (NC/OM, planos de ação, eficácia, auditoria, relatórios)
> Frontend: Vue 3 + TypeScript + Vite + Bootstrap 5 + Pinia + Vue Router + ApexCharts + Supabase JS
> Backend: Supabase Cloud (PostgreSQL, Auth, Storage, Realtime, Edge Functions)
> Visual de referência: Vuexy CRM Dashboard (reproduzir a experiência, não copiar código proprietário)

---

## 1. Visão geral
Aplicação web profissional, funcional (não demo), ligada a Supabase Cloud, para centralizar
Não-Conformidades (NC), Oportunidades de Melhoria (OM), planos de ação, evidências, prazos,
validação de eficácia, auditoria/histórico, indicadores, relatórios, utilizadores e permissões.

Regra transversal: **toda a lógica de negócio crítica e de controlo de dados implementada em
PostgreSQL/Supabase, nunca apenas no frontend** (regras §17, RLS §47, segurança §48, performance §49-50).

## 2. Stack

| Camada            | Tecnologia                                                |
|-------------------|-----------------------------------------------------------|
| UI                | Vue 3 (Composition API) + TypeScript + Vite + Bootstrap 5 |
| Estado global     | Pinia                                                     |
| Rotas             | Vue Router (com guards e permissões)                      |
| Gráficos          | ApexCharts                                                |
| Ícones            | Tabler Icons                                              |
| Tabelas           | DataTables / equivalente profissional Vue                 |
| Excel             | SheetJS                                                   |
| PDF               | Geração no browser ou servidor                            |
| Validação         | Zod (frontend e Edge Functions)                           |
| Backend/Auth/BD   | Supabase Cloud (PostgreSQL, Auth, Storage, Realtime)      |
| IA (futuro)       | Serviço abstrato em `src/services/ai/` + Edge Functions   |

## 3. Camadas e regras de separação
- **UI** (`.vue`) — apresentação, sem regras de negócio, sem acesso direto a SQL.
- **Lógica de negócio** — em `src/services/` e no PostgreSQL (triggers, RPC, regras).
- **Acesso Supabase** — `src/lib/supabase.ts` e `src/services/*`. `SUPABASE_SERVICE_ROLE_KEY`
  **nunca** é colocado no frontend (só Edge Functions / server-side).
- **Tipos** — gerados de Supabase (`supabase gen types typescript`) + tipos de domínio.
- **Validação** — Zod no frontend e nas Edge Functions.

## 4. Modelo de negócio e fluxo de estados
Entidades núcleo: `profiles`, `quality_areas`, `quality_origins`, `quality_occurrences` (NC/OM),
`quality_actions`, `quality_attachments`, `quality_comments`, `audit_log`, `notifications`.
Suporte futuro IA: `quality_categories`, `quality_tags`, `quality_occurrence_embeddings`,
`ai_interactions`, `feature_flags` (ver DATABASE.md).

Estado da ocorrência: `OPEN → IN_PROGRESS → AWAITING_EFFECTIVENESS → CLOSED` (+ `reopened_at`).
Transições controladas por regras de negócio (triggers/RPC no PostgreSQL) — §17.

## 5. Autenticação e perfis
- **Supabase Auth**: login, logout, recuperação/alteração de password, perfil, sessão persistente,
  proteção de rotas, controlo de permissões, tratamento de sessão expirada. **Sem registo público**.
- **Perfis iniciais** (extensível):
  - `QUALIDADE` (admin funcional) — acesso total.
  - `RESPONSÁVEL DA AÇÃO` — apenas as próprias ações/ocorrências associadas.
  - `LÍDER/DIREÇÃO` — consulta/leitura (dashboard, indicadores, relatórios).
  - `admin` (técnico) — administração do sistema.
- RLS: `Administrador/Qualidade` lê/edita tudo; `ActionOwner` lê autorizado e atualiza as próprias
  ações; `Management` read-only. Tudo em migrations.

## 6. Segurança
- `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY` no frontend; `SUPABASE_SERVICE_ROLE_KEY` só server-side.
- RLS obrigatório em todas as tabelas (nunca confiar só na interface).
- Evidências em bucket privado `quality-evidence`, com URLs assinados/temporários, nunca públicos.
- Erros técnicos Supabase nunca expostos diretamente; tratamento centralizado + log.

## 7. Performance
- Índices PostgreSQL em: `status, type, year, origin_id, area_id, responsible_user_id,
  occurrence_date, deadline, occurrence_id, created_at` (§49).
- Dashboard: **não** descarregar milhares de registos; usar views/RPC que devolvem métricas
  sumaarizadas (§50). Evitar N+1.

## 8. Arquitetura da pasta de frontend
```
src/
  components/   (reutilizáveis: cards, tabelas, badges, timeline, modais, etc.)
  layouts/      (sidebar, navbar, dark mode)
  pages/        (routes: dashboard, occurrences, actions, eficácia, relatórios, admin, etc.)
  router/       (rotas + guards)
  stores/       (Pinia: auth, perfil, notificações, filtros globais)
  composables/
  services/     (supabase, dashboard, occurrences, actions, reports, import, ai)
  lib/          (supabase, format, auth helpers)
  types/        (+ gerados do Supabase)
  utils/        (formatação de prazos, badges, etc.)
  modules/      (dashboard, occurrences, actions, reports, administration, audit)
```

## 9. Backend / Supabase
- `supabase/migrations/` — schema completo, RLS, triggers, RPC, índices (criável automaticamente).
- `supabase/functions/` — Edge Functions (IA, exportação pesada, importação de histórico).
- `supabase/seed.sql` — dados demo (10 utilizadores, 30 ocorrências, ~70 ações).
- Regras de negócio, sequência de referências (`NC-2026-0001`), auditoria e RLS implementadas em SQL.

## 10. Preparação para IA (fase futura, sem implementar no MVP) — §72–104
- A IA é **assistiva, nunca decisória**: nunca cria/elimina/encerra NC, valida eficácia, altera
  responsáveis/prazos, reabre ocorrências ou elimina evidências autonomamente.
- Abstração `AIService` (`findSimilarOccurrences()`, `suggestCategories()`, ...). Provider agnósticos.
- IA **apenas server-side** (Edge Functions), nunca API keys no frontend, nunca contorna RLS.
- Respostas IA sempre JSON estruturado, validado server-side.
- Feature flags para ativar funcionalidades gradualmente.
- Estrutura de dados já extensível: categorias/tags (opcionais no MVP), pgvector (não ativo no MVP),
  `ai_interactions`, `quality_occurrence_embeddings`, sanearização de dados antes do envio.

## 11. Fases de implementação (estratégia)
- **FASE 1** — Análise + `ARCHITECTURE.md`, `DATABASE.md`, `IMPLEMENTATION_PLAN.md` (este documento).
- **FASE 2** — Projeto, layout Vuexy, autenticação, Supabase, schema completo e RLS.
- **FASE 3** — Dashboard, NC/OM, ficha de ocorrência, plano de ações.
- **FASE 4** — Eficácia, anexos, histórico, notificações e Realtime.
- **FASE 5** — Relatórios, exportação, importação de histórico, administração.
- **FASE 6** — Testes, otimização e polish UI.

Cada fase termina com build limpo, lint e testes (quando aplicável) e resumo de: o que foi
desenvolvido, ficheiros criados/alterados, migrations adicionadas, funcionalidades concluídas,
problemas e próximos passos.