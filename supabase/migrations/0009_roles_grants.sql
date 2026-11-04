-- 0009_roles_grants.sql
-- SAMSYS|Qualidade — grants para as roles usadas pelo API (PostgREST/anon/authenticated/service_role)
-- Necessário para o stack local funcionar; também inofensivo em Supabase Cloud.
do $$
begin
  if not exists (select 1 from pg_roles where rolname='anon') then create role anon nologin; end if;
  if not exists (select 1 from pg_roles where rolname='authenticated') then create role authenticated nologin; end if;
  if not exists (select 1 from pg_roles where rolname='service_role') then create role service_role nologin bypassrls; end if;
end
$$;

grant usage on schema public to anon, authenticated, service_role;
grant all on schema public to anon, authenticated, service_role;
grant all on all tables in schema public to anon, authenticated, service_role;
grant all on all sequences in schema public to anon, authenticated, service_role;
grant all on all functions in schema public to anon, authenticated, service_role;

-- funções e schema auth (auth.uid())
grant usage on schema auth to anon, authenticated, service_role;
grant execute on all functions in schema auth to anon, authenticated, service_role;