-- 0017_lifecycle.sql
-- Modelo de dados LifeCycle RH (núcleo P0: B01/B02/B03).
-- Caso = candidatura/colaborador/estágio com LifeCycle ID único, estado e tarefas.

-- estados de caso (máquina de estados do ciclo de vida)
do $$ begin
  create type lifecycle_case_type as enum ('recrutamento','estagio','colaborador');
exception when duplicate_object then null; end $$;
do $$ begin
  create type lifecycle_case_status as enum (
    'CANDIDATURA_RECEBIDA','NA_FILA','EM_TRIAGEM','ENTREVISTA','SELECIONADO',
    'NAO_SELECIONADO','PRE_ADMISSAO','ADMISSAO_EM_PREPARACAO','READY_DAY1',
    'ATIVO','OFFBOARDING','ENCERRADO'
  );
exception when duplicate_object then null; end $$;

create table if not exists public.lifecycle_vagas (
  id            uuid primary key default gen_random_uuid(),
  reference     text not null unique,        -- VG-2026-001
  titulo        text not null,
  departamento  text,
  funcao        text,
  local         text,
  tipo          text not null default 'colaborador',   -- colaborador | estagio
  motivo        text,
  data_desejada date,
  estado        text not null default 'APROVACAO_PENDENTE',  -- APROVACAO_PENDENTE|APROVADA|PUBLICADA|ENCERRADA
  aprovador       uuid references public.profiles(id),
  aprovado_em     timestamptz,
  created_by      uuid references public.profiles(id),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create table if not exists public.lifecycle_casos (
  id               uuid primary key default gen_random_uuid(),
  reference        text not null unique,     -- LCY-2026-XXXXXX (LifeCycle ID)
  vaga_id          uuid references public.lifecycle_vagas(id),
  nome             text not null,
  email            text,
  telefone         text,
  origem           text,                     -- vaga | espontanea
  fonte            text,                     -- linkedin, recomendação, portal, ...
  tipo             lifecycle_case_type not null default 'recrutamento',
  estado           lifecycle_case_status not null default 'CANDIDATURA_RECEBIDA',
  cv_url           text,
  consentimento    boolean not null default false,
  consentimento_em timestamptz,
  score            integer,
  decisao_triagem  text,
  motivo_encerramento text,
  data_entrada     date,
  funcao           text,
  equipa           text,
  dados            jsonb not null default '{}'::jsonb,   -- ficha de identificação / dados estruturados
  created_by       uuid references public.profiles(id),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create table if not exists public.lifecycle_tarefas (
  id              uuid primary key default gen_random_uuid(),
  caso_id         uuid not null references public.lifecycle_casos(id) on delete cascade,
  titulo          text not null,
  descricao       text,
  responsavel     uuid references public.profiles(id),
  sector          text,                      -- rh | comunicacao | sistemas | logistica | financeiro | lider | enterprise-phc
  due_date        date,
  status          text not null default 'TODO',   -- TODO|IN_PROGRESS|COMPLETED
  sla_atraso      boolean not null default false,
  created_by      uuid references public.profiles(id),
  created_at      timestamptz not null default now(),
  completed_at    timestamptz
);

create index if not exists idx_lifecycle_casos_estado on public.lifecycle_casos (estado);
create index if not exists idx_lifecycle_casos_vaga on public.lifecycle_casos (vaga_id);
create index if not exists idx_lifecycle_casos_email on public.lifecycle_casos (email);
create index if not exists idx_lifecycle_tarefas_caso on public.lifecycle_tarefas (caso_id);
create index if not exists idx_lifecycle_tarefas_status on public.lifecycle_tarefas (status);

-- RLS: leitura p/ autenticados; escrita RH/admin (semelhante ao resto da app)
alter table public.lifecycle_vagas enable row level security;
alter table public.lifecycle_casos enable row level security;
alter table public.lifecycle_tarefas enable row level security;

-- grants aos roles do PostgREST (a RLS continua a restringir por policy)
grant select, insert, update, delete on public.lifecycle_vagas, public.lifecycle_casos, public.lifecycle_tarefas to anon, authenticated;

drop policy if exists lc_vagas_read on public.lifecycle_vagas;
drop policy if exists lc_vagas_write on public.lifecycle_vagas;
create policy lc_vagas_read on public.lifecycle_vagas for select using (is_any_authenticated());
create policy lc_vagas_write on public.lifecycle_vagas for all to authenticated using (is_quality_or_admin()) with check (is_quality_or_admin());

drop policy if exists lc_casos_read on public.lifecycle_casos;
drop policy if exists lc_casos_write on public.lifecycle_casos;
create policy lc_casos_read on public.lifecycle_casos for select using (is_any_authenticated());
create policy lc_casos_write on public.lifecycle_casos for all to authenticated using (is_quality_or_admin()) with check (is_quality_or_admin());

drop policy if exists lc_tarefas_read on public.lifecycle_tarefas;
drop policy if exists lc_tarefas_write on public.lifecycle_tarefas;
create policy lc_tarefas_read on public.lifecycle_tarefas for select using (is_any_authenticated());
create policy lc_tarefas_write on public.lifecycle_tarefas for all to authenticated using (is_quality_or_admin()) with check (is_quality_or_admin());

-- trigger updated_at
drop trigger if exists set_lifecycle_vagas_updated_at on public.lifecycle_vagas;
create trigger set_lifecycle_vagas_updated_at before update on public.lifecycle_vagas
  for each row execute function set_updated_at();
drop trigger if exists set_lifecycle_casos_updated_at on public.lifecycle_casos;
create trigger set_lifecycle_casos_updated_at before update on public.lifecycle_casos
  for each row execute function set_updated_at();