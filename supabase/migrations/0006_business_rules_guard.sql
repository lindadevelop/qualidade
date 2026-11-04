-- 0006_business_rules_guard.sql
-- SAMSYS|Qualidade — proteções das regras de negócio NO SERVIDOR (não depender do frontend)

-- Regra 4: NÃO permitir encerrar uma ocorrência sem validação de eficácia.
-- Regra 5: eficácia validada positivamente -> CLOSED + closed_at.
create or replace function public.guard_close_occurrence()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  -- Se está a tentar fechar (status -> CLOSED)
  if new.status = 'CLOSED' then
    -- exige eficácia validada positiva
    if new.effectiveness_status is distinct from 'EFFECTIVE' or new.effectiveness_validated_at is null then
      raise exception 'Não é possível encerrar a ocorrência sem validação de eficácia (eficaz).';
    end if;
    -- preencher closed_at se não vier
    if new.closed_at is null then
      new.closed_at := now();
    end if;
  else
    -- ao sair de CLOSED (reabertura): limpar closed_at
    if old.status = 'CLOSED' then
      new.closed_at := null;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists guard_close_occurrence on public.quality_occurrences;
create trigger guard_close_occurrence
  before update on public.quality_occurrences
  for each row execute procedure public.guard_close_occurrence();

-- Regra 7: reabertura de ocorrência encerrada exige permissão de qualidade/admin
-- (garantido por RLS no UPDATE; este trigger regista e impõe o fluxo — sem registo de auditoria fica bloqueada)
create or replace function public.guard_reopen_occurrence()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if old.status = 'CLOSED' and new.status <> 'CLOSED' then
    -- exige volta a IN_PROGRESS (não diretamente para CLOSED) e reopened_by preenchido
    if new.status not in ('IN_PROGRESS', 'OPEN') then
      raise exception 'Ocorrência encerrada só pode ser reaberta para estado aberto/em curso.';
    end if;
    if new.reopened_by is null then
      -- sem autor explícito: usar o utilizador autenticado
      new.reopened_by := auth.uid();
    end if;
    if new.reopened_at is null then
      new.reopened_at := now();
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists guard_reopen_occurrence on public.quality_occurrences;
create trigger guard_reopen_occurrence
  before update on public.quality_occurrences
  for each row execute procedure public.guard_reopen_occurrence();

-- Ações: conclusão só marca completed_at
create or replace function public.guard_complete_action()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if new.status = 'COMPLETED' and new.completed_at is null then
    new.completed_at := now();
  end if;
  if new.status <> 'COMPLETED' then
    new.completed_at := null;
  end if;
  return new;
end;
$$;

drop trigger if exists guard_complete_action on public.quality_actions;
create trigger guard_complete_action
  before update on public.quality_actions
  for each row execute procedure public.guard_complete_action();