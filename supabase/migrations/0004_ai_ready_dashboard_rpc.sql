-- 0004_ai_ready_dashboard_rpc.sql
-- SAMSYS|Qualidade — preparação estrutural para IA (sem implementar funcionalidades no MVP)
--                    + RPC/views de métricas do dashboard (performance §50)

-- ------------------------------------------------------------------ CATEGORIAS (futuro IA / análise) — opcional no MVP
create table if not exists public.quality_categories (
  id          uuid primary key default gen_random_uuid(),
  name        text not null unique,
  description text,
  parent_id   uuid references public.quality_categories (id),
  active      boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
alter table public.quality_categories enable row level security;
create policy "categories_read_authenticated" on public.quality_categories for select
  using (public.is_any_authenticated());
create policy "categories_write_quality" on public.quality_categories for all
  using (public.is_quality_or_admin()) with check (public.is_quality_or_admin());

create table if not exists public.quality_occurrence_categories (
  occurrence_id uuid not null references public.quality_occurrences (id) on delete cascade,
  category_id   uuid not null references public.quality_categories (id) on delete cascade,
  primary key (occurrence_id, category_id)
);
alter table public.quality_occurrence_categories enable row level security;
create policy "occ_cat_read" on public.quality_occurrence_categories for select using (public.is_any_authenticated());
create policy "occ_cat_write" on public.quality_occurrence_categories for all
  using (public.is_quality_or_admin()) with check (public.is_quality_or_admin());

-- ------------------------------------------------------------------ TAGS (opcional, futuro)
create table if not exists public.quality_tags (
  id         uuid primary key default gen_random_uuid(),
  name       text not null unique,
  created_at timestamptz not null default now()
);
alter table public.quality_tags enable row level security;
create policy "tags_read" on public.quality_tags for select using (public.is_any_authenticated());
create policy "tags_write" on public.quality_tags for all
  using (public.is_quality_or_admin()) with check (public.is_quality_or_admin());

create table if not exists public.quality_occurrence_tags (
  occurrence_id uuid not null references public.quality_occurrences (id) on delete cascade,
  tag_id        uuid not null references public.quality_tags (id) on delete cascade,
  primary key (occurrence_id, tag_id)
);
alter table public.quality_occurrence_tags enable row level security;
create policy "occ_tag_read" on public.quality_occurrence_tags for select using (public.is_any_authenticated());
create policy "occ_tag_write" on public.quality_occurrence_tags for all
  using (public.is_quality_or_admin()) with check (public.is_quality_or_admin());

-- ------------------------------------------------------------------ EMBEDDINGS (pgvector — ativar só se necessário, não no MVP)
-- require: create extension vector;  (opcional, comentado por omissão)
-- create table if not exists public.quality_occurrence_embeddings (
--   id            uuid primary key default gen_random_uuid(),
--   occurrence_id uuid not null references public.quality_occurrences (id) on delete cascade,
--   content       text,
--   embedding     vector(1536),
--   model         text,
--   created_at    timestamptz not null default now(),
--   updated_at    timestamptz not null default now()
-- );

-- ------------------------------------------------------------------ INTERAÇÕES COM IA (registo/medição futura)
create table if not exists public.ai_interactions (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid references public.profiles (id),
  occurrence_id  uuid references public.quality_occurrences (id) on delete set null,
  feature        text,
  provider       text,
  model          text,
  input_reference text,
  result         jsonb,
  accepted       boolean,
  created_at     timestamptz not null default now()
);
alter table public.ai_interactions enable row level security;
create policy "ai_interactions_insert_own" on public.ai_interactions for insert with check (user_id = auth.uid());
create policy "ai_interactions_read_quality" on public.ai_interactions for select using (public.is_quality_or_admin());

-- ------------------------------------------------------------------ FEATURE FLAGS (IA gradual)
create table if not exists public.feature_flags (
  id         uuid primary key default gen_random_uuid(),
  key        text not null unique,
  enabled    boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.feature_flags enable row level security;
create policy "flags_read_authenticated" on public.feature_flags for select using (public.is_any_authenticated());
create policy "flags_write_quality" on public.feature_flags for all
  using (public.is_quality_or_admin()) with check (public.is_quality_or_admin());

insert into public.feature_flags (key) values
  ('ai_similar_occurrences'),
  ('ai_root_cause'),
  ('ai_action_suggestions'),
  ('ai_dashboard_insights'),
  ('ai_assistant'),
  ('ai_effectiveness_analysis')
on conflict (key) do nothing;

-- ------------------------------------------------------------------ RPC METRICAS DO DASHBOARD (§50) — sem descarregar registos
create or replace function public.get_dashboard_metrics()
returns json
language sql stable security definer set search_path = public
as $$
  select json_build_object(
    'open_nc',
      (select count(*) from public.quality_occurrences where type='NC' and status in ('OPEN','IN_PROGRESS','AWAITING_EFFECTIVENESS')),
    'open_om',
      (select count(*) from public.quality_occurrences where type='OM' and status in ('OPEN','IN_PROGRESS','AWAITING_EFFECTIVENESS')),
    'overdue_actions',
      (select count(*) from public.quality_actions where status <> 'COMPLETED' and deadline < current_date),
    'awaiting_effectiveness',
      (select count(*) from public.quality_occurrences where status = 'AWAITING_EFFECTIVENESS'),
    'closed',
      (select count(*) from public.quality_occurrences where status = 'CLOSED'),
    'total_actions_open',
      (select count(*) from public.quality_actions where status <> 'COMPLETED')
  );
$$;

-- Evolução por mês (NC, OM, Encerradas) — anos corridos a partir de dados
create or replace function public.get_occurrence_evolution(months integer default 12)
returns table (period text, type public.occurrence_type, cnt bigint)
language sql stable security definer set search_path = public
as $$
  select to_char(date_trunc('month', created_at), 'YYYY-MM') as period, type, count(*) as cnt
  from public.quality_occurrences
  where created_at >= date_trunc('month', current_date) - (months || ' months')::interval
  group by 1, 2
  order by 1, 2;
$$;

-- Distribuição por estado
create or replace function public.get_occurrences_by_status()
returns table (status public.occurrence_status, cnt bigint)
language sql stable security definer set search_path = public
as $$
  select status, count(*)::bigint as cnt from public.quality_occurrences group by status;
$$;

-- Por origem
create or replace function public.get_occurrences_by_origin()
returns table (origin_name text, cnt bigint)
language sql stable security definer set search_path = public
as $$
  select o.name, count(*)::bigint as cnt from public.quality_occurrences q
  join public.quality_origins o on o.id = q.origin_id
  group by o.name order by 2 desc;
$$;

-- Por área
create or replace function public.get_occurrences_by_area()
returns table (area_name text, cnt bigint)
language sql stable security definer set search_path = public
as $$
  select a.name, count(*)::bigint as cnt from public.quality_occurrences q
  join public.quality_areas a on a.id = q.area_id
  group by a.name order by 2 desc;
$$;

-- Ações por responsável
create or replace function public.get_actions_by_responsible()
returns table (full_name text, total bigint, open_cnt bigint, overdue bigint, completed bigint)
language sql stable security definer set search_path = public
as $$
  select p.full_name,
         count(a.id) as total,
         count(*) filter (where a.status <> 'COMPLETED') as open_cnt,
         count(*) filter (where a.status <> 'COMPLETED' and a.deadline < current_date) as overdue,
         count(*) filter (where a.status = 'COMPLETED') as completed
  from public.profiles p
  left join public.quality_actions a on a.responsible_user_id = p.id
  group by p.id, p.full_name
  order by open_cnt desc;
$$;

-- Ações mais urgentes (atenção: atrasadas | hoje | 1d | 2d | 3d)
create or replace function public.get_urgent_actions(limit_n int default 8)
returns table (
  action_id uuid, action_ref text, action_description text,
  occurrence_ref text, occurrence_id uuid,
  responsible text, deadline date, status public.action_status,
  urgency int
)
language sql stable security definer set search_path = public
as $$
  select a.id, a.reference, a.description,
         o.reference, o.id,
         p.full_name, a.deadline, a.status,
         case
           when a.deadline < current_date then 0
           when a.deadline = current_date then 1
           when a.deadline = current_date + 1 then 2
           when a.deadline = current_date + 2 then 3
           when a.deadline = current_date + 3 then 4
           else 9
         end as urgency
  from public.quality_actions a
  join public.quality_occurrences o on o.id = a.occurrence_id
  left join public.profiles p on p.id = a.responsible_user_id
  where a.status <> 'COMPLETED' and (a.deadline is null or a.deadline <= current_date + 3)
  order by urgency asc, a.deadline asc nulls last
  limit limit_n;
$$;