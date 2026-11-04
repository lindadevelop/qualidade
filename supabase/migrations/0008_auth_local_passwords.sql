-- 0008_auth_local_passwords.sql
-- SAMSYS|Qualidade — auth local (ambiente sem Supabase Cloud).
-- Adiciona password hash ao schema auth para o auth server local validar credenciais.
-- Em Supabase Cloud este ficheiro é OPCIONAL (o Supabase Auth gere auth.users).
alter table auth.users add column if not exists password_hash text;
alter table auth.users add column if not exists role text default 'authenticated';

-- Passwords demo (hash SHA-256 com salt prefixado "sq$") — apenas para dev local.
-- Utilizadores: as credenciais demo são documentadas no README.
update auth.users set password_hash = 'sq$' || encode(sha256(('demo1234' || id::text)::bytea), 'hex')
where password_hash is null;