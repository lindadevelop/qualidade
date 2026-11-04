-- 0014_import_registry.sql
-- Registo de importação: preserva todos os dados dos Excel e o resultado do
-- mapa por referência, para que nenhum campo se perca por faltar coluna na BD.
-- Idempotente (pode ser aplicado várias vezes).

create table if not exists public.import_registry (
  id            bigint generated always as identity primary key,
  src_file      text not null,            -- nome do ficheiro origem
  sheet         text not null,
  row_num       integer not null,
  reference     text not null,            -- identificador de negócio (Title / ID NC)
  module        text not null,            -- 'action' | 'occurrence'
  kind          text not null,            -- para ocorrências: 'NC' | 'OM'; ações: '-'
  status        text not null,            -- created|updated|unchanged|pending|error
  target_id     uuid,                     -- id criado/atualizado (se aplicável)
  raw_data      jsonb not null,           -- todos os campos do Excel (linha)
  anomalies     jsonb not null default '[]'::jsonb,
  created_at    timestamptz not null default now(),
  unique (src_file, row_num)
);

comment on table public.import_registry is
  'Registo de importação de dados de Gestão da Qualidade a partir de Excel (Ações/NC/OM).';

create index if not exists idx_import_registry_ref on public.import_registry (reference);
create index if not exists idx_import_registry_status on public.import_registry (status);