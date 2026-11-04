# SAMSYS|Qualidade — Sistema de Gestão da Qualidade

Aplicação web para centralizar Não Conformidades (NC), Oportunidades de Melhoria (OM), planos de
ação, evidências, prazos, eficácia, auditoria, indicadores e relatórios.
Visual inspirado no dashboard **Vuexy** (experiência visual, sem código proprietário).
Backend: **Supabase Cloud** (PostgreSQL, Auth, Storage, Realtime). Frontend: **Vue 3 + TypeScript + Vite + Bootstrap 5**.

> **Qualidade que se vê. Melhoria que se acompanha.**

---

## Stack
- **Frontend**: Vue 3 (Composition API) + TypeScript + Vite + Bootstrap 5 + Pinia + Vue Router + ApexCharts + Tabler Icons + Zod + SheetJS
- **Backend**: Supabase Cloud — PostgreSQL (schema + RLS + triggers + RPC), Auth, Storage (bucket privado `quality-evidence`), Realtime (notificações)
- **IA (futuro)**: serviço abstrato `src/services/ai/` + Edge Functions (provider-agnostic, sempre assistiva, nunca decisória)

## Requisitos
- Node.js ≥ 18 e npm
- Conta/projeto Supabase Cloud
- Supabase CLI ≥ 2.x (opcional, para migrations locais)

## Instalação

### 1. Frontend
```bash
cd frontend
npm install
cp .env.example .env   # preenche VITE_SUPABASE_URL e VITE_SUPABASE_ANON_KEY
npm run dev            # desenvolvimento em http://localhost:5173
npm run build          # build de produção (dist/)
npm run preview        # servir o build
```

### 2. Configuração Supabase
1. Cria um projeto em https://supabase.com.
2. Em *Project Settings → API*, obtém:
   - `URL` → `VITE_SUPABASE_URL`
   - `anon public` key → `VITE_SUPABASE_ANON_KEY`
3. (Opcional) `SUPABASE_SERVICE_ROLE_KEY` **apenas server-side / Edge Functions — nunca no frontend**.

### 3. Aplicar migrations e seed
As migrations estão em `supabase/migrations/` (0001–0005). Criam todo o schema, RLS, triggers,
RPC e o `seed.sql` demo. Aplica pelo painel Supabase → SQL Editor (uma por vez, pela ordem) ou via CLI:
```bash
supabase link --project-ref <ref>
supabase db push
```

### 4. Primeiro utilizador / Administrador
Sem registo público. O 1º utilizador com perfil `quality`/`admin` pode ser criado pelo painel
Supabase → Authentication → Users, e depois atribuída a role no perfil (ou via RPC `is_admin`).
As passwords nunca são guardadas no git.

## Variáveis de ambiente
Nunca commitar o `.env`:
```
VITE_SUPABASE_URL=
VITE_SUPABASE_ANON_KEY=
```
> `SUPABASE_SERVICE_ROLE_KEY` só em Edge Functions/backend dedicado; nunca exposto ao browser.

## Migrations (resumo)
- `0001_profiles.sql` — profiles + trigger `handle_new_user` + RLS
- `0002_areas_origins_occurrences.sql` — áreas, origens, ocorrências NC/OM + referência concorrente (`NC-2026-0001`) + RLS
- `0003_actions_attachments_comments_audit.sql` — ações, anexos, comentários, audit_log, notificações + regras de negócio (triggers) + RLS
- `0004_ai_ready_dashboard_rpc.sql` — preparação IA (categorias/tags/ai_interactions/feature_flags) + RPC do dashboard
- `0005_seed.sql` — dados demo (10 utilizadores, 30 ocorrências, ~70 ações)

## Regras de negócio (no PostgreSQL, não no frontend)
1. Ocorrência começa `OPEN`
2. Com ações ativas → `IN_PROGRESS`
3. Todas as ações concluídas → `AWAITING_EFFECTIVENESS`
4. Não encerrar sem validação de eficácia
5. Eficácia positiva → `CLOSED` + `closed_at`
6. Ação concluída ≠ ocorrência encerrada
7. Reabertura só por autorizado
8. Reabertura registada em audit_log

## Perfis e permissões (RLS)
- `QUALIDADE` / `admin` — acesso total (gerir, validar eficácia, administrar)
- `RESPONSÁVEL DA AÇÃO` — as próprias ações/ocorrências associadas (sem validar eficácia nem encerrar)
- `LÍDER/DIREÇÃO` — leitura (dashboard, indicadores, relatórios)

## Desenvolvimento
- Separar **UI / lógica de negócio / acesso Supabase / tipos / validação** (`src/` modular).
- Lógica de negócio crítica sempre no PostgreSQL; nunca depender do frontend.
- `supabase gen types typescript --project-id <ref> > src/types/database.ts` para regenerar tipos.
- Erros Supabase tratados centralizadamente (nunca expor detalhe técnico ao utilizador).

## Build / Deploy
- `npm run build` produz `dist/` (estático). Pode ser servido por qualquer host estático (Vercel, Netlify, S3, etc.).
- Edge Functions para IA/exportação pesada ficam em `supabase/functions/`.

## Testes de regras (validação)
- Ocorrência com ação aberta não fecha.
- Todas as ações concluídas → `AWAITING_EFFECTIVENESS`.
- Sem eficácia validada não fecha.
- Eficácia aprovada → `CLOSED`.
- ActionOwner não valida eficácia nem edita ações de outrem.
- Management read-only.

## Roadmap IA
Ver `AI_ROADMAP.md`. A IA é **assistiva, nunca decisória** (não cria/encerra NC, não valida eficácia,
não altera responsáveis/prazos); apenas analisa, compara, sugere e resume, sempre sob confirmação humana.