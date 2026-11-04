-- 0020_lifecycle_avancado.sql
-- Blocos restantes: B09 (deduplicação), B11 (comunicações E01-E12), B12 (protocolo estágio).

-- Registo de comunicações (catálogo E01-E12): cada envio/geração deixa evidência ligada ao caso.
create table if not exists public.lifecycle_comunicacoes (
  id           bigint generated always as identity primary key,
  caso_id      uuid references public.lifecycle_casos(id) on delete cascade,
  ref          text not null,                 -- E01..E12 ou livre
  tipo         text not null,                 -- email | tarefa | integracao
  destino      text,
  template     text,
  estado       text not null default 'PENDENTE',  -- PENDENTE | ENVIADO | ERRO
  payload      jsonb not null default '{}'::jsonb,
  enviado_em   timestamptz,
  erro         text,
  created_at   timestamptz not null default now(),
  unique (caso_id, ref)
);

-- hash de deduplicação no caso (candidato + contacto) para sinalizar duplicados
alter table public.lifecycle_casos
  add column if not exists dedup_hash text,
  add column if not exists duplicado_de  uuid references public.lifecycle_casos(id) on delete set null,
  add column if not exists aviso_duplicado boolean not null default false;

create index if not exists idx_lifecycle_casos_dedup on public.lifecycle_casos (dedup_hash);
create index if not exists idx_lifecycle_comunicacoes_caso on public.lifecycle_comunicacoes (caso_id);

-- grants (RLS: leitura autenticada, escrita RH/admin — igual às restantes lifecycle_*)
alter table public.lifecycle_comunicacoes enable row level security;
grant select, insert, update, delete on public.lifecycle_comunicacoes to anon, authenticated;

drop policy if exists lc_com_read on public.lifecycle_comunicacoes;
drop policy if exists lc_com_write on public.lifecycle_comunicacoes;
create policy lc_com_read on public.lifecycle_comunicacoes for select using (is_any_authenticated());
create policy lc_com_write on public.lifecycle_comunicacoes for all to authenticated using (is_quality_or_admin()) with check (is_quality_or_admin());