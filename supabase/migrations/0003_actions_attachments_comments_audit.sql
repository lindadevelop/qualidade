-- 0003_actions_attachments_comments_audit.sql
-- SAMSYS|Qualidade — quality_actions, quality_attachments, quality_comments,
--                      audit_log, notifications + RLS + regras de negócio

-- ------------------------------------------------------------------ AÇÕES
create type public.action_status as enum ('TODO', 'IN_PROGRESS', 'COMPLETED');

create table if not exists public.quality_actions (
  id                  uuid primary key default gen_random_uuid(),
  reference           text not null unique,
  occurrence_id       uuid not null references public.quality_occurrences (id) on delete cascade,
  description         text not null,
  responsible_user_id uuid references public.profiles (id),
  deadline            date,
  status              public.action_status not null default 'TODO',
  completed_at        timestamptz,
  created_by          uuid references public.profiles (id),
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

drop trigger if exists set_quality_actions_updated_at on public.quality_actions;
create trigger set_quality_actions_updated_at
  before update on public.quality_actions
  for each row execute procedure public.set_updated_at();

create sequence if not exists public.seq_action_ref start 1;

create or replace function public.next_action_reference()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare next_val integer;
begin
  next_val := nextval('public.seq_action_ref');
  new.reference := 'ACT-' || lpad(next_val::text, 5, '0');
  return new;
end;
$$;

drop trigger if exists gen_action_reference on public.quality_actions;
create trigger gen_action_reference
  before insert on public.quality_actions
  for each row when (new.reference is null)
  execute procedure public.next_action_reference();

create index if not exists idx_actions_occurrence on public.quality_actions (occurrence_id);
create index if not exists idx_actions_responsible on public.quality_actions (responsible_user_id);
create index if not exists idx_actions_status on public.quality_actions (status);
create index if not exists idx_actions_deadline on public.quality_actions (deadline);

-- ------------------------------------------------------------------ ANEXOS
create table if not exists public.quality_attachments (
  id            uuid primary key default gen_random_uuid(),
  occurrence_id uuid references public.quality_occurrences (id) on delete cascade,
  action_id     uuid references public.quality_actions (id) on delete cascade,
  file_name     text not null,
  file_path     text not null,
  file_type     text,
  file_size     bigint,
  description   text,
  uploaded_by   uuid references public.profiles (id),
  created_at    timestamptz not null default now()
);

create index if not exists idx_attachments_occurrence on public.quality_attachments (occurrence_id);
create index if not exists idx_attachments_action on public.quality_attachments (action_id);

-- ------------------------------------------------------------------ COMENTÁRIOS
create table if not exists public.quality_comments (
  id            uuid primary key default gen_random_uuid(),
  occurrence_id uuid not null references public.quality_occurrences (id) on delete cascade,
  action_id     uuid references public.quality_actions (id) on delete cascade,
  comment       text not null,
  created_by    uuid references public.profiles (id),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
drop trigger if exists set_quality_comments_updated_at on public.quality_comments;
create trigger set_quality_comments_updated_at
  before update on public.quality_comments
  for each row execute procedure public.set_updated_at();

-- ------------------------------------------------------------------ AUDIT LOG
create table if not exists public.audit_log (
  id             uuid primary key default gen_random_uuid(),
  entity_type    text not null,
  entity_id      uuid,
  action         text not null,
  old_data       jsonb,
  new_data       jsonb,
  changed_fields jsonb,
  user_id        uuid references public.profiles (id),
  created_at     timestamptz not null default now()
);

create index if not exists idx_audit_entity on public.audit_log (entity_type, entity_id);
create index if not exists idx_audit_created on public.audit_log (created_at);

-- trigger de auditoria genérico
create or replace function public.log_audit()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  changes jsonb := '{}'::jsonb;
  key text;
  old_v text; new_v text; entity_t text; act text;
begin
  entity_t := tg_table_name;
  if tg_op = 'INSERT' then
    act := 'create';
  elsif tg_op = 'UPDATE' then
    act := 'update';
  elsif tg_op = 'DELETE' then
    act := 'delete';
    insert into public.audit_log (entity_type, entity_id, action, old_data, user_id)
    values (entity_t, old.id, act, to_jsonb(old), auth.uid());
    return new;
  end if;

  if tg_op = 'UPDATE' then
    for key in select k from jsonb_object_keys(to_jsonb(new)) k loop
      old_v := coalesce((to_jsonb(old))->>key, '');
      new_v := coalesce((to_jsonb(new))->>key, '');
      if old_v <> new_v then
        changes := changes || jsonb_build_object(key, jsonb_build_object('old', old_v, 'new', new_v));
      end if;
    end loop;
    insert into public.audit_log (entity_type, entity_id, action, old_data, new_data, changed_fields, user_id)
    values (entity_t, new.id, act, to_jsonb(old), to_jsonb(new), changes, auth.uid());
  else
    insert into public.audit_log (entity_type, entity_id, action, new_data, user_id)
    values (entity_t, new.id, act, to_jsonb(new), auth.uid());
  end if;
  return new;
end;
$$;

-- anexar auditoria a alterações críticas das ocorrências e ações
drop trigger if exists audit_occurrences on public.quality_occurrences;
create trigger audit_occurrences
  after insert or update or delete on public.quality_occurrences
  for each row execute procedure public.log_audit();

drop trigger if exists audit_actions on public.quality_actions;
create trigger audit_actions
  after insert or update or delete on public.quality_actions
  for each row execute procedure public.log_audit();

-- ------------------------------------------------------------------ NOTIFICAÇÕES
create table if not exists public.notifications (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles (id) on delete cascade,
  type        text not null,
  title       text not null,
  message     text,
  entity_type text,
  entity_id   uuid,
  read        boolean not null default false,
  created_at  timestamptz not null default now()
);

create index if not exists idx_notifications_user on public.notifications (user_id, read);

-- ------------------------------------------------------------------ REGRAS DE NEGÓCIO (triggers) — §17
-- Regra 6: ação concluída NÃO significa ocorrência encerrada.
-- Regra 2: se tiver ações ativas → IN_PROGRESS.
-- Regra 3: quando TODAS as ações concluídas → AWAITING_EFFECTIVENESS.
create or replace function public.update_occurrence_status_from_actions()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  target      uuid;
  total_cnt   integer;
  done_cnt    integer;
  cur_status  public.occurrence_status;
begin
  target := coalesce(new.occurrence_id, old.occurrence_id);
  if target is null then return coalesce(new, old); end if;

  select count(*), count(*) filter (where status = 'COMPLETED')
    into total_cnt, done_cnt
    from public.quality_actions where occurrence_id = target;

  select status into cur_status from public.quality_occurrences where id = target;

  if total_cnt > 0 then
    if done_cnt = total_cnt then
      -- todas concluídas → aguardar eficácia (a não ser que já encerrada)
      if cur_status <> 'CLOSED' and cur_status <> 'AWAITING_EFFECTIVENESS' then
        update public.quality_occurrences
          set status = 'AWAITING_EFFECTIVENESS' where id = target;
      end if;
    else
      -- há ações por concluir → IN_PROGRESS
      if cur_status <> 'CLOSED' and cur_status <> 'AWAITING_EFFECTIVENESS' then
        update public.quality_occurrences
          set status = 'IN_PROGRESS' where id = target;
      end if;
    end if;
  end if;
  return coalesce(new, old);
end;
$$;

drop trigger if exists actions_update_occurrence_status on public.quality_actions;
create trigger actions_update_occurrence_status
  after insert or update or delete on public.quality_actions
  for each row execute procedure public.update_occurrence_status_from_actions();

-- ------------------------------------------------------------------ RLS
alter table public.quality_actions enable row level security;
alter table public.quality_attachments enable row level security;
alter table public.quality_comments enable row level security;
alter table public.audit_log enable row level security;
alter table public.notifications enable row level security;

-- ocorrências: policy adicional — o responsável de uma ação pode ler a ocorrência respetiva
create policy "occurrences_read_as_action_owner" on public.quality_occurrences for select
  using (
    public.is_any_authenticated()
    and exists (
      select 1 from public.quality_actions a
      where a.occurrence_id = public.quality_occurrences.id
        and a.responsible_user_id = auth.uid()
    )
  );

-- ações: leitura autenticados; escrita qualidade/admin; action_owner atualiza as próprias
create policy "actions_read_authenticated" on public.quality_actions for select
  using (public.is_any_authenticated());
create policy "actions_write_quality" on public.quality_actions for all
  using (public.is_quality_or_admin()) with check (public.is_quality_or_admin());
create policy "actions_update_own" on public.quality_actions for update
  using (responsible_user_id = auth.uid())
  with check (responsible_user_id = auth.uid());

-- anexos: leitura autenticados; escrita qualidade/admin ou autor
create policy "attachments_read_authenticated" on public.quality_attachments for select
  using (public.is_any_authenticated());
create policy "attachments_write_quality" on public.quality_attachments for all
  using (public.is_quality_or_admin()) with check (public.is_quality_or_admin());
create policy "attachments_write_own" on public.quality_attachments for insert
  with check (uploaded_by = auth.uid());

-- comentários: leitura autenticados; escrita autenticados
create policy "comments_read_authenticated" on public.quality_comments for select
  using (public.is_any_authenticated());
create policy "comments_write_authenticated" on public.quality_comments for insert
  with check (created_by = auth.uid());

-- audit: quality/admin lêem tudo; restantes leem audit de ENTITIES a que têm acesso (simplificado: leem o seu próprio)
create policy "audit_read_quality_admin" on public.audit_log for select
  using (public.is_quality_or_admin());
create policy "audit_read_own" on public.audit_log for select
  using (user_id = auth.uid());

-- notificações: só o dono lê/atualiza
create policy "notifications_read_own" on public.notifications for select
  using (user_id = auth.uid());
create policy "notifications_update_own" on public.notifications for update
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "notifications_insert_own" on public.notifications for insert
  with check (user_id = auth.uid());