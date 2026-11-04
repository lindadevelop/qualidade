-- 0018_lifecycle_admissao.sql
-- Gate "Ready for Day 1" e tarefas de admissão A01-A20 (núcleo P0: B07/B13, ADM-P0-04/06).
-- Cada caso pode ter uma admissão com data de entrada; tarefas têm prazo, setor,
-- prioridade de gate (P0/P1) e dependência, para o gate ser bloqueado por pendências críticas.

-- extras na tarefa
alter table public.lifecycle_tarefas
  add column if not exists gate      text,          -- 'P0' | 'P1' | 'CONDICIONAL'
  add column if not exists depends_on uuid references public.lifecycle_tarefas(id) on delete set null,
  add column if not exists sla_ms    integer;       -- prazo SLA em minutos (opcional)

-- extras no caso (admissão)
alter table public.lifecycle_casos
  add column if not exists data_entrada      date,
  add column if not exists tipo_vinculo      text,   -- 'colaborador' | 'estagio'
  add column if not exists estado_admissao   text,   -- null | EM_PREPARACAO | READY_DAY1 | ATIVO
  add column if not exists ready_day1_flag   boolean not null default false,
  add column if not exists ready_day1_em     timestamptz;

-- index útil
create index if not exists idx_lifecycle_tarefas_caso_gate on public.lifecycle_tarefas (caso_id, gate);
create index if not exists idx_lifecycle_casos_admissao on public.lifecycle_casos (estado_admissao);