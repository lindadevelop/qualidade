-- 0019_lifecycle_offboarding.sql
-- Offboarding (B14): encerra o ciclo de vida com checklist de saída por área.
-- Extras no caso: dados de saída e estado do offboarding.

alter table public.lifecycle_casos
  add column if not exists data_saida        date,
  add column if not exists motivo_saida      text,
  add column if not exists estado_offboarding text,  -- null | EM_CURSO | CONCLUIDO
  add column if not exists offboarding_em    timestamptz,
  add column if not exists offboarding_concluido_em timestamptz;

create index if not exists idx_lifecycle_casos_off on public.lifecycle_casos (estado_offboarding);