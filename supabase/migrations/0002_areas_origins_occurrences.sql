-- 0002_areas_origins_occurrences.sql
-- SAMSYS|Qualidade — quality_areas, quality_origins, quality_occurrences + referência + RLS

-- ------------------------------------------------------------------ ÁREAS
create table if not exists public.quality_areas (
  id          uuid primary key default gen_random_uuid(),
  name        text not null unique,
  description text,
  active      boolean not null default true,
  sort_order  integer not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

drop trigger if exists set_quality_areas_updated_at on public.quality_areas;
create trigger set_quality_areas_updated_at
  before update on public.quality_areas
  for each row execute procedure public.set_updated_at();

-- seed inicial de áreas (não hardcoded no frontend, mas existem por omissão)
insert into public.quality_areas (name, description, sort_order) values
  ('Desenvolvimento', 'Equipa de desenvolvimento', 1),
  ('Sistemas', 'Sistemas e infraestrutura', 2),
  ('Comercial', 'Equipa comercial', 3),
  ('Financeiro', 'Área financeira', 4),
  ('PHC', 'Software PHC', 5),
  ('Sage', 'Software Sage', 6),
  ('Logística', 'Logística e expedição', 7),
  ('Administração', 'Administração', 8)
on conflict (name) do nothing;

-- ------------------------------------------------------------------ ORIGENS
create table if not exists public.quality_origins (
  id          uuid primary key default gen_random_uuid(),
  name        text not null unique,
  description text,
  active      boolean not null default true,
  sort_order  integer not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

drop trigger if exists set_quality_origins_updated_at on public.quality_origins;
create trigger set_quality_origins_updated_at
  before update on public.quality_origins
  for each row execute procedure public.set_updated_at();

insert into public.quality_origins (name, description, sort_order) values
  ('Auditoria Interna', 'Auditoria interna à organização', 1),
  ('Auditoria Externa', 'Auditoria externa / certificação', 2),
  ('Reclamação', 'Reclamação de cliente', 3),
  ('Processo Interno', 'Tempo identificada em processo interno', 4),
  ('Revisão pela Gestão', 'Revisão pela direção', 5),
  ('Melhoria Interna', 'Oportunidade de melhoria interna', 6),
  ('Outra', 'Outra origem', 7)
on conflict (name) do nothing;

-- ------------------------------------------------------------------ OCORRÊNCIAS
create type public.occurrence_type as enum ('NC', 'OM');
create type public.occurrence_status as enum ('OPEN', 'IN_PROGRESS', 'AWAITING_EFFECTIVENESS', 'CLOSED');

create table if not exists public.quality_occurrences (
  id                          uuid primary key default gen_random_uuid(),
  reference                   text not null,
  type                        public.occurrence_type not null,
  year                        integer not null,
  origin_id                   uuid not null references public.quality_origins (id),
  occurrence_date             date not null default current_date,
  area_id                     uuid not null references public.quality_areas (id),
  description                 text not null,
  responsible_user_id         uuid references public.profiles (id),
  cause_analysis              text,
  status                      public.occurrence_status not null default 'OPEN',
  effectiveness_status        text,        -- NULL | 'EFFECTIVE' | 'NOT_EFFECTIVE'
  effectiveness_notes         text,
  effectiveness_evidence      jsonb,
  effectiveness_validated_by  uuid references public.profiles (id),
  effectiveness_validated_at  timestamptz,
  closed_at                   timestamptz,
  reopened_at                 timestamptz,
  reopened_by                 uuid references public.profiles (id),
  created_by                  uuid references public.profiles (id),
  created_at                  timestamptz not null default now(),
  updated_at                  timestamptz not null default now(),
  unique (reference)
);

drop trigger if exists set_quality_occurrences_updated_at on public.quality_occurrences;
create trigger set_quality_occurrences_updated_at
  before update on public.quality_occurrences
  for each row execute procedure public.set_updated_at();

-- Gerar referência legível de forma concorrente e sem duplicados
-- Usamos uma tabela de contadores por (tipo, ano) — robusta em concorrência
create table if not exists public.occurrence_counters (
  id         uuid primary key default gen_random_uuid(),
  type       public.occurrence_type not null,
  year       integer not null,
  last_value integer not null default 0,
  unique (type, year)
);

create or replace function public.next_occurrence_reference()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  new_year  integer;
  next_val  integer;
  prefix    text;
begin
  new_year := extract(year from new.occurrence_date)::integer;
  prefix := case when new.type = 'NC' then 'NC-' else 'OM-' end;

  insert into public.occurrence_counters (type, year, last_value)
  values (new.type, new_year, 1)
  on conflict (type, year)
  do update set last_value = public.occurrence_counters.last_value + 1
  returning last_value into next_val;

  new.year := new_year;
  new.reference := prefix || new_year || '-' || lpad(next_val::text, 4, '0');
  return new;
end;
$$;

drop trigger if exists gen_occurrence_reference on public.quality_occurrences;
create trigger gen_occurrence_reference
  before insert on public.quality_occurrences
  for each row when (new.reference is null)
  execute procedure public.next_occurrence_reference();

create index if not exists idx_occurrences_status on public.quality_occurrences (status);
create index if not exists idx_occurrences_type on public.quality_occurrences (type);
create index if not exists idx_occurrences_year on public.quality_occurrences (year);
create index if not exists idx_occurrences_origin on public.quality_occurrences (origin_id);
create index if not exists idx_occurrences_area on public.quality_occurrences (area_id);
create index if not exists idx_occurrences_responsible on public.quality_occurrences (responsible_user_id);
create index if not exists idx_occurrences_date on public.quality_occurrences (occurrence_date);
create index if not exists idx_occurrences_created on public.quality_occurrences (created_at);

-- ------------------------------------------------------------------ RLS
alter table public.quality_areas enable row level security;
alter table public.quality_origins enable row level security;
alter table public.quality_occurrences enable row level security;

-- áreas/origens: leitura para autenticados, escrita para qualidade/admin
create policy "areas_read_authenticated" on public.quality_areas for select
  using (public.is_any_authenticated());
create policy "areas_write_quality_admin" on public.quality_areas for all
  using (public.is_quality_or_admin()) with check (public.is_quality_or_admin());
create policy "origins_read_authenticated" on public.quality_origins for select
  using (public.is_any_authenticated());
create policy "origins_write_quality_admin" on public.quality_origins for all
  using (public.is_quality_or_admin()) with check (public.is_quality_or_admin());

-- ocorrências: leitura para todos os autenticados.
-- NOTA: a policy completa (que considera ações atribuídas ao utilizador) é definida
-- em 0003, depois de quality_actions existir (dependência de ordem).
create policy "occurrences_read_authenticated" on public.quality_occurrences for select
  using (
    public.is_any_authenticated()
    and (
      public.is_quality_or_admin()
      or public.is_management()
      or responsible_user_id = auth.uid()
    )
  );

-- escrita: qualidade/admin gerem tudo
create policy "occurrences_write_quality" on public.quality_occurrences for all
  using (public.is_quality_or_admin()) with check (public.is_quality_or_admin());