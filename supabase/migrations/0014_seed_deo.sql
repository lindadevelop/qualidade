-- 0014_seed_deo.sql — Cria o utilizador local deo@samsys.pt (qualidade)
-- Credencial demo local (auth-server local; sq$ = sha256(password + id)).
-- Idempotente: só cria se ainda não existir (email). Reutilizável.
do $$
declare
  uid uuid;
begin
  if exists (select 1 from auth.users where email = 'deo@samsys.pt') then
    raise notice 'utilizador deo@samsys.pt já existe; a manter.';
    return;
  end if;

  uid := gen_random_uuid();
  insert into auth.users (id, email, raw_user_meta_data, password_hash, role)
  values (
    uid, 'deo@samsys.pt', '{"full_name":"Deo"}',
    'sq$' || encode(sha256(('123456789' || uid::text)::bytea),'hex'),
    'authenticated'
  );
  insert into public.profiles (id, full_name, email, role, active)
  values (uid, 'Deo', 'deo@samsys.pt', 'quality', true);
  raise notice 'criado deo@samsys.pt (id %)', uid;
end $$;