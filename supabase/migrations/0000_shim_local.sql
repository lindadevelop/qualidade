-- Shim para correr as migrations SAMSYS|Qualidade num PostgreSQL puro (sem Supabase).
-- Imita o schema `auth` e as funções que as migrations esperam. NÃO usar em produção Supabase.
create schema if not exists auth;

create table if not exists auth.users (
  id uuid primary key,
  email text,
  raw_user_meta_data jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Supabase auth.uid() — retorna o id do utilizador autenticado.
-- Local: lê current_setting('request.jwt.claims'), senão NULL.
create or replace function auth.uid()
returns uuid
language sql stable
as $$
  select (current_setting('request.jwt.claims', true)::jsonb ->> 'sub')::uuid
$$;

-- Vista/auxiliar de users não é usada pelas migrations diretamente, mas fica disponível.