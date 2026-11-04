-- 0013_ai_search_text.sql — Adiciona pesquisa de texto livre à RPC do assistente IA
-- (referência ou descrição) — filtro parametrizado, respeita RLS (security invoker).
drop function if exists public.ai_occurrence_search(text[], text, text, text, text, date, date, boolean, int);
drop function if exists public.ai_occurrence_search(text[], text, text, text, text, date, date, boolean, text, int);

create or replace function public.ai_occurrence_search(
  p_status text[] default null,
  p_type text default null,
  p_area_name text default null,
  p_origin_name text default null,
  p_responsible_name text default null,
  p_date_from date default null,
  p_date_to date default null,
  p_unassigned boolean default false,
  p_search text default null,
  p_limit int default 100
)
returns table (
  id uuid, reference text, type text, status text, occurrence_date date,
  created_at timestamptz, updated_at timestamptz, closed_at timestamptz,
  description text, cause_analysis text, effectiveness_status text,
  area_name text, origin_name text, responsible_name text
)
language sql
security invoker
set search_path = public, auth
as $fn$
  select
    q.id, q.reference, q.type::text, q.status::text, q.occurrence_date,
    q.created_at, q.updated_at, q.closed_at, q.description, q.cause_analysis,
    q.effectiveness_status,
    a.name as area_name, o.name as origin_name, p.full_name as responsible_name
  from public.quality_occurrences q
  left join public.quality_areas   a on a.id = q.area_id
  left join public.quality_origins o on o.id = q.origin_id
  left join public.profiles        p on p.id = q.responsible_user_id
  where
    (p_status is null or q.status = any(p_status::public.occurrence_status[]))
    and (p_type is null or q.type::text = p_type)
    and (p_area_name is null or a.name ilike '%' || p_area_name || '%')
    and (p_origin_name is null or o.name ilike '%' || p_origin_name || '%')
    and (p_responsible_name is null or p.full_name ilike '%' || p_responsible_name || '%')
    and (p_date_from is null or q.occurrence_date >= p_date_from)
    and (p_date_to is null or q.occurrence_date <  p_date_to)
    and (not p_unassigned or q.responsible_user_id is null)
    and (p_search is null or q.reference ilike '%' || p_search || '%' or q.description ilike '%' || p_search || '%')
  order by q.occurrence_date desc
  limit p_limit
$fn$;

grant execute on function public.ai_occurrence_search to anon, authenticated, service_role;