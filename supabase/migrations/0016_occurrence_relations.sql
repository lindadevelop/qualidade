-- 0016_occurrence_relations.sql
-- Relações entre ocorrências (ex.: "NC relacionada" / recorrência).
-- A fonte Excel indica relações pelo identificador (ex. NC-2022-002);
-- guardamos de forma tipada e idempotente, sem apagar outras.
create table if not exists public.quality_occurrence_relations (
  id          bigint generated always as identity primary key,
  occurrence_id   uuid not null references public.quality_occurrences(id) on delete cascade,
  related_occurrence_id uuid not null references public.quality_occurrences(id) on delete cascade,
  relation_type text not null default 'related',   -- 'related' | 'recurrence'
  created_at  timestamptz not null default now(),
  unique (occurrence_id, related_occurrence_id, relation_type)
);
comment on table public.quality_occurrence_relations is
  'Relação entre ocorrências de qualidade (ex.: NC relacionada/recorrência).';
create index if not exists idx_occurrence_relations_occ on public.quality_occurrence_relations (occurrence_id);