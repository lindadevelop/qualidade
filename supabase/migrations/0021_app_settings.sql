-- 0021_app_settings.sql
-- Tabela de configurações da aplicação (chave/valor), partilhável entre frontend e backend.
-- O backend (assistente IA, /help) consulta aqui o estado de módulos como o LifeCycle RH.
create table if not exists public.app_settings (
  key        text primary key,
  value      text not null,
  updated_at timestamptz not null default now()
);

alter table public.app_settings enable row level security;

-- leitura autenticada; escrita só quality/admin
drop policy if exists app_settings_read on public.app_settings;
create policy app_settings_read on public.app_settings
  for select using (is_any_authenticated());

drop policy if exists app_settings_write on public.app_settings;
create policy app_settings_write on public.app_settings
  for insert with check (is_quality_or_admin());
create policy app_settings_update on public.app_settings
  for update using (is_quality_or_admin());

-- default: LifeCycle acessível (ativo até ser desativado nas configurações)
insert into public.app_settings (key, value) values ('lifecycle_visivel', 'true')
  on conflict (key) do nothing;

grant select, insert, update on public.app_settings to authenticated;
grant select on public.app_settings to anon;