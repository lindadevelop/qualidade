-- 0012_ai_channels.sql — Camada de canais externos (Telegram/WhatsApp) segura
-- - external_ai_identities : ligação de utilizadores internos a identidades de canal
-- - ai_action_logs          : auditoria de tools de escrita (e confirmations pending lá abaixo)
-- - ai_pending_actions      : ações pendentes de confirmação humana (Fase 5)
-- Tudo resolving para o schema real (occurrences NC/OM, áreas, origens, perfis).

-- ---------------------------------------------------------------------------
-- 1) external_ai_identities
-- ---------------------------------------------------------------------------
create table if not exists public.external_ai_identities (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references auth.users(id) on delete cascade,
  channel           text not null check (channel in ('telegram','whatsapp','teams','slack','web')),
  external_user_id  text not null,          -- telegram user_id / whatsapp phone / sessão web
  external_chat_id  text,                    -- chat/thread quando aplicável
  external_phone_hash text,                 -- hash do nº telefone (WhatsApp), sem plaintext
  verified_at       timestamptz default now(),
  revoked_at        timestamptz,
  is_active         boolean default true,
  last_seen_at      timestamptz,
  created_at        timestamptz default now(),
  updated_at        timestamptz default now(),
  unique(channel, external_user_id)
);
alter table public.external_ai_identities enable row level security;

-- ---------------------------------------------------------------------------
-- 2) ai_action_logs — auditoria de actions MCP (read e write mais tarde)
-- ---------------------------------------------------------------------------
create table if not exists public.ai_action_logs (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid references auth.users(id) on delete set null,
  channel       text,                      -- telegram | whatsapp | web | mcp
  tool_name     text not null,
  target_type   text,
  target_id     uuid,
  confirmation_id uuid,
  result_status text,                      -- ok | denied | error | pending | confirmed | cancelled | expired
  created_at    timestamptz default now()
);
alter table public.ai_action_logs enable row level security;

-- ---------------------------------------------------------------------------
-- 3) ai_pending_actions — escrita pendente de confirmação humana (Fase 5)
-- ---------------------------------------------------------------------------
create table if not exists public.ai_pending_actions (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null references auth.users(id) on delete cascade,
  channel             text,
  conversation_id     text,
  tool_name           text not null,
  payload_json        jsonb not null default '{}'::jsonb,
  confirmation_token_hash text not null,
  status              text not null default 'pending'
                      check (status in ('pending','confirmed','cancelled','expired','executed','failed')),
  expires_at          timestamptz not null,
  confirmed_at        timestamptz,
  executed_at         timestamptz,
  created_at          timestamptz default now()
);
alter table public.ai_pending_actions enable row level security;
create index if not exists idx_pending_user on public.ai_pending_actions(user_id, status);
create index if not exists idx_pending_token on public.ai_pending_actions(confirmation_token_hash);

-- ---------------------------------------------------------------------------
-- RLS — somente o próprio utilizador (e admins) vê os seus canais/ações
-- ---------------------------------------------------------------------------
create or replace function public.is_admin_user(uid uuid) returns boolean security definer language sql stable as $$
  select exists (
    select 1 from public.profiles p
    where p.id = uid and p.role in ('admin','quality')
  );
$$;

do $$
begin
  -- external_ai_identities
  drop policy if exists ext_ai_self on public.external_ai_identities;
  create policy ext_ai_self on public.external_ai_identities
    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
  drop policy if exists ext_ai_admin on public.external_ai_identities;
  create policy ext_ai_admin on public.external_ai_identities
    for select using (public.is_admin_user(auth.uid()));
  -- ai_action_logs
  drop policy if exists ai_action_self on public.ai_action_logs;
  create policy ai_action_self on public.ai_action_logs
    for select using (auth.uid() = user_id);
  drop policy if exists ai_action_admin on public.ai_action_logs;
  create policy ai_action_admin on public.ai_action_logs
    for all using (public.is_admin_user(auth.uid())) with check (public.is_admin_user(auth.uid()));
  -- ai_pending_actions
  drop policy if exists pend_self on public.ai_pending_actions;
  create policy pend_self on public.ai_pending_actions
    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
  drop policy if exists pend_admin on public.ai_pending_actions;
  create policy pend_admin on public.ai_pending_actions
    for all using (public.is_admin_user(auth.uid())) with check (public.is_admin_user(auth.uid()));
end $$;

-- grants (usado pelo PostgREST com o token do utilizador)
grant usage on schema public to anon, authenticated, service_role;
grant select, insert, update, delete on public.external_ai_identities to authenticated, service_role;
grant select, insert, update on public.ai_pending_actions to authenticated, service_role;
grant select on public.ai_action_logs to authenticated, service_role;
grant execute on function public.is_admin_user(uuid) to anon, authenticated, service_role;