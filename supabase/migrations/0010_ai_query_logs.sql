-- 0010_ai_query_logs.sql
-- SAMSYS|Qualidade — registo de utilização do Assistente IA (§21)
-- Guarda pergunta, intent, filtros não sensíveis, modelo, duração, estado e n.º de registos.
-- NÃO guarda respostas completas nem dados sensíveis por omissão.

create table if not exists public.ai_query_logs (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid references public.profiles (id) on delete set null,
  question        text,
  intent          text,
  filters         jsonb,
  model           text,
  duration_ms     integer,
  status          text not null default 'success',   -- success | error | rejected_sql | rejected_plan
  rows_processed  integer,
  error           text,
  created_at      timestamptz not null default now()
);

create index if not exists idx_ai_logs_user on public.ai_query_logs (user_id);
create index if not exists idx_ai_logs_created on public.ai_query_logs (created_at);

alter table public.ai_query_logs enable row level security;

-- qualidade/admin (acesso total) consultam os logs; o próprio utilizador vê os seus
create policy "ai_logs_read_own" on public.ai_query_logs for select
  using (user_id = auth.uid());
create policy "ai_logs_read_quality" on public.ai_query_logs for select
  using (public.is_quality_or_admin());

-- insert: o servidor AI grava logs (conexão interna como postgres; RLS não se aplica nessa via).
-- Para utilizadores via API, exigir autenticação.
create policy "ai_logs_insert" on public.ai_query_logs for insert
  with check (true);