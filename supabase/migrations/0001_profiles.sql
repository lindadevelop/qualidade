-- 0001_profiles.sql
-- SAMSYS|Qualidade — profiles + trigger handle_new_user + RLS

-- Extensão para UUIDs
create extension if not exists "pgcrypto";

-- Handle de novo utilizador: cria profile a partir de auth.users
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name, avatar_url)
  values (
    new.id,
    new.email,
    new.raw_user_meta_data ->> 'full_name',
    new.raw_user_meta_data ->> 'avatar_url'
  );
  return new;
end;
$$;

-- Garantir que a roles permitidas são controladas (evitar valores inválidos)
do $$
begin
  if not exists (select 1 from pg_type where typname = 'profile_role') then
    create type public.profile_role as enum ('quality', 'action_owner', 'management', 'admin');
  end if;
end;
$$;

create table if not exists public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  full_name   text,
  email       text,
  avatar_url  text,
  role        public.profile_role not null default 'management',
  department  text,
  job_title   text,
  active      boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- trigger foto de novo user
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- updated_at
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_profiles_updated_at on public.profiles;
create trigger set_profiles_updated_at
  before update on public.profiles
  for each row execute procedure public.set_updated_at();

-- ------- RLS --------
alter table public.profiles enable row level security;

-- helper: o utilizador é quality ou admin?
create or replace function public.is_quality_or_admin()
returns boolean
language sql
stable
security definer set search_path = public, auth
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and active = true and role in ('quality', 'admin')
  );
$$;

create or replace function public.is_any_authenticated()
returns boolean
language sql
stable
security definer set search_path = public, auth
as $$
  select auth.uid() is not null
$$;

-- management (Líder/Direção) é read-only mas lê tudo (§47)
create or replace function public.is_management()
returns boolean
language sql
stable
security definer set search_path = public, auth
as $$
  select exists (
    select 1 from public.profiles where id = auth.uid() and active = true and role = 'management'
  );
$$;

-- profile pode ser lido por qualquer autenticado (para mostrar responsáveis)
create policy "profiles_read_authenticated"
  on public.profiles for select
  using (public.is_any_authenticated());

-- qualidade/admin podem editar todos
create policy "profiles_write_quality_admin"
  on public.profiles for update
  using (public.is_quality_or_admin())
  with check (public.is_quality_or_admin());

-- utilizador pode editar o próprio perfil (exceto role, controlado por trigger/RLS)
create policy "profiles_write_own"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- apenas qualidade/admin podem criar utilizadores (insert)
create policy "profiles_insert_quality_admin"
  on public.profiles for insert
  with check (public.is_quality_or_admin());