--
-- PostgreSQL database dump
--

\restrict kExQtnl0C24c41r7dNklXr1AcOIu68AckFduVFw649txACWjIuLJQVJsnYbEYil

-- Dumped from database version 17.11
-- Dumped by pg_dump version 17.11

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: auth; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA auth;


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: action_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.action_status AS ENUM (
    'TODO',
    'IN_PROGRESS',
    'COMPLETED',
    'BLOCKED',
    'VALIDATING',
    'CANCELLED'
);


--
-- Name: action_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.action_type AS ENUM (
    'CONTENCAO',
    'CORRETIVA',
    'PREVENTIVA',
    'MELHORIA',
    'FORMACAO',
    'ALTERACAO_DOCUMENTAL',
    'ALTERACAO_PROCESSO',
    'VERIFICACAO',
    'VALIDACAO_EFICACIA',
    'OUTRA'
);


--
-- Name: compliance_plan_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.compliance_plan_status AS ENUM (
    'RASCUNHO',
    'PROPOSTO',
    'ATIVO',
    'BLOQUEADO',
    'EM_VALIDACAO',
    'CONCLUIDO',
    'CANCELADO'
);


--
-- Name: connector_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.connector_status AS ENUM (
    'active',
    'inactive',
    'error'
);


--
-- Name: decision_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.decision_status AS ENUM (
    'proposed',
    'approved',
    'rejected',
    'implemented'
);


--
-- Name: effectiveness_result; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.effectiveness_result AS ENUM (
    'effective',
    'not_effective',
    'pending'
);


--
-- Name: generated_file_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.generated_file_status AS ENUM (
    'queued',
    'processing',
    'ready',
    'error'
);


--
-- Name: kpi_direction; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.kpi_direction AS ENUM (
    'higher_is_better',
    'lower_is_better',
    'target'
);


--
-- Name: kpi_frequency; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.kpi_frequency AS ENUM (
    'daily',
    'weekly',
    'monthly',
    'quarterly',
    'yearly'
);


--
-- Name: lifecycle_case_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.lifecycle_case_status AS ENUM (
    'CANDIDATURA_RECEBIDA',
    'NA_FILA',
    'EM_TRIAGEM',
    'ENTREVISTA',
    'SELECIONADO',
    'NAO_SELECIONADO',
    'PRE_ADMISSAO',
    'ADMISSAO_EM_PREPARACAO',
    'READY_DAY1',
    'ATIVO',
    'OFFBOARDING',
    'ENCERRADO'
);


--
-- Name: lifecycle_case_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.lifecycle_case_type AS ENUM (
    'recrutamento',
    'estagio',
    'colaborador'
);


--
-- Name: meeting_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.meeting_status AS ENUM (
    'scheduled',
    'in_progress',
    'completed',
    'cancelled'
);


--
-- Name: occurrence_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.occurrence_status AS ENUM (
    'OPEN',
    'IN_PROGRESS',
    'AWAITING_EFFECTIVENESS',
    'CLOSED'
);


--
-- Name: occurrence_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.occurrence_type AS ENUM (
    'NC',
    'OM'
);


--
-- Name: profile_role; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.profile_role AS ENUM (
    'quality',
    'action_owner',
    'management',
    'admin'
);


--
-- Name: project_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.project_status AS ENUM (
    'draft',
    'planning',
    'active',
    'on_hold',
    'completed',
    'cancelled'
);


--
-- Name: risk_opportunity_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.risk_opportunity_status AS ENUM (
    'identified',
    'analyzing',
    'mitigating',
    'monitored',
    'closed'
);


--
-- Name: risk_opportunity_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.risk_opportunity_type AS ENUM (
    'risk',
    'opportunity'
);


--
-- Name: strategic_action_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.strategic_action_status AS ENUM (
    'todo',
    'in_progress',
    'completed',
    'cancelled'
);


--
-- Name: strategic_objective_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.strategic_objective_status AS ENUM (
    'draft',
    'approved',
    'active',
    'achieved',
    'cancelled'
);


--
-- Name: submission_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.submission_status AS ENUM (
    'draft',
    'submitted',
    'under_review',
    'approved',
    'rejected'
);


--
-- Name: swot_quadrant; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.swot_quadrant AS ENUM (
    'strengths',
    'weaknesses',
    'opportunities',
    'threats'
);


--
-- Name: tows_strategy_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.tows_strategy_type AS ENUM (
    'so',
    'wo',
    'st',
    'wt'
);


--
-- Name: uid(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.uid() RETURNS uuid
    LANGUAGE sql STABLE
    AS $$
 SELECT (nullif(current_setting('request.jwt.claims',true),'')::jsonb ->> 'sub')::uuid
$$;


--
-- Name: access_admin(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.access_admin() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
 SELECT public.session_valid() AND EXISTS(SELECT 1 FROM profiles WHERE id=auth.uid() AND is_super_admin)
$$;


--
-- Name: ai_occurrence_search(text[], text, text, text, text, date, date, boolean, text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ai_occurrence_search(p_status text[] DEFAULT NULL::text[], p_type text DEFAULT NULL::text, p_area_name text DEFAULT NULL::text, p_origin_name text DEFAULT NULL::text, p_responsible_name text DEFAULT NULL::text, p_date_from date DEFAULT NULL::date, p_date_to date DEFAULT NULL::date, p_unassigned boolean DEFAULT false, p_search text DEFAULT NULL::text, p_limit integer DEFAULT 100) RETURNS TABLE(id uuid, reference text, type text, status text, occurrence_date date, created_at timestamp with time zone, updated_at timestamp with time zone, closed_at timestamp with time zone, description text, cause_analysis text, effectiveness_status text, area_name text, origin_name text, responsible_name text)
    LANGUAGE sql
    SET search_path TO 'public', 'auth'
    AS $$
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
$$;


--
-- Name: assignments_integrity(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.assignments_integrity() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM profiles WHERE id=NEW.user_id AND organization_id=NEW.organization_id) OR (NEW.team_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM teams WHERE id=NEW.team_id AND organization_id=NEW.organization_id)) THEN RAISE EXCEPTION 'Atribuição de outra empresa.'; END IF;
 RETURN NEW;
END $$;


--
-- Name: can_strategy_record(text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_strategy_record(t text, j jsonb) RETURNS boolean
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE org uuid; parent_id uuid;
BEGIN
 IF NOT public.has_module('strategy') THEN RETURN false; END IF;
 IF public.access_admin() THEN RETURN true; END IF;
 org:=nullif(j->>'organization_id','')::uuid;
 IF org IS NULL THEN
  CASE t
   WHEN 'swot_items','tows_crossings' THEN SELECT organization_id INTO org FROM swot_campaigns WHERE id=(j->>'campaign_id')::uuid;
   WHEN 'swot_contributions' THEN SELECT c.organization_id INTO org FROM swot_items i JOIN swot_campaigns c ON c.id=i.campaign_id WHERE i.id=(j->>'item_id')::uuid;
   WHEN 'strategic_actions' THEN SELECT organization_id INTO org FROM strategic_objectives WHERE id=(j->>'objective_id')::uuid;
   WHEN 'kpi_targets','kpi_results' THEN SELECT organization_id INTO org FROM kpis WHERE id=(j->>'kpi_id')::uuid;
   WHEN 'meeting_presenters','submissions' THEN SELECT organization_id INTO org FROM meetings WHERE id=(j->>'meeting_id')::uuid;
   WHEN 'ppt_layouts' THEN SELECT organization_id INTO org FROM ppt_templates WHERE id=(j->>'template_id')::uuid;
   ELSE RETURN false;
  END CASE;
 END IF;
 RETURN org IS NOT NULL AND org=public.my_organization();
END $$;


--
-- Name: check_rls_status(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_rls_status() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  EXECUTE 'ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY';
  EXECUTE 'ALTER TABLE public.quality_areas ENABLE ROW LEVEL SECURITY';
  EXECUTE 'ALTER TABLE public.quality_origins ENABLE ROW LEVEL SECURITY';
  EXECUTE 'ALTER TABLE public.quality_occurrences ENABLE ROW LEVEL SECURITY';
  EXECUTE 'ALTER TABLE public.quality_actions ENABLE ROW LEVEL SECURITY';
  EXECUTE 'ALTER TABLE public.quality_attachments ENABLE ROW LEVEL SECURITY';
  EXECUTE 'ALTER TABLE public.quality_comments ENABLE ROW LEVEL SECURITY';
  EXECUTE 'ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY';
  EXECUTE 'ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY';
END;
$$;


--
-- Name: current_company_context(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.current_company_context() RETURNS uuid
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE selected uuid; own uuid;
BEGIN
 own:=public.my_organization();
 IF auth.uid() IS NULL THEN RETURN (SELECT id FROM organizations WHERE name ILIKE 'Samsys%' ORDER BY created_at LIMIT 1); END IF;
 selected:=nullif(nullif(current_setting('request.headers',true),'')::jsonb->>'x-organization-id','')::uuid;
 IF selected IS NULL THEN RETURN own; END IF;
 IF NOT public.access_admin() AND selected IS DISTINCT FROM own THEN RAISE EXCEPTION 'Empresa não autorizada' USING ERRCODE='42501'; END IF;
 RETURN selected;
END $$;


--
-- Name: cv_recover_stale_jobs(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.cv_recover_stale_jobs(p_interrupted_minutes integer DEFAULT 60) RETURNS integer
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
DECLARE
  n int;
  n2 int;
BEGIN
  -- jobs ativos interrompidos por reinício do servidor -> ERROR (tentar novamente)
  UPDATE public.lifecycle_cv_jobs
     SET status = 'ERROR',
         etapa = 'error',
         error_message = 'Interrompido por reinicio do servidor — use "Tentar novamente".',
         error_details = jsonb_build_object('recovered', true, 'at', now()),
         finished_at = now(),
         updated_at = now()
   WHERE status IN ('QUEUED','UPLOADING','EXTRACTING','OCR','ANALYZING','VALIDATING','DEDUPLICATING','CREATING')
     AND finished_at IS NULL
     AND (COALESCE(started_at, submitted_at)) < now() - make_interval(mins => p_interrupted_minutes);
  GET DIAGNOSTICS n = ROW_COUNT;

  -- CANCEL_REQUESTED que ficaram pendentes (Ollama congelado no cancelamento): concluir depois de X min.
  UPDATE public.lifecycle_cv_jobs
     SET status = 'CANCELLED',
         etapa = 'cancelled',
         finished_at = COALESCE(finished_at, now()),
         cancelled_at = COALESCE(cancel_requested_at, now()),
         arquivado_at = now(),
         viewed = true,
         updated_at = now()
   WHERE status = 'CANCEL_REQUESTED'
     AND cancel_requested_at < now() - make_interval(mins => GREATEST(10, p_interrupted_minutes / 6));
  GET DIAGNOSTICS n2 = ROW_COUNT;

  RETURN n + n2;
END
$$;


--
-- Name: delta_swot_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delta_swot_guard() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ DECLARE campaign swot_campaigns; BEGIN
 IF TG_TABLE_NAME='swot_items' THEN
  SELECT * INTO campaign FROM swot_campaigns WHERE id=coalesce(NEW.campaign_id,OLD.campaign_id) FOR SHARE;
  IF campaign.status IN ('closed','archived') THEN RAISE EXCEPTION 'Campanha fechada. Reabra a campanha antes de alterar a SWOT.'; END IF;
  IF TG_OP='DELETE' AND EXISTS(SELECT 1 FROM swot_contributions WHERE item_id=OLD.id) THEN RAISE EXCEPTION 'Item consolidado com contributos originais. Preserve a rastreabilidade.'; END IF;
 ELSIF TG_TABLE_NAME='swot_contributions' AND TG_OP='UPDATE' THEN
  IF (to_jsonb(NEW)-'item_id'-'updated_at') IS DISTINCT FROM (to_jsonb(OLD)-'item_id'-'updated_at') OR OLD.item_id IS NOT NULL THEN RAISE EXCEPTION 'O contributo original é imutável.'; END IF;
 ELSIF TG_TABLE_NAME='swot_contributions' AND TG_OP='DELETE' THEN RAISE EXCEPTION 'Os contributos originais devem ser preservados.';
 END IF;
 RETURN coalesce(NEW,OLD);
END $$;


--
-- Name: effective_roles(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.effective_roles(p_user uuid, p_module text) RETURNS text[]
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
 SELECT CASE WHEN p.role='admin' THEN ARRAY['admin'] WHEN NOT p.assignments_configured THEN ARRAY[p.role::text]
 ELSE coalesce((SELECT array_agg(DISTINCT a.role) FROM user_assignments a WHERE a.user_id=p.id AND a.kind='permission' AND a.module=p_module AND a.active AND (a.starts_on IS NULL OR a.starts_on<=current_date) AND (a.ends_on IS NULL OR a.ends_on>=current_date)),ARRAY[]::text[]) END
 FROM profiles p WHERE p.id=p_user
$$;


--
-- Name: enforce_company_links(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_company_links() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $_$
DECLARE fk record; other_org uuid; ref_id uuid; j jsonb:=to_jsonb(NEW); super_ref boolean;
BEGIN
 IF TG_OP='UPDATE' AND NEW.organization_id IS DISTINCT FROM OLD.organization_id THEN RAISE EXCEPTION 'Não é permitido mudar a empresa do registo'; END IF;
 IF auth.uid() IS NOT NULL AND NOT public.access_admin() AND NEW.organization_id IS DISTINCT FROM public.my_organization() THEN RAISE EXCEPTION 'Empresa não autorizada' USING ERRCODE='42501'; END IF;
 FOR fk IN SELECT a.attname field,c.confrelid target,b.attname target_field FROM pg_constraint c JOIN pg_attribute a ON a.attrelid=c.conrelid AND a.attnum=c.conkey[1] JOIN pg_attribute b ON b.attrelid=c.confrelid AND b.attnum=c.confkey[1] WHERE c.conrelid=TG_RELID AND c.contype='f' AND array_length(c.conkey,1)=1 AND EXISTS(SELECT 1 FROM pg_attribute x WHERE x.attrelid=c.confrelid AND x.attname='organization_id' AND NOT x.attisdropped) LOOP
  ref_id:=nullif(j->>fk.field,'')::uuid;
  IF ref_id IS NULL THEN CONTINUE; END IF;
  EXECUTE format('SELECT organization_id FROM %s WHERE %I=$1',fk.target::regclass,fk.target_field) INTO other_org USING ref_id;
  IF fk.target='public.profiles'::regclass THEN
   SELECT is_super_admin INTO super_ref FROM public.profiles WHERE id=ref_id;
   IF super_ref THEN CONTINUE; END IF;
  END IF;
  IF other_org IS NOT NULL AND other_org IS DISTINCT FROM NEW.organization_id THEN RAISE EXCEPTION 'Associação a registo de outra empresa: %',fk.field; END IF;
 END LOOP;
 RETURN NEW;
END $_$;


--
-- Name: get_actions_by_responsible(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_actions_by_responsible() RETURNS TABLE(full_name text, total bigint, open_cnt bigint, overdue bigint, completed bigint)
    LANGUAGE sql STABLE
    SET search_path TO 'public'
    AS $$
  select p.full_name,
         count(a.id) as total,
         count(*) filter (where a.status <> 'COMPLETED') as open_cnt,
         count(*) filter (where a.status <> 'COMPLETED' and a.deadline < current_date) as overdue,
         count(*) filter (where a.status = 'COMPLETED') as completed
  from public.profiles p
  left join public.quality_active_actions a on a.responsible_user_id = p.id
  group by p.id, p.full_name
  order by open_cnt desc;
$$;


--
-- Name: get_dashboard_metrics(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_dashboard_metrics() RETURNS json
    LANGUAGE sql STABLE
    SET search_path TO 'public'
    AS $$
  select json_build_object(
    'open_nc',
      (select count(*) from public.quality_active_occurrences where type='NC' and status in ('OPEN','IN_PROGRESS','AWAITING_EFFECTIVENESS')),
    'open_om',
      (select count(*) from public.quality_active_occurrences where type='OM' and status in ('OPEN','IN_PROGRESS','AWAITING_EFFECTIVENESS')),
    'overdue_actions',
      (select count(*) from public.quality_active_actions where status <> 'COMPLETED' and deadline < current_date),
    'awaiting_effectiveness',
      (select count(*) from public.quality_active_occurrences where status = 'AWAITING_EFFECTIVENESS'),
    'closed',
      (select count(*) from public.quality_active_occurrences where status = 'CLOSED'),
    'total_actions_open',
      (select count(*) from public.quality_active_actions where status <> 'COMPLETED')
  );
$$;


--
-- Name: get_occurrence_evolution(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_occurrence_evolution(months integer DEFAULT 12) RETURNS TABLE(period text, type public.occurrence_type, cnt bigint)
    LANGUAGE sql STABLE
    SET search_path TO 'public'
    AS $$
  select to_char(date_trunc('month', created_at), 'YYYY-MM') as period, type, count(*) as cnt
  from public.quality_active_occurrences
  where created_at >= date_trunc('month', current_date) - (months || ' months')::interval
  group by 1, 2
  order by 1, 2;
$$;


--
-- Name: get_occurrences_by_area(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_occurrences_by_area() RETURNS TABLE(area_name text, cnt bigint)
    LANGUAGE sql STABLE
    SET search_path TO 'public'
    AS $$
  select a.name, count(*)::bigint as cnt from public.quality_active_occurrences q
  join public.quality_areas a on a.id = q.area_id
  group by a.name order by 2 desc;
$$;


--
-- Name: get_occurrences_by_origin(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_occurrences_by_origin() RETURNS TABLE(origin_name text, cnt bigint)
    LANGUAGE sql STABLE
    SET search_path TO 'public'
    AS $$
  select o.name, count(*)::bigint as cnt from public.quality_active_occurrences q
  join public.quality_origins o on o.id = q.origin_id
  group by o.name order by 2 desc;
$$;


--
-- Name: get_occurrences_by_status(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_occurrences_by_status() RETURNS TABLE(status public.occurrence_status, cnt bigint)
    LANGUAGE sql STABLE
    SET search_path TO 'public'
    AS $$
  select status, count(*)::bigint as cnt from public.quality_active_occurrences group by status;
$$;


--
-- Name: get_urgent_actions(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_urgent_actions(limit_n integer DEFAULT 8) RETURNS TABLE(action_id uuid, action_ref text, action_description text, occurrence_ref text, occurrence_id uuid, responsible text, deadline date, status public.action_status, urgency integer)
    LANGUAGE sql STABLE
    SET search_path TO 'public'
    AS $$
  select a.id, a.reference, a.description,
         o.reference, o.id,
         p.full_name, a.deadline, a.status,
         case
           when a.deadline < current_date then 0
           when a.deadline = current_date then 1
           when a.deadline = current_date + 1 then 2
           when a.deadline = current_date + 2 then 3
           when a.deadline = current_date + 3 then 4
           else 9
         end as urgency
  from public.quality_active_actions a
  join public.quality_active_occurrences o on o.id = a.occurrence_id
  left join public.profiles p on p.id = a.responsible_user_id
  where a.status <> 'COMPLETED' and (a.deadline is null or a.deadline <= current_date + 3)
  order by urgency asc, a.deadline asc nulls last
  limit limit_n;
$$;


--
-- Name: guard_close_occurrence(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.guard_close_occurrence() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
 IF NEW.status='CLOSED' AND OLD.status<>'CLOSED' THEN
 IF NEW.type='NC' AND (nullif(btrim(NEW.cause_analysis),'') IS NULL OR nullif(btrim(NEW.root_cause),'') IS NULL OR NEW.root_cause_confirmed_by IS NULL OR NEW.corrective_required IS NULL) THEN RAISE EXCEPTION 'Falta concluir e confirmar a análise da causa, causa raiz e decisão corretiva.';END IF;
 IF NEW.corrective_required=false AND nullif(btrim(NEW.corrective_reason),'') IS NULL THEN RAISE EXCEPTION 'Falta justificar a dispensa de ação corretiva.';END IF;
 IF EXISTS(SELECT 1 FROM quality_actions WHERE occurrence_id=NEW.id AND mandatory AND status NOT IN ('COMPLETED','CANCELLED')) THEN RAISE EXCEPTION 'Existem ações obrigatórias por concluir.'; END IF;
 IF NEW.corrective_required AND NOT EXISTS(SELECT 1 FROM quality_actions WHERE occurrence_id=NEW.id AND action_kind='CORRECTIVE' AND status='COMPLETED') THEN RAISE EXCEPTION 'Falta uma ação corretiva concluída.';END IF;
 IF NEW.approval_required AND NEW.approval_status<>'APPROVED' THEN RAISE EXCEPTION 'O tratamento aguarda aprovação.'; END IF;
 IF NEW.effectiveness_required AND (NEW.effectiveness_status IS DISTINCT FROM 'EFFECTIVE' OR NEW.effectiveness_validated_by IS NULL OR NEW.effectiveness_validated_at IS NULL) THEN RAISE EXCEPTION 'Falta avaliar positivamente a eficácia.'; END IF;
 NEW.closed_at:=clock_timestamp();
 END IF;RETURN NEW;
END $$;


--
-- Name: guard_complete_action(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.guard_complete_action() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: guard_reopen_occurrence(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.guard_reopen_occurrence() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: handle_new_user(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.handle_new_user() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: has_module(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.has_module(p_module text) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
 SELECT public.session_valid() AND EXISTS(SELECT 1 FROM profiles p WHERE p.id=auth.uid() AND (p.role='admin' OR coalesce((p.module_access->>p_module)::boolean,false)))
$$;


--
-- Name: has_responsibility(text, text[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.has_responsibility(p_module text, p_roles text[]) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
 SELECT session_valid() AND has_module(p_module) AND effective_roles(auth.uid(),p_module)&&p_roles
$$;


--
-- Name: import_kpi_csv(uuid, jsonb, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.import_kpi_csv(p_connector_id uuid, p_rows jsonb, p_human_confirmed boolean DEFAULT false) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE conn public.connectors; item jsonb; k public.kpis; existing public.kpi_results; n integer:=0;
BEGIN
 IF NOT public.has_module('strategy') OR NOT EXISTS(SELECT 1 FROM public.connectors c WHERE c.id=p_connector_id AND public.can_strategy_record('connectors',to_jsonb(c))) THEN RAISE EXCEPTION 'Sem acesso ao conector' USING ERRCODE='42501'; END IF;

 IF auth.uid() IS NULL OR NOT public.has_responsibility('strategy',ARRAY['admin','quality']) OR p_human_confirmed IS DISTINCT FROM true THEN RAISE EXCEPTION 'Validação humana e permissão obrigatórias' USING ERRCODE='42501'; END IF;
 SELECT * INTO conn FROM public.connectors WHERE id=p_connector_id FOR SHARE;
 IF conn.id IS NULL OR NOT conn.active OR conn.provider<>'csv_kpi' THEN RAISE EXCEPTION 'Conector CSV indisponível'; END IF;
 IF jsonb_typeof(p_rows) IS DISTINCT FROM 'array' OR jsonb_array_length(p_rows) NOT BETWEEN 1 AND 500 THEN RAISE EXCEPTION 'Importa entre 1 e 500 linhas'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_rows) x GROUP BY x->>'codigo',x->>'periodo' HAVING count(*)>1) THEN RAISE EXCEPTION 'Linhas duplicadas'; END IF;
 FOR item IN SELECT * FROM jsonb_array_elements(p_rows) LOOP
  SELECT * INTO k FROM public.kpis WHERE organization_id=conn.organization_id AND code=item->>'codigo' AND active FOR UPDATE;
  IF k.id IS NULL THEN RAISE EXCEPTION 'KPI desconhecido: %',item->>'codigo'; END IF;
  SELECT * INTO existing FROM public.kpi_results WHERE kpi_id=k.id AND period=item->>'periodo' FOR UPDATE;
  IF existing.id IS DISTINCT FROM nullif(item->>'id','')::uuid THEN RAISE EXCEPTION 'O resultado mudou. Atualiza a pré-visualização.' USING ERRCODE='40001'; END IF;
  PERFORM public.strategy_write('kpi_results',CASE WHEN existing.id IS NULL THEN 'insert' ELSE 'update' END,jsonb_build_object('kpi_id',k.id,'period',item->>'periodo','value',item->'valor','notes',item->>'notas'),existing.id,nullif(item->>'updated_at','')::timestamptz,true);
  n:=n+1;
 END LOOP;
 RETURN n;
END $$;


--
-- Name: is_admin_user(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_admin_user(uid uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
  select exists (
    select 1 from public.profiles p
    where p.id = uid and p.role in ('admin','quality')
  );
$$;


--
-- Name: is_any_authenticated(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_any_authenticated() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
  select auth.uid() is not null
$$;


--
-- Name: is_management(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_management() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
  select exists (
    select 1 from public.profiles where id = auth.uid() and active = true and role = 'management'
  );
$$;


--
-- Name: is_management_or_quality_or_admin(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_management_or_quality_or_admin() RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role IN ('management','quality','admin')
  );
END;
$$;


--
-- Name: is_quality_or_admin(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_quality_or_admin() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
 SELECT has_responsibility('quality',ARRAY['admin','quality'])
$$;


--
-- Name: log_audit(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.log_audit() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE oldj jsonb;newj jsonb;org uuid;
BEGIN
 IF TG_OP<>'INSERT' THEN oldj:=to_jsonb(OLD); END IF;
 IF TG_OP<>'DELETE' THEN newj:=to_jsonb(NEW); END IF;
 org:=coalesce((newj->>'organization_id')::uuid,(oldj->>'organization_id')::uuid,current_company_context());
 INSERT INTO audit_log(entity_type,entity_id,action,old_data,new_data,user_id,organization_id)
 VALUES(TG_TABLE_NAME,coalesce((newj->>'id')::uuid,(oldj->>'id')::uuid),lower(TG_OP),oldj,newj,auth.uid(),org);
 RETURN coalesce(NEW,OLD);
END $$;


--
-- Name: my_organization(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.my_organization() RETURNS uuid
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
 SELECT organization_id FROM profiles WHERE id=auth.uid() AND public.session_valid()
$$;


--
-- Name: next_action_reference(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.next_action_reference() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare next_val integer;
begin
  next_val := nextval('public.seq_action_ref');
  new.reference := 'ACT-' || lpad(next_val::text, 5, '0');
  return new;
end;
$$;


--
-- Name: next_occurrence_reference(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.next_occurrence_reference() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  new_year  integer;
  next_val  integer;
  prefix    text;
begin
  new_year := extract(year from new.occurrence_date)::integer;
  prefix := case when new.type = 'NC' then 'NC-' else 'OM-' end;

  insert into public.occurrence_counters (type, year, last_value)
  values (new.type, new_year, 1)
  on conflict (type, year)
  do update set last_value = public.occurrence_counters.last_value + 1
  returning last_value into next_val;

  new.year := new_year;
  new.reference := prefix || new_year || '-' || lpad(next_val::text, 4, '0');
  return new;
end;
$$;


--
-- Name: nif_pt_valido(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.nif_pt_valido(p_nif text) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
DECLARE
  peso int; soma int := 0; resto int; ctrl int;
BEGIN
  IF p_nif !~ '^[0-9]{9}$' OR left(p_nif,1) = '0' THEN RETURN false; END IF;
  FOR i IN 1..8 LOOP
    peso := 10 - i;                 -- 1º dígito peso 9, 8º peso 2
    soma := soma + (substr(p_nif, i, 1)::int * peso);
  END LOOP;
  resto := soma % 11;
  ctrl := CASE WHEN resto < 2 THEN 0 ELSE 11 - resto END;
  RETURN ctrl = right(p_nif,1)::int;
END;
$_$;


--
-- Name: platform_module_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.platform_module_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN NEW.updated_at:=clock_timestamp(); RETURN NEW; END $$;


--
-- Name: platform_module_write(text, jsonb, uuid, timestamp with time zone, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.platform_module_write(p_table text, p_payload jsonb, p_id uuid DEFAULT NULL::uuid, p_expected_updated_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_human_confirmed boolean DEFAULT false) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $_$
DECLARE actor uuid:=auth.uid(); before_row jsonb; after_row jsonb; merged jsonb; allowed text[]; bad text; fields text; vals text; assignments text; org uuid; other jsonb; old_status text; new_status text;
BEGIN
 IF p_table IN ('organizations','organization_memberships','teams','brand_kits','roles') THEN
 IF NOT public.access_admin() THEN
  IF NOT public.session_valid() OR NOT EXISTS(SELECT 1 FROM public.profiles WHERE id=auth.uid() AND role='admin') OR p_table IN ('organization_memberships','roles') THEN RAISE EXCEPTION 'Operação reservada ao administrador autorizado' USING ERRCODE='42501'; END IF;
  IF p_table='organizations' THEN
   IF p_id IS DISTINCT FROM public.my_organization() THEN RAISE EXCEPTION 'Empresa não autorizada' USING ERRCODE='42501'; END IF;
  ELSE
   IF p_id IS NOT NULL THEN EXECUTE format('SELECT to_jsonb(t) FROM public.%I t WHERE id=$1',p_table) INTO before_row USING p_id; ELSE before_row:=p_payload; END IF;
   IF nullif(before_row->>'organization_id','')::uuid IS DISTINCT FROM public.my_organization() THEN RAISE EXCEPTION 'Empresa não autorizada' USING ERRCODE='42501'; END IF;
  END IF;
 END IF;
 ELSE
 IF p_id IS NOT NULL AND p_table IN ('frameworks','cycles','meetings','meeting_presenters','decisions','ppt_templates','connectors') THEN
 EXECUTE format('SELECT to_jsonb(t) FROM public.%I t WHERE id=$1',p_table) INTO before_row USING p_id;
 IF NOT public.can_strategy_record(p_table,before_row) THEN RAISE EXCEPTION 'Sem acesso ao registo' USING ERRCODE='42501'; END IF;
 ELSIF NOT public.can_strategy_record(p_table,p_payload) THEN RAISE EXCEPTION 'Sem acesso à empresa ou módulo' USING ERRCODE='42501'; END IF;
 END IF;

 IF actor IS NULL OR NOT public.has_responsibility('strategy',ARRAY['admin','quality']) THEN RAISE EXCEPTION 'Sem permissão' USING ERRCODE='42501'; END IF;
 IF p_human_confirmed IS DISTINCT FROM true THEN RAISE EXCEPTION 'Validação humana obrigatória' USING ERRCODE='42501'; END IF;
 allowed:=CASE p_table
 WHEN 'organizations' THEN ARRAY['name','slug','description','tax_id','email','phone','website','address','city','country','active']
 WHEN 'teams' THEN ARRAY['name','description','color','active','organization_id']
 WHEN 'organization_memberships' THEN ARRAY['user_id','role','department','job_title','active','organization_id']
 WHEN 'brand_kits' THEN ARRAY['name','is_default','primary_color','secondary_color','background_color','text_color','accent_color','danger_color','warning_color','info_color','success_color','font_heading','font_body','organization_id']
 WHEN 'frameworks' THEN ARRAY['code','name','description','type','active','organization_id']
 WHEN 'cycles' THEN ARRAY['name','description','framework_id','start_date','end_date','status','active','organization_id']
 WHEN 'meetings' THEN ARRAY['title','description','cycle_id','meeting_type','scheduled_at','duration_min','location','online_url','status','minutes','organization_id']
 WHEN 'meeting_presenters' THEN ARRAY['meeting_id','user_id','topic','order_index']
 WHEN 'decisions' THEN ARRAY['code','title','description','meeting_id','rationale','impact_level','status','organization_id']
 WHEN 'ppt_templates' THEN ARRAY['name','description','is_default','include_cover','sections','body_font_size','lines_per_slide','active','organization_id']
 WHEN 'connectors' THEN ARRAY['name','description','provider','active','organization_id']
 END;
 IF allowed IS NULL OR jsonb_typeof(p_payload) IS DISTINCT FROM 'object' OR p_payload='{}'::jsonb THEN RAISE EXCEPTION 'Operação inválida'; END IF;
 SELECT key INTO bad FROM jsonb_object_keys(p_payload) key WHERE NOT key=ANY(allowed) LIMIT 1;
 IF bad IS NOT NULL THEN RAISE EXCEPTION 'Campo não editável: %',bad; END IF;
 -- Serialize per organisation, including competing default selections.
 org:=nullif(p_payload->>'organization_id','')::uuid;
 IF org IS NOT NULL THEN PERFORM 1 FROM public.organizations WHERE id=org FOR UPDATE; END IF;
 IF p_id IS NOT NULL THEN
  EXECUTE format('SELECT to_jsonb(t) FROM public.%I t WHERE id=$1 FOR UPDATE',p_table) INTO before_row USING p_id;
  IF before_row IS NULL THEN RAISE EXCEPTION 'Registo não encontrado'; END IF;
  IF p_expected_updated_at IS NULL OR (before_row->>'updated_at')::timestamptz IS DISTINCT FROM p_expected_updated_at THEN RAISE EXCEPTION 'O registo mudou. Recarrega antes de guardar.' USING ERRCODE='40001'; END IF;
  IF EXISTS(SELECT 1 FROM unnest(ARRAY['organization_id','meeting_id','user_id']) k WHERE (k='organization_id' OR p_table IN ('meeting_presenters','organization_memberships')) AND p_payload ? k AND p_payload->k IS DISTINCT FROM before_row->k) THEN RAISE EXCEPTION 'Não é permitido mudar a origem do registo'; END IF;
 END IF;
 IF p_id IS NULL THEN p_payload:=coalesce(('{"organizations": {"country": "PT", "active": true}, "teams": {"color": "#7367f0", "active": true}, "organization_memberships": {"role": "member", "active": true}, "brand_kits": {"is_default": false, "primary_color": "#7367f0", "secondary_color": "#00cfe8", "background_color": "#ffffff", "text_color": "#2c2c2c", "accent_color": "#28c76f", "danger_color": "#ea5455", "warning_color": "#ff9f43", "info_color": "#00cfe8", "success_color": "#28c76f", "font_heading": "Aptos", "font_body": "Aptos"}, "frameworks": {"type": "strategic", "active": true}, "cycles": {"status": "draft", "active": true}, "meetings": {"meeting_type": "strategic", "duration_min": 60, "status": "scheduled"}, "meeting_presenters": {"order_index": 0}, "decisions": {"impact_level": "medium", "status": "proposed"}, "ppt_templates": {"is_default": false, "include_cover": true, "sections": ["meeting", "swot", "tows", "risks", "objectives", "actions", "kpis", "decisions"], "body_font_size": 18, "lines_per_slide": 10, "active": true}, "connectors": {"provider": "csv_kpi", "active": true}}'::jsonb)->p_table,'{}')||p_payload; END IF;
 merged:=coalesce(before_row,'{}')||p_payload;
 org:=nullif(merged->>'organization_id','')::uuid;
 IF p_table NOT IN ('organizations','meeting_presenters') AND org IS NULL THEN RAISE EXCEPTION 'Organização obrigatória'; END IF;
 IF p_table='organizations' THEN
  IF btrim(coalesce(merged->>'name',''))='' THEN RAISE EXCEPTION 'Nome obrigatório'; END IF;
  IF merged->>'website' IS NOT NULL AND NOT (merged->>'website' ~* '^https?://') THEN RAISE EXCEPTION 'URL inválido'; END IF;
 END IF;
 IF p_table='teams' THEN
  IF btrim(coalesce(merged->>'name',''))='' THEN RAISE EXCEPTION 'Nome obrigatório'; END IF;
  IF merged->>'color' IS NOT NULL AND NOT (merged->>'color' ~ '^#[0-9a-fA-F]{6}$') THEN RAISE EXCEPTION 'Cor inválida'; END IF;
 END IF;
 IF p_table='organization_memberships' THEN
  IF btrim(coalesce(merged->>'user_id',''))='' THEN RAISE EXCEPTION 'Utilizador obrigatório'; END IF;
  IF btrim(coalesce(merged->>'role',''))='' THEN RAISE EXCEPTION 'Papel na organizaÃ§Ã£o obrigatório'; END IF;
  IF merged->>'role' IS NOT NULL AND merged->>'role' NOT IN ('owner','admin','member','viewer') THEN RAISE EXCEPTION 'Papel na organizaÃ§Ã£o inválido'; END IF;
 END IF;
 IF p_table='brand_kits' THEN
  IF btrim(coalesce(merged->>'name',''))='' THEN RAISE EXCEPTION 'Nome obrigatório'; END IF;
  IF btrim(coalesce(merged->>'primary_color',''))='' THEN RAISE EXCEPTION 'Cor principal obrigatório'; END IF;
  IF merged->>'primary_color' IS NOT NULL AND NOT (merged->>'primary_color' ~ '^#[0-9a-fA-F]{6}$') THEN RAISE EXCEPTION 'Cor inválida'; END IF;
  IF btrim(coalesce(merged->>'secondary_color',''))='' THEN RAISE EXCEPTION 'Cor secundÃ¡ria obrigatório'; END IF;
  IF merged->>'secondary_color' IS NOT NULL AND NOT (merged->>'secondary_color' ~ '^#[0-9a-fA-F]{6}$') THEN RAISE EXCEPTION 'Cor inválida'; END IF;
  IF btrim(coalesce(merged->>'background_color',''))='' THEN RAISE EXCEPTION 'Fundo obrigatório'; END IF;
  IF merged->>'background_color' IS NOT NULL AND NOT (merged->>'background_color' ~ '^#[0-9a-fA-F]{6}$') THEN RAISE EXCEPTION 'Cor inválida'; END IF;
  IF btrim(coalesce(merged->>'text_color',''))='' THEN RAISE EXCEPTION 'Texto obrigatório'; END IF;
  IF merged->>'text_color' IS NOT NULL AND NOT (merged->>'text_color' ~ '^#[0-9a-fA-F]{6}$') THEN RAISE EXCEPTION 'Cor inválida'; END IF;
  IF btrim(coalesce(merged->>'accent_color',''))='' THEN RAISE EXCEPTION 'Destaque obrigatório'; END IF;
  IF merged->>'accent_color' IS NOT NULL AND NOT (merged->>'accent_color' ~ '^#[0-9a-fA-F]{6}$') THEN RAISE EXCEPTION 'Cor inválida'; END IF;
  IF btrim(coalesce(merged->>'danger_color',''))='' THEN RAISE EXCEPTION 'Erro obrigatório'; END IF;
  IF merged->>'danger_color' IS NOT NULL AND NOT (merged->>'danger_color' ~ '^#[0-9a-fA-F]{6}$') THEN RAISE EXCEPTION 'Cor inválida'; END IF;
  IF btrim(coalesce(merged->>'warning_color',''))='' THEN RAISE EXCEPTION 'Aviso obrigatório'; END IF;
  IF merged->>'warning_color' IS NOT NULL AND NOT (merged->>'warning_color' ~ '^#[0-9a-fA-F]{6}$') THEN RAISE EXCEPTION 'Cor inválida'; END IF;
  IF btrim(coalesce(merged->>'info_color',''))='' THEN RAISE EXCEPTION 'InformaÃ§Ã£o obrigatório'; END IF;
  IF merged->>'info_color' IS NOT NULL AND NOT (merged->>'info_color' ~ '^#[0-9a-fA-F]{6}$') THEN RAISE EXCEPTION 'Cor inválida'; END IF;
  IF btrim(coalesce(merged->>'success_color',''))='' THEN RAISE EXCEPTION 'Sucesso obrigatório'; END IF;
  IF merged->>'success_color' IS NOT NULL AND NOT (merged->>'success_color' ~ '^#[0-9a-fA-F]{6}$') THEN RAISE EXCEPTION 'Cor inválida'; END IF;
  IF btrim(coalesce(merged->>'font_heading',''))='' THEN RAISE EXCEPTION 'Fonte dos tÃ­tulos obrigatório'; END IF;
  IF btrim(coalesce(merged->>'font_body',''))='' THEN RAISE EXCEPTION 'Fonte do texto obrigatório'; END IF;
 END IF;
 IF p_table='frameworks' THEN
  IF btrim(coalesce(merged->>'code',''))='' THEN RAISE EXCEPTION 'CÃ³digo obrigatório'; END IF;
  IF btrim(coalesce(merged->>'name',''))='' THEN RAISE EXCEPTION 'Nome obrigatório'; END IF;
  IF merged->>'type' IS NOT NULL AND merged->>'type' NOT IN ('strategic','quality','compliance','custom') THEN RAISE EXCEPTION 'Tipo inválido'; END IF;
 END IF;
 IF p_table='cycles' THEN
  IF btrim(coalesce(merged->>'name',''))='' THEN RAISE EXCEPTION 'Nome obrigatório'; END IF;
  IF btrim(coalesce(merged->>'start_date',''))='' THEN RAISE EXCEPTION 'InÃ­cio obrigatório'; END IF;
  IF merged->>'status' IS NOT NULL AND merged->>'status' NOT IN ('draft','active','closed','archived') THEN RAISE EXCEPTION 'Estado inválido'; END IF;
 END IF;
 IF p_table='meetings' THEN
  IF btrim(coalesce(merged->>'title',''))='' THEN RAISE EXCEPTION 'TÃ­tulo obrigatório'; END IF;
  IF merged->>'meeting_type' IS NOT NULL AND merged->>'meeting_type' NOT IN ('board','strategic','tactical','operational') THEN RAISE EXCEPTION 'Tipo inválido'; END IF;
  IF btrim(coalesce(merged->>'scheduled_at',''))='' THEN RAISE EXCEPTION 'Data e hora obrigatório'; END IF;
  IF merged->>'duration_min' IS NOT NULL AND (merged->>'duration_min')::numeric NOT BETWEEN 1 AND 1440 THEN RAISE EXCEPTION 'DuraÃ§Ã£o em minutos fora dos limites'; END IF;
  IF merged->>'online_url' IS NOT NULL AND NOT (merged->>'online_url' ~* '^https?://') THEN RAISE EXCEPTION 'URL inválido'; END IF;
  IF btrim(coalesce(merged->>'status',''))='' THEN RAISE EXCEPTION 'Estado obrigatório'; END IF;
  IF merged->>'status' IS NOT NULL AND merged->>'status' NOT IN ('scheduled','in_progress','completed','cancelled') THEN RAISE EXCEPTION 'Estado inválido'; END IF;
 END IF;
 IF p_table='meeting_presenters' THEN
  IF btrim(coalesce(merged->>'meeting_id',''))='' THEN RAISE EXCEPTION 'ReuniÃ£o obrigatório'; END IF;
  IF btrim(coalesce(merged->>'user_id',''))='' THEN RAISE EXCEPTION 'Participante obrigatório'; END IF;
  IF merged->>'order_index' IS NOT NULL AND (merged->>'order_index')::numeric NOT BETWEEN 0 AND 999 THEN RAISE EXCEPTION 'Ordem fora dos limites'; END IF;
 END IF;
 IF p_table='decisions' THEN
  IF btrim(coalesce(merged->>'title',''))='' THEN RAISE EXCEPTION 'Assunto obrigatório'; END IF;
  IF merged->>'impact_level' IS NOT NULL AND merged->>'impact_level' NOT IN ('low','medium','high') THEN RAISE EXCEPTION 'Impacto inválido'; END IF;
  IF btrim(coalesce(merged->>'status',''))='' THEN RAISE EXCEPTION 'Estado obrigatório'; END IF;
  IF merged->>'status' IS NOT NULL AND merged->>'status' NOT IN ('proposed','approved','rejected','implemented') THEN RAISE EXCEPTION 'Estado inválido'; END IF;
 END IF;
 IF p_table='ppt_templates' THEN
  IF btrim(coalesce(merged->>'name',''))='' THEN RAISE EXCEPTION 'Nome obrigatório'; END IF;
  IF btrim(coalesce(merged->>'sections',''))='' THEN RAISE EXCEPTION 'SecÃ§Ãµes incluÃ­das obrigatório'; END IF;
  IF btrim(coalesce(merged->>'body_font_size',''))='' THEN RAISE EXCEPTION 'Tamanho do texto (pt) obrigatório'; END IF;
  IF merged->>'body_font_size' IS NOT NULL AND (merged->>'body_font_size')::numeric NOT BETWEEN 18 AND 24 THEN RAISE EXCEPTION 'Tamanho do texto (pt) fora dos limites'; END IF;
  IF btrim(coalesce(merged->>'lines_per_slide',''))='' THEN RAISE EXCEPTION 'Linhas por slide obrigatório'; END IF;
  IF merged->>'lines_per_slide' IS NOT NULL AND (merged->>'lines_per_slide')::numeric NOT BETWEEN 6 AND 10 THEN RAISE EXCEPTION 'Linhas por slide fora dos limites'; END IF;
 END IF;
 IF p_table='connectors' THEN
  IF btrim(coalesce(merged->>'name',''))='' THEN RAISE EXCEPTION 'Nome obrigatório'; END IF;
  IF btrim(coalesce(merged->>'provider',''))='' THEN RAISE EXCEPTION 'Origem obrigatório'; END IF;
  IF merged->>'provider' IS NOT NULL AND merged->>'provider' NOT IN ('csv_kpi','phc','sage','powerbi','sharepoint','custom') THEN RAISE EXCEPTION 'Origem inválido'; END IF;
 END IF;

 IF p_table='cycles' THEN
  IF (merged->>'start_date')::date>(merged->>'end_date')::date THEN RAISE EXCEPTION 'Fim anterior ao início'; END IF;
  IF merged->>'framework_id' IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.frameworks WHERE id=(merged->>'framework_id')::uuid AND organization_id=org) THEN RAISE EXCEPTION 'Framework de outra organização'; END IF;
 END IF;
 IF p_table='meetings' THEN
  IF merged->>'cycle_id' IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.cycles WHERE id=(merged->>'cycle_id')::uuid AND organization_id=org) THEN RAISE EXCEPTION 'Ciclo de outra organização'; END IF;
  IF merged->>'status'='completed' AND btrim(coalesce(merged->>'minutes',''))='' THEN RAISE EXCEPTION 'Ata obrigatória para concluir'; END IF;
 END IF;
 IF p_table='meeting_presenters' AND NOT EXISTS(SELECT 1 FROM public.meetings WHERE id=(merged->>'meeting_id')::uuid) THEN RAISE EXCEPTION 'Reunião inválida'; END IF;
 IF p_table='decisions' THEN
  IF merged->>'meeting_id' IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.meetings WHERE id=(merged->>'meeting_id')::uuid AND organization_id=org) THEN RAISE EXCEPTION 'Reunião de outra organização'; END IF;
  old_status:=coalesce(before_row->>'status','proposed'); new_status:=coalesce(merged->>'status','proposed');
  IF p_id IS NULL AND new_status<>'proposed' OR old_status<>new_status AND NOT (old_status='proposed' AND new_status IN ('approved','rejected') OR old_status='approved' AND new_status='implemented') THEN RAISE EXCEPTION 'Transição de decisão inválida'; END IF;
  IF new_status<>'proposed' AND btrim(coalesce(merged->>'rationale',''))='' THEN RAISE EXCEPTION 'Fundamentação obrigatória'; END IF;
  IF old_status<>new_status AND new_status IN ('approved','rejected') THEN p_payload:=p_payload||jsonb_build_object('decided_by',actor,'decided_at',clock_timestamp()); END IF;
  IF old_status<>new_status AND new_status='implemented' THEN p_payload:=p_payload||jsonb_build_object('implemented_at',clock_timestamp()); END IF;
 END IF;
 IF p_table='connectors' AND coalesce((merged->>'active')::boolean,true) AND merged->>'provider'<>'csv_kpi' THEN RAISE EXCEPTION 'Adaptador externo ainda não disponível; guarda o conector inativo'; END IF;
 IF p_table='ppt_templates' THEN
  IF jsonb_typeof(merged->'sections') IS DISTINCT FROM 'array' OR jsonb_array_length(merged->'sections')=0 OR EXISTS(SELECT 1 FROM jsonb_array_elements_text(merged->'sections') s WHERE s NOT IN ('meeting','swot','tows','risks','objectives','actions','kpis','decisions')) THEN RAISE EXCEPTION 'Secções inválidas'; END IF;
 END IF;
 IF p_table IN ('brand_kits','ppt_templates') AND (merged->>'is_default')::boolean THEN
  PERFORM 1 FROM public.organizations WHERE id=org FOR UPDATE;
  FOR other IN EXECUTE format('SELECT to_jsonb(t) FROM public.%I t WHERE organization_id=$1 AND is_default AND id IS DISTINCT FROM $2 FOR UPDATE',p_table) USING org,p_id LOOP
   EXECUTE format('UPDATE public.%I SET is_default=false,updated_at=clock_timestamp() WHERE id=$1 RETURNING to_jsonb(%I.*)',p_table,p_table) INTO after_row USING (other->>'id')::uuid;
   INSERT INTO public.strategy_history(table_name,record_id,operation,before_data,after_data,reviewed_by) VALUES(p_table,(other->>'id')::uuid,'update',other,after_row,actor);
  END LOOP;
 END IF;
 IF p_id IS NULL AND p_table IN ('meetings','decisions','ppt_templates') THEN p_payload:=p_payload||jsonb_build_object('created_by',actor); END IF;
 p_payload:=p_payload||jsonb_build_object('updated_at',clock_timestamp());
 SELECT string_agg(format('%I',key),','),string_agg(format('r.%I',key),','),string_agg(format('%I=r.%I',key,key),',') INTO fields,vals,assignments FROM jsonb_object_keys(p_payload) key;
 IF p_id IS NULL THEN
  EXECUTE format('INSERT INTO public.%I (%s) SELECT %s FROM jsonb_populate_record(NULL::public.%I,$1) r RETURNING to_jsonb(%I.*)',p_table,fields,vals,p_table,p_table) INTO after_row USING p_payload;
 ELSE
  EXECUTE format('UPDATE public.%I t SET %s FROM jsonb_populate_record(NULL::public.%I,$1) r WHERE t.id=$2 RETURNING to_jsonb(t.*)',p_table,assignments,p_table) INTO after_row USING p_payload,p_id;
 END IF;
 INSERT INTO public.strategy_history(table_name,record_id,operation,before_data,after_data,reviewed_by) VALUES(p_table,(after_row->>'id')::uuid,CASE WHEN p_id IS NULL THEN 'insert' ELSE 'update' END,before_row,after_row,actor);
 RETURN after_row;
END $_$;


--
-- Name: preserve_used_assignment(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.preserve_used_assignment() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN
 IF OLD.used_at IS NOT NULL THEN RAISE EXCEPTION 'Atribuição já utilizada. Termine a atribuição para preservar o histórico.'; END IF; RETURN OLD;
END $$;


--
-- Name: protect_campaign_delete(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_campaign_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN
 IF EXISTS(SELECT 1 FROM swot_items WHERE campaign_id=OLD.id) OR EXISTS(SELECT 1 FROM swot_contributions WHERE campaign_id=OLD.id) OR EXISTS(SELECT 1 FROM platform_admin_history WHERE entity_id=OLD.id AND action NOT IN ('create','edit')) THEN RAISE EXCEPTION 'Campanha já utilizada. Arquive para preservar o histórico.'; END IF; RETURN OLD;
END $$;


--
-- Name: protect_super_administrator(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_super_administrator() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
 IF TG_OP='INSERT' THEN IF NEW.is_super_admin THEN RAISE EXCEPTION 'Não é permitido criar superadministradores'; END IF; RETURN NEW; END IF;
 IF TG_OP='DELETE' THEN IF OLD.is_super_admin THEN RAISE EXCEPTION 'Superadministrador protegido'; END IF; RETURN OLD; END IF;
 IF NEW.is_super_admin IS DISTINCT FROM OLD.is_super_admin OR OLD.is_super_admin AND (NEW.role<>'admin' OR NOT NEW.active OR NEW.email IS DISTINCT FROM OLD.email OR NEW.organization_id IS DISTINCT FROM OLD.organization_id) THEN RAISE EXCEPTION 'Superadministrador protegido'; END IF;
 RETURN NEW;
END $$;


--
-- Name: protect_super_auth(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_super_auth() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
 IF EXISTS(SELECT 1 FROM public.profiles WHERE id=OLD.id AND is_super_admin) AND (TG_OP='DELETE' OR NEW.email IS DISTINCT FROM OLD.email) THEN RAISE EXCEPTION 'Identidade do superadministrador protegida'; END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; END IF; RETURN NEW;
END $$;


--
-- Name: protect_used_config(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_used_config() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN
 IF (TG_TABLE_NAME='quality_catalogs' AND to_jsonb(OLD)->>'is_system'='true') OR record_has_usage(TG_TABLE_NAME,OLD.id,OLD.organization_id) THEN RAISE EXCEPTION 'Este valor está protegido ou já foi utilizado e não pode ser eliminado. Preserve o histórico; pode desativá-lo para impedir novas utilizações.'; END IF;
 RETURN OLD;
END $$;


--
-- Name: quality_immutable(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.quality_immutable() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN RAISE EXCEPTION 'Registo imutável: o histórico e a evidência devem ser preservados.'; END $$;


--
-- Name: quality_original_text(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.quality_original_text() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN
 IF OLD.original_text IS NOT NULL AND NEW.original_text IS DISTINCT FROM OLD.original_text THEN RAISE EXCEPTION 'O texto original do auditor não pode ser substituído.'; END IF;RETURN NEW;END $$;


--
-- Name: quality_protect_nc_classification(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.quality_protect_nc_classification() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
BEGIN
 IF OLD.kind='nc_classification' THEN
  IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Desativa a classificação; o histórico deve ser preservado.'; END IF;
  IF NEW.kind<>OLD.kind OR NEW.organization_id<>OLD.organization_id OR NEW.is_system<>OLD.is_system THEN RAISE EXCEPTION 'Identidade da classificação protegida.'; END IF;
  IF OLD.is_system AND (NEW.name<>OLD.name OR NOT NEW.active) THEN RAISE EXCEPTION 'Classificação base protegida.'; END IF;
  IF NEW.name<>OLD.name AND EXISTS(SELECT 1 FROM quality_occurrences WHERE organization_id=OLD.organization_id AND type='NC' AND lower(btrim(classification))=lower(btrim(OLD.name))) THEN RAISE EXCEPTION 'Classificação já utilizada: apenas podes alterar o estado.'; END IF;
 END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; END IF;
 RETURN NEW;
END $$;


--
-- Name: quality_scope_integrity(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.quality_scope_integrity() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM quality_audits WHERE id=NEW.audit_id AND organization_id=NEW.organization_id) THEN RAISE EXCEPTION 'Auditoria de outra empresa.'; END IF;
 IF NEW.kind='area' AND NOT EXISTS(SELECT 1 FROM quality_areas WHERE id=NEW.area_id AND organization_id=NEW.organization_id) THEN RAISE EXCEPTION 'Área de outra empresa.'; END IF;
 IF NEW.kind='standard' AND NOT EXISTS(SELECT 1 FROM quality_catalogs WHERE id=NEW.standard_id AND organization_id=NEW.organization_id AND kind='standard') THEN RAISE EXCEPTION 'Referencial inválido.'; END IF;
 RETURN NEW;
END $$;


--
-- Name: quality_seed_nc_classifications(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.quality_seed_nc_classifications() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
 INSERT INTO quality_catalogs(organization_id,kind,name,active,is_system)
 VALUES(NEW.id,'nc_classification','NC Menor',true,true),(NEW.id,'nc_classification','NC Maior',true,true);
 RETURN NEW;
END $$;


--
-- Name: quality_version(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.quality_version() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN NEW.version:=OLD.version+1;NEW.updated_at:=clock_timestamp(); RETURN NEW; END $$;


--
-- Name: record_has_usage(text, uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.record_has_usage(p_table text, p_id uuid, p_org uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $_$
DECLARE r record; found boolean; value text;
BEGIN
 FOR r IN SELECT ns.nspname schema,cl.relname child,a.attname col FROM pg_constraint c JOIN pg_class cl ON cl.oid=c.conrelid JOIN pg_namespace ns ON ns.oid=cl.relnamespace JOIN pg_attribute a ON a.attrelid=cl.oid AND a.attnum=c.conkey[1]
 WHERE c.contype='f' AND c.confrelid=to_regclass('public.'||p_table) AND array_length(c.conkey,1)=1 LOOP
  IF p_table='profiles' AND ((r.child='user_assignments' AND r.col='user_id') OR (r.child='organization_memberships' AND r.col='user_id')) THEN CONTINUE; END IF;
  EXECUTE format('SELECT EXISTS(SELECT 1 FROM %I.%I WHERE %I=$1)',r.schema,r.child,r.col) INTO found USING p_id;
  IF found THEN RETURN true; END IF;
 END LOOP;
 IF EXISTS(SELECT 1 FROM audit_log WHERE organization_id=p_org AND entity_type<>p_table AND NOT(p_table='profiles' AND entity_type IN ('user_assignments','organization_memberships')) AND (old_data::text LIKE '%'||p_id||'%' OR new_data::text LIKE '%'||p_id||'%')) THEN RETURN true; END IF;
 IF p_table='quality_catalogs' THEN
  SELECT name INTO value FROM quality_catalogs WHERE id=p_id;
  IF EXISTS(SELECT 1 FROM quality_occurrences WHERE organization_id=p_org AND (classification=value OR standard=value)) OR EXISTS(SELECT 1 FROM audit_log WHERE organization_id=p_org AND entity_type='quality_occurrences' AND (old_data->>'classification'=value OR new_data->>'classification'=value OR old_data->>'standard'=value OR new_data->>'standard'=value)) THEN RETURN true; END IF;
 END IF;
 RETURN false;
END $_$;


--
-- Name: seed_occurrence(text, text, text, text, text, text, date, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.seed_occurrence(p_type text, p_reference text, p_origin text, p_area text, p_desc text, p_resp text, p_date date, p_status text, p_eff text DEFAULT NULL::text, p_cause text DEFAULT NULL::text) RETURNS void
    LANGUAGE plpgsql
    AS $$
declare v_origin uuid; v_area uuid; v_resp uuid; v_eff text; v_closed timestamptz; v_validated timestamptz;
begin
  select id into v_origin from public.quality_origins where name = p_origin;
  select id into v_area   from public.quality_areas  where name = p_area;
  select id into v_resp   from public.profiles       where full_name = p_resp;
  v_eff := p_eff;
  v_closed := case when p_status='CLOSED' then p_date + interval '30 days' else null end;
  v_validated := case when v_eff is not null then p_date + interval '25 days' else null end;
  insert into public.quality_occurrences
      (reference, year, type, origin_id, area_id, description, responsible_user_id, occurrence_date,
       status, cause_analysis, effectiveness_status, effectiveness_validated_at, closed_at, created_by, created_at)
    values
      (p_reference, extract(year from p_date)::int, p_type::public.occurrence_type, v_origin, v_area, p_desc, v_resp, p_date,
       p_status::public.occurrence_status, p_cause, v_eff, v_validated, v_closed, '11111111-1111-1111-1111-111111111111', p_date)
    on conflict (reference) do nothing;
end;
$$;


--
-- Name: session_valid(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.session_valid() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
 SELECT EXISTS(SELECT 1 FROM profiles p WHERE p.id=auth.uid() AND p.active AND p.session_version=coalesce(nullif(current_setting('request.jwt.claims',true),'')::jsonb->>'sv','0')::integer)
$$;


--
-- Name: set_lifecycle_pessoas_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_lifecycle_pessoas_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END $$;


--
-- Name: set_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_updated_at() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


--
-- Name: strategy_context_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.strategy_context_guard() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ DECLARE campaign swot_campaigns; BEGIN
 SELECT * INTO campaign FROM swot_campaigns WHERE id=NEW.campaign_id FOR UPDATE;
 IF campaign.organization_id IS DISTINCT FROM NEW.organization_id THEN RAISE EXCEPTION 'Campanha de outra empresa.'; END IF;
 IF campaign.quota_mode='participant_context' THEN
  IF NEW.thematic_area_id IS NULL OR NEW.contribution_scope IS NULL OR NOT EXISTS(SELECT 1 FROM strategy_thematic_areas WHERE id=NEW.thematic_area_id AND organization_id=NEW.organization_id AND active) THEN RAISE EXCEPTION 'Seleciona a área temática e o contexto.'; END IF;
  IF (NEW.contribution_scope='organization') IS DISTINCT FROM (NEW.team_id IS NULL) THEN RAISE EXCEPTION 'Seleciona a equipa correspondente ao contexto.'; END IF;
  IF EXISTS(SELECT 1 FROM swot_submissions WHERE campaign_id=NEW.campaign_id AND user_id=NEW.user_id) THEN RAISE EXCEPTION 'Participação já submetida.'; END IF;
 END IF; RETURN NEW;
END $$;


--
-- Name: strategy_membership_active_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.strategy_membership_active_guard() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN
 IF NEW.active AND (TG_OP='INSERT' OR NEW.user_id IS DISTINCT FROM OLD.user_id OR NOT OLD.active) AND NOT EXISTS(SELECT 1 FROM profiles WHERE id=NEW.user_id AND active AND organization_id=NEW.organization_id) THEN RAISE EXCEPTION 'Só é possível associar utilizadores ativos da organização selecionada.'; END IF;
 RETURN NEW;
END $$;


--
-- Name: strategy_structure_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.strategy_structure_guard() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ DECLARE used boolean; BEGIN
 used:=record_has_usage(TG_TABLE_NAME,OLD.id,OLD.organization_id) OR EXISTS(SELECT 1 FROM platform_admin_history WHERE organization_id=OLD.organization_id AND entity_type<>TG_TABLE_NAME AND (before_data::text LIKE '%'||OLD.id||'%' OR after_data::text LIKE '%'||OLD.id||'%')) OR EXISTS(SELECT 1 FROM strategy_history WHERE table_name<>TG_TABLE_NAME AND (before_data::text LIKE '%'||OLD.id||'%' OR after_data::text LIKE '%'||OLD.id||'%'));
 IF used AND TG_OP='DELETE' THEN RAISE EXCEPTION 'Registo utilizado. Desative ou arquive para preservar as dependências e o histórico.'; END IF;
 IF TG_TABLE_NAME='cycles' AND TG_OP='UPDATE' AND used THEN
  IF NEW.framework_id IS DISTINCT FROM OLD.framework_id OR NEW.organization_id IS DISTINCT FROM OLD.organization_id THEN RAISE EXCEPTION 'Um ciclo utilizado mantém a empresa e o framework.'; END IF;
  IF NEW.start_date>OLD.start_date OR (NEW.end_date IS NOT NULL AND (OLD.end_date IS NULL OR NEW.end_date<OLD.end_date)) THEN RAISE EXCEPTION 'Um ciclo utilizado não pode ter o período reduzido. Pode alargar as datas ou criar um novo ciclo.'; END IF;
 END IF;
 IF TG_OP='UPDATE' AND NEW.organization_id IS DISTINCT FROM OLD.organization_id THEN RAISE EXCEPTION 'Não é possível transferir este registo para outra empresa.'; END IF;
 RETURN coalesce(NEW,OLD);
END $$;


--
-- Name: strategy_write(text, text, jsonb, uuid, timestamp with time zone, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.strategy_write(p_table text, p_operation text, p_payload jsonb DEFAULT '{}'::jsonb, p_id uuid DEFAULT NULL::uuid, p_expected_updated_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_human_confirmed boolean DEFAULT false) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $_$
DECLARE actor uuid := auth.uid(); before_row jsonb; after_row jsonb; fields text; vals text; assignments text; allowed text[]; bad text;
BEGIN
 IF NOT public.has_module('strategy') THEN RAISE EXCEPTION 'Sem acesso ao módulo Estratégia' USING ERRCODE='42501'; END IF;
 IF p_id IS NOT NULL AND p_table IN ('swot_items','tows_crossings','risk_opportunities','strategic_objectives','strategic_actions','kpis','kpi_targets','kpi_results') THEN
 EXECUTE format('SELECT to_jsonb(t) FROM public.%I t WHERE id=$1',p_table) INTO before_row USING p_id;
 IF NOT public.can_strategy_record(p_table,before_row) THEN RAISE EXCEPTION 'Registo de outra empresa' USING ERRCODE='42501'; END IF;
 ELSIF NOT public.can_strategy_record(p_table,p_payload) THEN RAISE EXCEPTION 'Empresa inválida' USING ERRCODE='42501'; END IF;

 IF actor IS NULL OR NOT public.has_responsibility('strategy',ARRAY['admin','quality']) THEN RAISE EXCEPTION 'Sem permissão para alterar estratégia' USING ERRCODE='42501'; END IF;
 IF p_human_confirmed IS DISTINCT FROM true THEN RAISE EXCEPTION 'Validação humana obrigatória' USING ERRCODE='42501'; END IF;
 allowed := CASE p_table
 WHEN 'swot_items' THEN ARRAY['campaign_id','quadrant','title','description','impact','probability','order_index']
 WHEN 'tows_crossings' THEN ARRAY['campaign_id','strategy_type','name','description','priority','s_item_id','w_item_id','o_item_id','t_item_id','disposition']
 WHEN 'risk_opportunities' THEN ARRAY['organization_id','cycle_id','reference','type','title','description','probability','impact','status','mitigation','responsible_id','due_date','source_tows_id']
 WHEN 'strategic_objectives' THEN ARRAY['organization_id','cycle_id','parent_id','code','name','description','perspective','weight','status','progress','responsible_id','start_date','due_date','risk_ids']
 WHEN 'strategic_actions' THEN ARRAY['objective_id','name','description','status','priority','responsible_id','start_date','due_date','progress','budget','actual_cost']
 WHEN 'kpis' THEN ARRAY['organization_id','objective_id','code','name','description','unit','direction','frequency','formula','data_source','responsible_id','active']
 WHEN 'kpi_targets' THEN ARRAY['kpi_id','period','target_value','warning_value']
 WHEN 'kpi_results' THEN ARRAY['kpi_id','period','value','notes'] END;
 IF allowed IS NULL OR p_operation NOT IN ('insert','update','delete') THEN RAISE EXCEPTION 'Operação inválida'; END IF;
 SELECT key INTO bad FROM jsonb_object_keys(p_payload) key WHERE NOT key=ANY(allowed) LIMIT 1;
 IF bad IS NOT NULL THEN RAISE EXCEPTION 'Campo não editável: %',bad; END IF;
 IF p_operation <> 'insert' THEN
   EXECUTE format('SELECT to_jsonb(t) FROM public.%I t WHERE id=$1 FOR UPDATE',p_table) INTO before_row USING p_id;
   IF before_row IS NULL THEN RAISE EXCEPTION 'Registo não encontrado'; END IF;
   IF p_expected_updated_at IS NULL OR (before_row->>'updated_at')::timestamptz IS DISTINCT FROM p_expected_updated_at THEN RAISE EXCEPTION 'O registo mudou. Recarrega antes de guardar.' USING ERRCODE='40001'; END IF;
   -- Never move existing records between organisations/parents.
   IF EXISTS(SELECT 1 FROM unnest(ARRAY['organization_id','campaign_id','objective_id','kpi_id']) x WHERE p_payload ? x AND before_row ? x AND NOT (p_table='kpis' AND x='objective_id') AND p_payload->x IS DISTINCT FROM before_row->x) THEN RAISE EXCEPTION 'Não é permitido mudar a origem do registo'; END IF;
 END IF;
 IF p_operation='delete' THEN
   IF p_table='swot_items' AND EXISTS(SELECT 1 FROM public.tows_crossings t WHERE p_id IN (t.s_item_id,t.w_item_id,t.o_item_id,t.t_item_id)) THEN RAISE EXCEPTION 'Item usado em TOWS; preserva a rastreabilidade'; END IF;
   IF p_table='risk_opportunities' AND EXISTS(SELECT 1 FROM public.strategic_objectives WHERE p_id=ANY(risk_ids)) THEN RAISE EXCEPTION 'Risco associado a objetivos'; END IF;
   IF p_table='strategic_objectives' AND (EXISTS(SELECT 1 FROM public.strategic_actions WHERE objective_id=p_id) OR EXISTS(SELECT 1 FROM public.kpis WHERE objective_id=p_id)) THEN RAISE EXCEPTION 'Objetivo com ações/KPIs: cancela-o para preservar histórico'; END IF;
   IF p_table='kpis' AND (EXISTS(SELECT 1 FROM public.kpi_targets WHERE kpi_id=p_id) OR EXISTS(SELECT 1 FROM public.kpi_results WHERE kpi_id=p_id)) THEN RAISE EXCEPTION 'KPI com histórico: desativa-o em vez de eliminar'; END IF;
   EXECUTE format('DELETE FROM public.%I WHERE id=$1',p_table) USING p_id;
 ELSE
   IF p_payload='{}'::jsonb THEN RAISE EXCEPTION 'Dados obrigatórios'; END IF;
   IF p_table='kpi_results' THEN p_payload:=p_payload || jsonb_build_object('entered_by',actor,'entered_at',now());
   ELSIF p_operation='insert' AND p_table<>'kpi_targets' THEN p_payload:=p_payload || jsonb_build_object('created_by',actor); END IF;
   SELECT string_agg(format('%I',key),','), string_agg(format('r.%I',key),','), string_agg(format('%I=r.%I',key,key),',') INTO fields,vals,assignments FROM jsonb_object_keys(p_payload) key;
   IF p_operation='insert' THEN
     EXECUTE format('INSERT INTO public.%I (%s) SELECT %s FROM jsonb_populate_record(NULL::public.%I,$1) r RETURNING to_jsonb(%I.*)',p_table,fields,vals,p_table,p_table) INTO after_row USING p_payload;
   ELSE
     EXECUTE format('UPDATE public.%I t SET %s FROM jsonb_populate_record(NULL::public.%I,$1) r WHERE t.id=$2 RETURNING to_jsonb(t.*)',p_table,assignments,p_table) INTO after_row USING p_payload,p_id;
   END IF;
 END IF;
 INSERT INTO public.strategy_history(table_name,record_id,operation,before_data,after_data,reviewed_by) VALUES(p_table,coalesce(p_id,(after_row->>'id')::uuid),p_operation,before_row,after_row,actor);
 RETURN coalesce(after_row,before_row);
END $_$;


--
-- Name: track_assignment_usage(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.track_assignment_usage() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN
 IF NEW.entity_type NOT IN ('user_assignments','profiles','organization_memberships','quality_auditors','quality_catalogs') THEN
 UPDATE user_assignments SET used_at=now() WHERE used_at IS NULL AND active AND (user_id=NEW.user_id OR user_id::text=NEW.new_data->>'responsible_user_id' OR user_id::text=NEW.new_data->>'responsible_id' OR user_id::text=NEW.new_data->>'approver_id');
 UPDATE profiles SET account_used=true WHERE NOT account_used AND (id=NEW.user_id OR id::text=NEW.new_data->>'responsible_user_id' OR id::text=NEW.new_data->>'responsible_id');
 END IF; RETURN NEW;
END $$;


--
-- Name: track_strategy_assignment_usage(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.track_strategy_assignment_usage() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ DECLARE actor uuid; BEGIN
 actor:=coalesce((to_jsonb(NEW)->>'actor_id')::uuid,(to_jsonb(NEW)->>'reviewed_by')::uuid);
 UPDATE user_assignments SET used_at=now() WHERE used_at IS NULL AND active AND (user_id=actor OR user_id::text=NEW.after_data->>'responsible_id') AND (starts_on IS NULL OR starts_on<=current_date) AND (ends_on IS NULL OR ends_on>=current_date);
 UPDATE profiles SET account_used=true WHERE NOT account_used AND id=actor;
 RETURN NEW; END $$;


--
-- Name: update_occurrence_status_from_actions(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_occurrence_status_from_actions() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE target uuid; total integer;pending integer;required boolean;current_state occurrence_status;
BEGIN
 target:=coalesce(NEW.occurrence_id,OLD.occurrence_id);IF target IS NULL THEN RETURN coalesce(NEW,OLD);END IF;
 SELECT status,effectiveness_required INTO current_state,required FROM quality_occurrences WHERE id=target AND cancelled_at IS NULL FOR UPDATE;
 IF NOT FOUND OR current_state='CLOSED' THEN RETURN coalesce(NEW,OLD);END IF;
 SELECT count(*),count(*) FILTER(WHERE status<>'COMPLETED') INTO total,pending FROM quality_actions WHERE occurrence_id=target AND status<>'CANCELLED' AND mandatory;
 UPDATE quality_occurrences SET status=CASE WHEN total>0 AND pending=0 AND required THEN 'AWAITING_EFFECTIVENESS'::occurrence_status ELSE 'IN_PROGRESS'::occurrence_status END WHERE id=target;
 RETURN coalesce(NEW,OLD);
END $$;


--
-- Name: validate_strategy_record(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.validate_strategy_record() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $_$
DECLARE j jsonb := to_jsonb(NEW); parent_org uuid; related_org uuid; factor record; freq text; per text; k record;
BEGIN
 IF j ? 'title' AND btrim(coalesce(j->>'title','')) = '' OR j ? 'name' AND btrim(coalesce(j->>'name','')) = '' OR j ? 'code' AND btrim(coalesce(j->>'code','')) = '' THEN RAISE EXCEPTION 'Título, nome ou código obrigatório'; END IF;
 IF j ? 'progress' AND ((j->>'progress')::numeric IS NULL OR (j->>'progress')::numeric NOT BETWEEN 0 AND 100) THEN RAISE EXCEPTION 'Progresso entre 0 e 100'; END IF;
 IF nullif(j->>'start_date','')::date > nullif(j->>'due_date','')::date THEN RAISE EXCEPTION 'Prazo anterior ao início'; END IF;
 IF TG_TABLE_NAME = 'swot_items' AND TG_OP='UPDATE' THEN
   IF (NEW.quadrant IS DISTINCT FROM OLD.quadrant OR NEW.campaign_id IS DISTINCT FROM OLD.campaign_id) AND EXISTS(SELECT 1 FROM public.tows_crossings WHERE OLD.id IN (s_item_id,w_item_id,o_item_id,t_item_id)) THEN RAISE EXCEPTION 'Item usado em TOWS; preserva o quadrante e a campanha de origem'; END IF;
 ELSIF TG_TABLE_NAME = 'tows_crossings' THEN
   FOR factor IN SELECT * FROM (VALUES ('s_item_id','strengths', NEW.strategy_type::text IN ('so','st')), ('w_item_id','weaknesses', NEW.strategy_type::text IN ('wo','wt')), ('o_item_id','opportunities', NEW.strategy_type::text IN ('so','wo')), ('t_item_id','threats', NEW.strategy_type::text IN ('st','wt'))) f(field, quadrant, needed) LOOP
     IF factor.needed AND NOT EXISTS (SELECT 1 FROM public.swot_items s WHERE s.id = nullif(j->>factor.field,'')::uuid AND s.campaign_id = NEW.campaign_id AND s.quadrant::text = factor.quadrant) THEN RAISE EXCEPTION 'Cruzamento exige os dois fatores da mesma campanha e quadrantes corretos'; END IF;
     IF NOT factor.needed AND j->>factor.field IS NOT NULL THEN RAISE EXCEPTION 'Fator incompatível com o tipo TOWS'; END IF;
   END LOOP;
 ELSIF TG_TABLE_NAME = 'risk_opportunities' THEN
   IF NEW.probability IS NULL OR NEW.impact IS NULL THEN RAISE EXCEPTION 'Impacto e probabilidade obrigatórios'; END IF;
   IF NEW.source_tows_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.tows_crossings t JOIN public.swot_campaigns c ON c.id=t.campaign_id WHERE t.id=NEW.source_tows_id AND c.organization_id=NEW.organization_id) THEN RAISE EXCEPTION 'Origem TOWS de outra organização'; END IF;
   IF NEW.status IN ('mitigating','monitored','closed') AND btrim(coalesce(NEW.mitigation,''))='' THEN RAISE EXCEPTION 'Tratamento/decisão obrigatório neste estado'; END IF;
   NEW.closed_at := CASE WHEN NEW.status='closed' THEN coalesce(NEW.closed_at, now()) ELSE NULL END;
 ELSIF TG_TABLE_NAME = 'strategic_objectives' THEN
   IF EXISTS (SELECT 1 FROM unnest(NEW.risk_ids) r(id) WHERE NOT EXISTS (SELECT 1 FROM public.risk_opportunities x WHERE x.id=r.id AND x.organization_id=NEW.organization_id)) THEN RAISE EXCEPTION 'Risco associado inválido ou de outra organização'; END IF;
   IF NEW.status='achieved' AND NEW.progress<>100 THEN RAISE EXCEPTION 'Objetivo alcançado exige progresso 100'; END IF;
   NEW.achieved_at := CASE WHEN NEW.status='achieved' THEN coalesce(NEW.achieved_at,now()) ELSE NULL END;
 ELSIF TG_TABLE_NAME = 'strategic_actions' THEN
   IF NEW.status='completed' THEN NEW.progress:=100; NEW.completed_at:=coalesce(NEW.completed_at,now()); ELSE NEW.completed_at:=NULL; END IF;
   IF NEW.budget<0 OR NEW.actual_cost<0 THEN RAISE EXCEPTION 'Custos não podem ser negativos'; END IF;
 ELSIF TG_TABLE_NAME = 'kpis' THEN
   IF NEW.objective_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.strategic_objectives o WHERE o.id=NEW.objective_id AND o.organization_id=NEW.organization_id) THEN RAISE EXCEPTION 'Objetivo de outra organização'; END IF;
   IF TG_OP='UPDATE' AND NEW.frequency IS DISTINCT FROM OLD.frequency AND (EXISTS(SELECT 1 FROM public.kpi_targets WHERE kpi_id=NEW.id) OR EXISTS(SELECT 1 FROM public.kpi_results WHERE kpi_id=NEW.id)) THEN RAISE EXCEPTION 'KPI com histórico: criar outro KPI para mudar frequência'; END IF;
 ELSIF TG_TABLE_NAME IN ('kpi_targets','kpi_results') THEN
   SELECT * INTO k FROM public.kpis WHERE id=NEW.kpi_id;
   freq:=coalesce(k.frequency::text,'monthly'); per:=NEW.period;
   IF NOT (CASE freq WHEN 'daily' THEN per ~ '^\d{4}-\d{2}-\d{2}$' WHEN 'weekly' THEN per ~ '^\d{4}-W(0[1-9]|[1-4]\d|5[0-3])$' WHEN 'monthly' THEN per ~ '^\d{4}-(0[1-9]|1[0-2])$' WHEN 'quarterly' THEN per ~ '^\d{4}-Q[1-4]$' WHEN 'yearly' THEN per ~ '^\d{4}$' ELSE false END) THEN RAISE EXCEPTION 'Período incompatível com a frequência'; END IF;
   IF freq='daily' AND to_char(per::date,'YYYY-MM-DD')<>per THEN RAISE EXCEPTION 'Data inválida'; END IF;
   IF freq='weekly' AND to_char(to_date(per||'-1','IYYY-"W"IW-ID'),'IYYY-"W"IW')<>per THEN RAISE EXCEPTION 'Semana ISO inválida'; END IF;
   IF TG_TABLE_NAME='kpi_targets' THEN
     IF NEW.target_value::text IN ('NaN','Infinity','-Infinity') OR NEW.warning_value::text IN ('NaN','Infinity','-Infinity') THEN RAISE EXCEPTION 'Valor não finito'; END IF;
     IF k.direction='higher_is_better' AND NEW.warning_value>NEW.target_value OR k.direction='lower_is_better' AND NEW.warning_value<NEW.target_value OR k.direction='target' AND NEW.warning_value<0 THEN RAISE EXCEPTION 'Alerta incompatível com direção/meta'; END IF;
   ELSIF NEW.value::text IN ('NaN','Infinity','-Infinity') THEN RAISE EXCEPTION 'Resultado não finito'; END IF;
 END IF;
 RETURN NEW;
END $_$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: users; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.users (
    id uuid NOT NULL,
    email text,
    raw_user_meta_data jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    password_hash text,
    role text DEFAULT 'authenticated'::text
);


--
-- Name: ai_action_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_action_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    channel text,
    tool_name text NOT NULL,
    target_type text,
    target_id uuid,
    confirmation_id uuid,
    result_status text,
    created_at timestamp with time zone DEFAULT now(),
    organization_id uuid DEFAULT public.current_company_context() NOT NULL
);


--
-- Name: ai_interactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_interactions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    occurrence_id uuid,
    feature text,
    provider text,
    model text,
    input_reference text,
    result jsonb,
    accepted boolean,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    organization_id uuid DEFAULT public.current_company_context() NOT NULL
);


--
-- Name: ai_pending_actions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_pending_actions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    channel text,
    conversation_id text,
    tool_name text NOT NULL,
    payload_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    confirmation_token_hash text NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    confirmed_at timestamp with time zone,
    executed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    organization_id uuid DEFAULT public.current_company_context() NOT NULL,
    CONSTRAINT ai_pending_actions_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'confirmed'::text, 'cancelled'::text, 'expired'::text, 'executed'::text, 'failed'::text])))
);


--
-- Name: ai_query_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_query_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    question text,
    intent text,
    filters jsonb,
    model text,
    duration_ms integer,
    status text DEFAULT 'success'::text NOT NULL,
    rows_processed integer,
    error text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    organization_id uuid DEFAULT public.current_company_context() NOT NULL
);


--
-- Name: app_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.app_settings (
    key text NOT NULL,
    value text NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: app_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.app_versions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    platform text NOT NULL,
    version text NOT NULL,
    release_notes text,
    min_required boolean DEFAULT false NOT NULL,
    active boolean DEFAULT true NOT NULL,
    released_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: archive_locations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.archive_locations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    name text NOT NULL,
    description text,
    location_type text DEFAULT 'folder'::text NOT NULL,
    location_path text,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: audit_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    entity_type text NOT NULL,
    entity_id uuid,
    action text NOT NULL,
    old_data jsonb,
    new_data jsonb,
    changed_fields jsonb,
    user_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    organization_id uuid DEFAULT public.current_company_context() NOT NULL
);


--
-- Name: auth_password_resets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.auth_password_resets (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    token_hash text NOT NULL,
    session_version integer NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    used_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: auth_recovery_attempts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.auth_recovery_attempts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    email_hash text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    outcome text NOT NULL,
    CONSTRAINT auth_recovery_attempts_outcome_check CHECK ((outcome = ANY (ARRAY['pending'::text, 'sent'::text, 'unavailable'::text, 'failed'::text, 'unknown'::text])))
);


--
-- Name: brand_assets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.brand_assets (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    brand_kit_id uuid NOT NULL,
    kind text NOT NULL,
    mime_type text NOT NULL,
    content_base64 text NOT NULL,
    width integer NOT NULL,
    height integer NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT brand_assets_kind_check CHECK ((kind = ANY (ARRAY['logo'::text, 'icon'::text, 'favicon'::text])))
);


--
-- Name: brand_kits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.brand_kits (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    name text NOT NULL,
    is_default boolean DEFAULT false NOT NULL,
    primary_color text DEFAULT '#7367f0'::text,
    secondary_color text DEFAULT '#00cfe8'::text,
    background_color text DEFAULT '#ffffff'::text,
    text_color text DEFAULT '#2c2c2c'::text,
    accent_color text DEFAULT '#28c76f'::text,
    danger_color text DEFAULT '#ea5455'::text,
    warning_color text DEFAULT '#ff9f43'::text,
    info_color text DEFAULT '#00cfe8'::text,
    success_color text DEFAULT '#28c76f'::text,
    logo_url text,
    font_heading text DEFAULT 'Inter'::text,
    font_body text DEFAULT 'Inter'::text,
    slide_master jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    logo_asset_id uuid,
    icon_asset_id uuid,
    favicon_asset_id uuid
);


--
-- Name: connector_instances; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.connector_instances (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    connector_id uuid NOT NULL,
    organization_id uuid NOT NULL,
    name text NOT NULL,
    credentials jsonb DEFAULT '{}'::jsonb,
    settings jsonb DEFAULT '{}'::jsonb,
    status public.connector_status DEFAULT 'inactive'::public.connector_status NOT NULL,
    last_sync_at timestamp with time zone,
    last_error text,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: connectors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.connectors (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    name text NOT NULL,
    description text,
    provider text NOT NULL,
    config_schema jsonb DEFAULT '{}'::jsonb,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: cycles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cycles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    framework_id uuid,
    name text NOT NULL,
    description text,
    start_date date NOT NULL,
    end_date date,
    status text DEFAULT 'draft'::text NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: data_reset_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.data_reset_history (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    actor_id uuid NOT NULL,
    organization_id uuid NOT NULL,
    module text NOT NULL,
    record_counts jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT data_reset_history_module_check CHECK ((module = ANY (ARRAY['quality'::text, 'lifecycle'::text, 'strategy'::text])))
);


--
-- Name: TABLE data_reset_history; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.data_reset_history IS 'Retained administrative reset audit; contains counts only, never deleted record contents.';


--
-- Name: decisions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.decisions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    meeting_id uuid,
    code text,
    title text NOT NULL,
    description text,
    rationale text,
    status public.decision_status DEFAULT 'proposed'::public.decision_status NOT NULL,
    impact_level text,
    decided_by uuid,
    decided_at timestamp with time zone,
    implemented_at timestamp with time zone,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: effectiveness_evaluations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.effectiveness_evaluations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    objective_id uuid,
    action_id uuid,
    kpi_id uuid,
    evaluated_at timestamp with time zone DEFAULT now() NOT NULL,
    result public.effectiveness_result DEFAULT 'pending'::public.effectiveness_result NOT NULL,
    score numeric(5,2),
    observations text,
    evidence_links jsonb DEFAULT '[]'::jsonb,
    evaluated_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: evidences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.evidences (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    decision_id uuid,
    objective_id uuid,
    action_id uuid,
    kpi_id uuid,
    title text NOT NULL,
    description text,
    file_url text,
    file_type text,
    file_size bigint,
    uploaded_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: external_ai_identities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.external_ai_identities (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    channel text NOT NULL,
    external_user_id text NOT NULL,
    external_chat_id text,
    external_phone_hash text,
    verified_at timestamp with time zone DEFAULT now(),
    revoked_at timestamp with time zone,
    is_active boolean DEFAULT true,
    last_seen_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT external_ai_identities_channel_check CHECK ((channel = ANY (ARRAY['telegram'::text, 'whatsapp'::text, 'teams'::text, 'slack'::text, 'web'::text])))
);


--
-- Name: feature_flags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.feature_flags (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    key text NOT NULL,
    enabled boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    description text
);


--
-- Name: frameworks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.frameworks (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    description text,
    type text DEFAULT 'strategic'::text NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: generated_files; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.generated_files (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    template_id uuid,
    meeting_id uuid,
    name text NOT NULL,
    file_type text DEFAULT 'pptx'::text NOT NULL,
    file_path text,
    file_size bigint,
    status public.generated_file_status DEFAULT 'queued'::public.generated_file_status NOT NULL,
    error_message text,
    generated_by uuid,
    generated_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: import_registry; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.import_registry (
    id bigint NOT NULL,
    src_file text NOT NULL,
    sheet text NOT NULL,
    row_num integer NOT NULL,
    reference text NOT NULL,
    module text NOT NULL,
    kind text NOT NULL,
    status text NOT NULL,
    target_id uuid,
    raw_data jsonb NOT NULL,
    anomalies jsonb DEFAULT '[]'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    organization_id uuid DEFAULT public.current_company_context() NOT NULL
);


--
-- Name: TABLE import_registry; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.import_registry IS 'Registo de importação de dados de Gestão da Qualidade a partir de Excel (Ações/NC/OM).';


--
-- Name: import_registry_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.import_registry ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.import_registry_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: kpi_results; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.kpi_results (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    kpi_id uuid NOT NULL,
    period text NOT NULL,
    value numeric(15,4) NOT NULL,
    notes text,
    entered_by uuid,
    entered_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: kpi_targets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.kpi_targets (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    kpi_id uuid NOT NULL,
    period text NOT NULL,
    target_value numeric(15,4) NOT NULL,
    warning_value numeric(15,4),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: kpis; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.kpis (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    objective_id uuid,
    code text NOT NULL,
    name text NOT NULL,
    description text,
    unit text,
    direction public.kpi_direction DEFAULT 'higher_is_better'::public.kpi_direction,
    frequency public.kpi_frequency DEFAULT 'monthly'::public.kpi_frequency,
    formula text,
    data_source text,
    responsible_id uuid,
    active boolean DEFAULT true NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: lifecycle_avaliacoes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lifecycle_avaliacoes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    caso_id uuid NOT NULL,
    vaga_id uuid,
    pessoa_id uuid,
    score_global numeric(5,2),
    score_requisitos numeric(5,2),
    score_preferenciais numeric(5,2),
    score_competencias numeric(5,2),
    score_experiencia numeric(5,2),
    score_formacao numeric(5,2),
    score_idiomas numeric(5,2),
    score_disponibilidade numeric(5,2),
    razao jsonb DEFAULT '[]'::jsonb,
    competencias_encontradas jsonb DEFAULT '[]'::jsonb,
    competencias_em_falta jsonb DEFAULT '[]'::jsonb,
    alertas jsonb DEFAULT '[]'::jsonb,
    perguntas_entrevista jsonb DEFAULT '[]'::jsonb,
    recomendacao_ia text,
    decisao_humana text,
    decisao_humana_em timestamp with time zone,
    decisao_humana_por uuid,
    notas_humanas text,
    modelo_ia text,
    prompt_version text,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    organization_id uuid DEFAULT public.current_company_context() NOT NULL
);


--
-- Name: lifecycle_casos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lifecycle_casos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    reference text NOT NULL,
    vaga_id uuid,
    nome text NOT NULL,
    email text,
    telefone text,
    origem text,
    fonte text,
    tipo public.lifecycle_case_type DEFAULT 'recrutamento'::public.lifecycle_case_type NOT NULL,
    estado public.lifecycle_case_status DEFAULT 'CANDIDATURA_RECEBIDA'::public.lifecycle_case_status NOT NULL,
    cv_url text,
    consentimento boolean DEFAULT false NOT NULL,
    consentimento_em timestamp with time zone,
    score integer,
    decisao_triagem text,
    motivo_encerramento text,
    data_entrada date,
    funcao text,
    equipa text,
    dados jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    tipo_vinculo text,
    estado_admissao text,
    ready_day1_flag boolean DEFAULT false NOT NULL,
    ready_day1_em timestamp with time zone,
    data_saida date,
    motivo_saida text,
    estado_offboarding text,
    offboarding_em timestamp with time zone,
    offboarding_concluido_em timestamp with time zone,
    dedup_hash text,
    duplicado_de uuid,
    aviso_duplicado boolean DEFAULT false NOT NULL,
    pessoa_id uuid,
    organization_id uuid DEFAULT public.current_company_context() NOT NULL
);


--
-- Name: lifecycle_certificacoes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lifecycle_certificacoes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    pessoa_id uuid NOT NULL,
    nome text NOT NULL,
    entidade text,
    data_emissao date,
    validade date,
    identificador text,
    link_validacao text,
    competencias jsonb DEFAULT '[]'::jsonb,
    estado_validade text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    organization_id uuid DEFAULT public.current_company_context() NOT NULL
);


--
-- Name: lifecycle_competencias; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lifecycle_competencias (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    pessoa_id uuid NOT NULL,
    nome text NOT NULL,
    categoria text,
    nivel_indicado text,
    anos_experiencia numeric,
    ultima_utilizacao date,
    origem_dado text DEFAULT 'introducao_manual'::text NOT NULL,
    confirmado boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    organization_id uuid DEFAULT public.current_company_context() NOT NULL
);


--
-- Name: lifecycle_comunicacoes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lifecycle_comunicacoes (
    id bigint NOT NULL,
    caso_id uuid,
    ref text NOT NULL,
    tipo text NOT NULL,
    destino text,
    template text,
    estado text DEFAULT 'PENDENTE'::text NOT NULL,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    enviado_em timestamp with time zone,
    erro text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    organization_id uuid DEFAULT public.current_company_context() NOT NULL
);


--
-- Name: lifecycle_comunicacoes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.lifecycle_comunicacoes ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.lifecycle_comunicacoes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: lifecycle_cv_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lifecycle_cv_jobs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid,
    user_id uuid,
    file_name text NOT NULL,
    file_path text NOT NULL,
    file_hash text,
    file_size bigint,
    file_mime text DEFAULT 'application/pdf'::text,
    status text DEFAULT 'QUEUED'::text NOT NULL,
    etapa text DEFAULT 'queued'::text,
    progress numeric(5,2) DEFAULT 0,
    attempt integer DEFAULT 0,
    submitted_at timestamp with time zone DEFAULT now(),
    queued_at timestamp with time zone,
    started_at timestamp with time zone,
    finished_at timestamp with time zone,
    duration_ms bigint,
    model_ia text,
    prompt_version text,
    caso_id uuid,
    pessoa_id uuid,
    vaga_id uuid,
    extracted_text text,
    analysis_json jsonb,
    duplicated_of uuid,
    error_message text,
    error_details jsonb,
    cancel_requested_by uuid,
    cancel_requested_at timestamp with time zone,
    cancelled_by uuid,
    cancelled_at timestamp with time zone,
    viewed boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    arquivado_at timestamp with time zone,
    organization_id uuid DEFAULT public.current_company_context() NOT NULL
);


--
-- Name: lifecycle_entrevistas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lifecycle_entrevistas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    caso_id uuid NOT NULL,
    tipo text DEFAULT 'entrevista'::text NOT NULL,
    data_hora timestamp with time zone,
    duracao_min integer,
    local_ou_ligacao text,
    entrevistadores jsonb DEFAULT '[]'::jsonb,
    guiao text,
    criterios jsonb DEFAULT '[]'::jsonb,
    classificacao_geral numeric(4,2),
    notas_privadas text,
    parecer text,
    proximos_passos text,
    criado_por uuid,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL,
    organization_id uuid DEFAULT public.current_company_context() NOT NULL
);


--
-- Name: lifecycle_experiencias; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lifecycle_experiencias (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    pessoa_id uuid NOT NULL,
    empresa text NOT NULL,
    cargo text,
    local text,
    data_inicio date,
    data_fim date,
    emprego_atual boolean DEFAULT false NOT NULL,
    duracao_meses integer,
    descricao text,
    responsabilidades jsonb DEFAULT '[]'::jsonb,
    projetos jsonb DEFAULT '[]'::jsonb,
    tecnologias jsonb DEFAULT '[]'::jsonb,
    ferramentas jsonb DEFAULT '[]'::jsonb,
    resultados text,
    setor text,
    tipo_vinculo text,
    origem_dado text DEFAULT 'introducao_manual'::text NOT NULL,
    data_inicio_parcial text,
    data_fim_parcial text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    organization_id uuid DEFAULT public.current_company_context() NOT NULL
);


--
-- Name: lifecycle_formacoes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lifecycle_formacoes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    pessoa_id uuid NOT NULL,
    grau text,
    curso text,
    area_estudo text,
    instituicao text,
    pais_local text,
    data_inicio date,
    data_conclusao date,
    data_inicio_parcial text,
    data_fim_parcial text,
    estado text DEFAULT 'concluido'::text,
    classificacao text,
    observacoes text,
    equivalencia text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    organization_id uuid DEFAULT public.current_company_context() NOT NULL
);


--
-- Name: lifecycle_idiomas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lifecycle_idiomas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    pessoa_id uuid NOT NULL,
    idioma text NOT NULL,
    nivel_global text,
    compreensao text,
    conversacao text,
    escrita text,
    certificacao text,
    nivel_cefr text,
    lingua_materna boolean DEFAULT false NOT NULL,
    origem_dado text DEFAULT 'introducao_manual'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    organization_id uuid DEFAULT public.current_company_context() NOT NULL
);


--
-- Name: lifecycle_pessoas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lifecycle_pessoas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nome_completo text NOT NULL,
    nome_preferido text,
    fotografia_url text,
    data_nascimento date,
    nacionalidade text,
    pais_residencia text,
    distrito text,
    concelho text,
    localidade text,
    codigo_postal text,
    morada text,
    pronome text,
    numero_interno text,
    estado_ficha text DEFAULT 'ATIVA'::text NOT NULL,
    email text,
    email_alternativo text,
    indicativo_telefone text,
    telefone text,
    telefone_alternativo text,
    linkedin text,
    github text,
    portfolio text,
    website text,
    outros_links jsonb DEFAULT '[]'::jsonb,
    canal_contacto_pref text,
    consentimento_contactos boolean DEFAULT false NOT NULL,
    titulo_atual text,
    empresa_atual text,
    area_profissional text,
    senioridade text,
    anos_experiencia numeric,
    situacao_atual text,
    disponibilidade_inicio text,
    prazo_pre_aviso text,
    regime text,
    tipo_vinculo_pretendido text,
    disponibilidade_geo text,
    disponibilidade_desloc boolean,
    disponibilidade_viagem boolean,
    disponibilidade_mudar boolean,
    carta_conducao boolean,
    viatura_propria boolean,
    autorizado_trabalhar_pt boolean,
    resumo_original text,
    resumo_gerado_ia text,
    perfil text,
    areas_experiencia jsonb DEFAULT '[]'::jsonb,
    competencias_principais jsonb DEFAULT '[]'::jsonb,
    objetivos_profissionais text,
    setores jsonb DEFAULT '[]'::jsonb,
    pontos_fortes jsonb DEFAULT '[]'::jsonb,
    info_em_falta jsonb DEFAULT '[]'::jsonb,
    perguntas_entrevista jsonb DEFAULT '[]'::jsonb,
    funcoes_pretendidas jsonb DEFAULT '[]'::jsonb,
    areas_pretendidas jsonb DEFAULT '[]'::jsonb,
    expectativa_salarial numeric,
    moeda text DEFAULT 'EUR'::text,
    periodicidade_salarial text,
    beneficios jsonb DEFAULT '[]'::jsonb,
    horario text,
    regime_pretendido text,
    localizacao_pretendida text,
    contrato_pretendido text,
    cv_hash text,
    cv_ultima_url text,
    duplicados_fundidos jsonb DEFAULT '[]'::jsonb,
    notas_internas text,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    organization_id uuid DEFAULT public.current_company_context() NOT NULL,
    CONSTRAINT lifecycle_pessoas_estado_ficha_check CHECK ((estado_ficha = ANY (ARRAY['ATIVA'::text, 'INATIVA'::text, 'CONTRATADA'::text, 'ELIMINADA'::text, 'ANONIMIZADA'::text])))
);


--
-- Name: lifecycle_projetos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lifecycle_projetos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    pessoa_id uuid NOT NULL,
    nome text NOT NULL,
    descricao text,
    papel text,
    tecnologias jsonb DEFAULT '[]'::jsonb,
    data date,
    link text,
    resultados text,
    tipo text DEFAULT 'profissional'::text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    organization_id uuid DEFAULT public.current_company_context() NOT NULL
);


--
-- Name: lifecycle_referencias; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lifecycle_referencias (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    pessoa_id uuid NOT NULL,
    nome text NOT NULL,
    empresa text,
    cargo text,
    relacao text,
    contacto text,
    autorizacao boolean DEFAULT false NOT NULL,
    estado_verificacao text DEFAULT 'por_verificar'::text,
    notas text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    organization_id uuid DEFAULT public.current_company_context() NOT NULL
);


--
-- Name: lifecycle_tarefas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lifecycle_tarefas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    caso_id uuid NOT NULL,
    titulo text NOT NULL,
    descricao text,
    responsavel uuid,
    sector text,
    due_date date,
    status text DEFAULT 'TODO'::text NOT NULL,
    sla_atraso boolean DEFAULT false NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    completed_at timestamp with time zone,
    gate text,
    depends_on uuid,
    sla_ms integer,
    organization_id uuid DEFAULT public.current_company_context() NOT NULL
);


--
-- Name: lifecycle_vagas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lifecycle_vagas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    reference text NOT NULL,
    titulo text NOT NULL,
    departamento text,
    funcao text,
    local text,
    tipo text DEFAULT 'colaborador'::text NOT NULL,
    motivo text,
    data_desejada date,
    estado text DEFAULT 'APROVACAO_PENDENTE'::text NOT NULL,
    aprovador uuid,
    aprovado_em timestamp with time zone,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    requisitos jsonb DEFAULT '{"obrigatorios": [], "preferenciais": []}'::jsonb,
    organization_id uuid DEFAULT public.current_company_context() NOT NULL
);


--
-- Name: meeting_presenters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.meeting_presenters (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    meeting_id uuid NOT NULL,
    user_id uuid NOT NULL,
    topic text,
    order_index integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: meetings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.meetings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    cycle_id uuid,
    title text NOT NULL,
    description text,
    meeting_type text,
    status public.meeting_status DEFAULT 'scheduled'::public.meeting_status NOT NULL,
    scheduled_at timestamp with time zone NOT NULL,
    duration_min integer,
    location text,
    online_url text,
    minutes text,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notifications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    type text NOT NULL,
    title text NOT NULL,
    message text,
    entity_type text,
    entity_id uuid,
    read boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    event_key text,
    organization_id uuid,
    link text
);


--
-- Name: occurrence_counters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.occurrence_counters (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    type public.occurrence_type NOT NULL,
    year integer NOT NULL,
    last_value integer DEFAULT 0 NOT NULL
);


--
-- Name: organization_memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.organization_memberships (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    user_id uuid NOT NULL,
    role text DEFAULT 'member'::text NOT NULL,
    department text,
    job_title text,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: organizations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.organizations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    slug text,
    description text,
    tax_id text,
    website text,
    email text,
    phone text,
    address text,
    city text,
    country text DEFAULT 'PT'::text,
    logo_url text,
    primary_color text DEFAULT '#7367f0'::text,
    secondary_color text DEFAULT '#00cfe8'::text,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: platform_admin_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.platform_admin_history (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    entity_type text NOT NULL,
    entity_id uuid NOT NULL,
    action text NOT NULL,
    before_data jsonb,
    after_data jsonb,
    actor_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: ppt_layouts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ppt_layouts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    template_id uuid NOT NULL,
    name text NOT NULL,
    slide_type text NOT NULL,
    layout_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    order_index integer DEFAULT 0 NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: ppt_templates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ppt_templates (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    name text NOT NULL,
    description text,
    file_path text,
    thumbnail_url text,
    is_default boolean DEFAULT false NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    include_cover boolean DEFAULT true NOT NULL,
    sections text[] DEFAULT ARRAY['meeting'::text, 'swot'::text, 'tows'::text, 'risks'::text, 'objectives'::text, 'actions'::text, 'kpis'::text, 'decisions'::text] NOT NULL,
    body_font_size integer DEFAULT 18 NOT NULL,
    lines_per_slide integer DEFAULT 10 NOT NULL
);


--
-- Name: profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.profiles (
    id uuid NOT NULL,
    full_name text,
    email text,
    avatar_url text,
    role public.profile_role DEFAULT 'management'::public.profile_role NOT NULL,
    department text,
    job_title text,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    is_super_admin boolean DEFAULT false NOT NULL,
    organization_id uuid,
    module_access jsonb DEFAULT '{"quality": true, "strategy": true, "lifecycle": true}'::jsonb NOT NULL,
    session_version integer DEFAULT 0 NOT NULL,
    account_used boolean DEFAULT false NOT NULL,
    assignments_configured boolean DEFAULT false NOT NULL,
    CONSTRAINT profiles_modules_valid CHECK (((jsonb_typeof(module_access) = 'object'::text) AND (module_access ?& ARRAY['quality'::text, 'strategy'::text, 'lifecycle'::text]) AND (jsonb_typeof((module_access -> 'quality'::text)) = 'boolean'::text) AND (jsonb_typeof((module_access -> 'strategy'::text)) = 'boolean'::text) AND (jsonb_typeof((module_access -> 'lifecycle'::text)) = 'boolean'::text)))
);


--
-- Name: projects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.projects (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    objective_id uuid,
    code text NOT NULL,
    name text NOT NULL,
    description text,
    status public.project_status DEFAULT 'draft'::public.project_status NOT NULL,
    priority text,
    responsible_id uuid,
    start_date date,
    due_date date,
    completed_at timestamp with time zone,
    budget numeric(12,2),
    actual_cost numeric(12,2),
    progress numeric(5,2) DEFAULT 0 NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: quality_action_dependencies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quality_action_dependencies (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    action_id uuid NOT NULL,
    depends_on_id uuid NOT NULL,
    tipo text DEFAULT 'bloqueante'::text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    organization_id uuid DEFAULT public.current_company_context() NOT NULL
);


--
-- Name: quality_actions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quality_actions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    reference text NOT NULL,
    occurrence_id uuid,
    description text NOT NULL,
    responsible_user_id uuid,
    deadline date,
    status public.action_status DEFAULT 'TODO'::public.action_status NOT NULL,
    completed_at timestamp with time zone,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    plano_id uuid,
    titulo text,
    tipo public.action_type,
    resultado_esperado text,
    resultado_real text,
    prioridade text,
    criticidade text,
    colaboradores jsonb,
    data_inicio date,
    horas_previstas numeric(8,2),
    horas_realizadas numeric(8,2) DEFAULT 0 NOT NULL,
    percent_execucao numeric(5,2) DEFAULT 0 NOT NULL,
    progresso_origem text DEFAULT 'manual'::text,
    checklist jsonb,
    evidencias_obrigatorias boolean DEFAULT false,
    requer_aprovacao boolean DEFAULT false,
    aprovado_por uuid,
    aprovado_em timestamp with time zone,
    verificar_eficacia boolean DEFAULT false,
    eficacia_validada boolean DEFAULT false,
    eficacia_validada_por uuid,
    eficacia_validada_em timestamp with time zone,
    origem text DEFAULT 'manual'::text,
    proposta_por_ia boolean DEFAULT false,
    bloqueio_motivo text,
    cancelled_at timestamp with time zone,
    cancelled_by uuid,
    next_step text,
    organization_id uuid DEFAULT public.current_company_context() NOT NULL,
    action_kind text,
    original_deadline date,
    assigned_at timestamp with time zone,
    acknowledged_by uuid,
    acknowledged_at timestamp with time zone,
    completion_criterion text,
    effectiveness_criterion text,
    effectiveness_due date,
    mandatory boolean DEFAULT true NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    cancellation_reason text,
    CONSTRAINT quality_actions_action_kind_check CHECK ((action_kind = ANY (ARRAY['CORRECTION'::text, 'CORRECTIVE'::text, 'IMPROVEMENT'::text, 'RISK'::text, 'OPPORTUNITY'::text])))
);


--
-- Name: quality_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quality_occurrences (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    reference text NOT NULL,
    type public.occurrence_type NOT NULL,
    year integer NOT NULL,
    origin_id uuid NOT NULL,
    occurrence_date date DEFAULT CURRENT_DATE NOT NULL,
    area_id uuid NOT NULL,
    description text NOT NULL,
    responsible_user_id uuid,
    cause_analysis text,
    status public.occurrence_status DEFAULT 'OPEN'::public.occurrence_status NOT NULL,
    effectiveness_status text,
    effectiveness_notes text,
    effectiveness_evidence jsonb,
    effectiveness_validated_by uuid,
    effectiveness_validated_at timestamp with time zone,
    closed_at timestamp with time zone,
    reopened_at timestamp with time zone,
    reopened_by uuid,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    organization_id uuid DEFAULT public.current_company_context() NOT NULL,
    audit_id uuid,
    original_text text,
    internal_context text,
    external_reference text,
    classification text,
    standard text,
    clause text,
    site text,
    root_cause text,
    root_cause_confirmed_by uuid,
    root_cause_confirmed_at timestamp with time zone,
    corrective_required boolean,
    corrective_reason text,
    effectiveness_required boolean,
    effectiveness_criterion text,
    effectiveness_due date,
    approval_required boolean DEFAULT false NOT NULL,
    approver_id uuid,
    approval_status text DEFAULT 'DRAFT'::text NOT NULL,
    assigned_at timestamp with time zone,
    acknowledged_by uuid,
    acknowledged_at timestamp with time zone,
    cancelled_at timestamp with time zone,
    cancelled_by uuid,
    cancellation_reason text,
    cycle integer DEFAULT 1 NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    recurrent boolean DEFAULT false NOT NULL,
    related_occurrence_id uuid,
    reopen_reason text,
    external_status text DEFAULT 'Por responder'::text NOT NULL,
    standard_scope_id uuid,
    site_scope_id uuid,
    standard_id uuid
);


--
-- Name: quality_active_actions; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.quality_active_actions WITH (security_invoker='true') AS
 SELECT id,
    reference,
    occurrence_id,
    description,
    responsible_user_id,
    deadline,
    status,
    completed_at,
    created_by,
    created_at,
    updated_at,
    plano_id,
    titulo,
    tipo,
    resultado_esperado,
    resultado_real,
    prioridade,
    criticidade,
    colaboradores,
    data_inicio,
    horas_previstas,
    horas_realizadas,
    percent_execucao,
    progresso_origem,
    checklist,
    evidencias_obrigatorias,
    requer_aprovacao,
    aprovado_por,
    aprovado_em,
    verificar_eficacia,
    eficacia_validada,
    eficacia_validada_por,
    eficacia_validada_em,
    origem,
    proposta_por_ia,
    bloqueio_motivo,
    cancelled_at,
    cancelled_by,
    next_step,
    organization_id,
    action_kind,
    original_deadline,
    assigned_at,
    acknowledged_by,
    acknowledged_at,
    completion_criterion,
    effectiveness_criterion,
    effectiveness_due,
    mandatory,
    version,
    cancellation_reason
   FROM public.quality_actions a
  WHERE ((status <> 'CANCELLED'::public.action_status) AND (NOT (EXISTS ( SELECT 1
           FROM public.quality_occurrences o
          WHERE ((o.id = a.occurrence_id) AND (o.cancelled_at IS NOT NULL))))));


--
-- Name: quality_active_occurrences; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.quality_active_occurrences WITH (security_invoker='true') AS
 SELECT id,
    reference,
    type,
    year,
    origin_id,
    occurrence_date,
    area_id,
    description,
    responsible_user_id,
    cause_analysis,
    status,
    effectiveness_status,
    effectiveness_notes,
    effectiveness_evidence,
    effectiveness_validated_by,
    effectiveness_validated_at,
    closed_at,
    reopened_at,
    reopened_by,
    created_by,
    created_at,
    updated_at,
    organization_id,
    audit_id,
    original_text,
    internal_context,
    external_reference,
    classification,
    standard,
    clause,
    site,
    root_cause,
    root_cause_confirmed_by,
    root_cause_confirmed_at,
    corrective_required,
    corrective_reason,
    effectiveness_required,
    effectiveness_criterion,
    effectiveness_due,
    approval_required,
    approver_id,
    approval_status,
    assigned_at,
    acknowledged_by,
    acknowledged_at,
    cancelled_at,
    cancelled_by,
    cancellation_reason,
    cycle,
    version,
    recurrent,
    related_occurrence_id,
    reopen_reason,
    external_status
   FROM public.quality_occurrences
  WHERE (cancelled_at IS NULL);


--
-- Name: quality_approval_decisions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quality_approval_decisions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    occurrence_id uuid NOT NULL,
    cycle integer NOT NULL,
    decision text NOT NULL,
    comment text,
    actor_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT quality_approval_decisions_decision_check CHECK ((decision = ANY (ARRAY['SUBMITTED'::text, 'APPROVED'::text, 'RETURNED'::text, 'REJECTED'::text])))
);


--
-- Name: quality_areas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quality_areas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    description text,
    active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    organization_id uuid DEFAULT public.current_company_context() NOT NULL
);


--
-- Name: quality_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quality_attachments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    occurrence_id uuid,
    action_id uuid,
    file_name text NOT NULL,
    file_path text NOT NULL,
    file_type text,
    file_size bigint,
    description text,
    uploaded_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    plano_id uuid,
    organization_id uuid DEFAULT public.current_company_context() NOT NULL,
    audit_id uuid,
    review_id uuid,
    external_response_id uuid
);


--
-- Name: quality_audit_scope; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quality_audit_scope (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    audit_id uuid NOT NULL,
    kind text NOT NULL,
    area_id uuid,
    standard_id uuid,
    site text,
    CONSTRAINT quality_audit_scope_check CHECK ((((kind = 'area'::text) AND (area_id IS NOT NULL) AND (standard_id IS NULL) AND (site IS NULL)) OR ((kind = 'standard'::text) AND (standard_id IS NOT NULL) AND (area_id IS NULL) AND (site IS NULL)) OR ((kind = 'site'::text) AND (site IS NOT NULL) AND (btrim(site) <> ''::text) AND (area_id IS NULL) AND (standard_id IS NULL)))),
    CONSTRAINT quality_audit_scope_kind_check CHECK ((kind = ANY (ARRAY['area'::text, 'standard'::text, 'site'::text])))
);


--
-- Name: quality_auditors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quality_auditors (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    name text NOT NULL,
    kind text NOT NULL,
    entity text,
    contact text,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT quality_auditors_kind_check CHECK ((kind = ANY (ARRAY['INTERNAL'::text, 'EXTERNAL'::text]))),
    CONSTRAINT quality_auditors_name_check CHECK ((btrim(name) <> ''::text))
);


--
-- Name: quality_audits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quality_audits (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    reference text NOT NULL,
    kind text NOT NULL,
    title text NOT NULL,
    year integer NOT NULL,
    start_date date,
    end_date date,
    lead_auditor text,
    team text,
    standard text,
    scope text,
    areas text,
    sites text,
    auditor_entity text,
    external_kind text,
    accreditation text,
    certificate text,
    contract_reference text,
    representative text,
    headcount integer,
    conclusions text,
    recommendation text,
    status text DEFAULT 'OPEN'::text NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    lead_auditor_id uuid,
    auditor_id uuid,
    CONSTRAINT quality_audits_check CHECK (((end_date IS NULL) OR (start_date IS NULL) OR (end_date >= start_date))),
    CONSTRAINT quality_audits_kind_check CHECK ((kind = ANY (ARRAY['INTERNAL'::text, 'EXTERNAL'::text])))
);


--
-- Name: quality_catalogs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quality_catalogs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    kind text NOT NULL,
    name text NOT NULL,
    active boolean DEFAULT true NOT NULL,
    is_system boolean DEFAULT false NOT NULL,
    CONSTRAINT quality_catalogs_kind_check CHECK ((kind = ANY (ARRAY['finding'::text, 'standard'::text, 'nc_classification'::text])))
);


--
-- Name: quality_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quality_categories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    description text,
    parent_id uuid,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    organization_id uuid DEFAULT public.current_company_context() NOT NULL
);


--
-- Name: quality_comments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quality_comments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    occurrence_id uuid,
    action_id uuid,
    comment text NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    plano_id uuid,
    origem text DEFAULT 'manual'::text,
    organization_id uuid DEFAULT public.current_company_context() NOT NULL,
    CONSTRAINT quality_comment_parent_required CHECK (((occurrence_id IS NOT NULL) OR (action_id IS NOT NULL)))
);


--
-- Name: quality_compliance_plan_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quality_compliance_plan_links (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    plan_id uuid NOT NULL,
    related_plan_id uuid NOT NULL,
    relacao text DEFAULT 'complementar'::text,
    seu_id uuid,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    organization_id uuid DEFAULT public.current_company_context() NOT NULL
);


--
-- Name: quality_compliance_plans; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quality_compliance_plans (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    occurrence_id uuid NOT NULL,
    codigo text,
    versao integer DEFAULT 1 NOT NULL,
    titulo text,
    descricao text,
    status public.compliance_plan_status DEFAULT 'RASCUNHO'::public.compliance_plan_status NOT NULL,
    progresso numeric(5,2) DEFAULT 0 NOT NULL,
    progresso_origem text DEFAULT 'manual'::text,
    esforco_previsto_h numeric(8,2),
    esforco_real_h numeric(8,2),
    responsavel_id uuid,
    data_inicio date,
    data_prevista_fim date,
    data_conclusao timestamp with time zone,
    aprovado_por uuid,
    aprovado_em timestamp with time zone,
    requer_aprovacao boolean DEFAULT false NOT NULL,
    plan_principal boolean DEFAULT true NOT NULL,
    concluido_ai_validado boolean DEFAULT false NOT NULL,
    origem text DEFAULT 'manual'::text,
    sugerido_por_ia boolean DEFAULT false NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    aprovador_id uuid,
    aprovado_em_por timestamp with time zone,
    rejeitado_por uuid,
    rejeitado_em timestamp with time zone,
    motivo_rejeicao text,
    organization_id uuid DEFAULT public.current_company_context() NOT NULL
);


--
-- Name: COLUMN quality_compliance_plans.aprovador_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.quality_compliance_plans.aprovador_id IS 'Utilizador designado para aprovar o plano (quem deve aprovar).';


--
-- Name: COLUMN quality_compliance_plans.rejeitado_por; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.quality_compliance_plans.rejeitado_por IS 'Quem rejeitou o plano (decisão).';


--
-- Name: COLUMN quality_compliance_plans.motivo_rejeicao; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.quality_compliance_plans.motivo_rejeicao IS 'Justificação da rejeição pelo aprovador.';


--
-- Name: quality_deadline_changes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quality_deadline_changes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    action_id uuid NOT NULL,
    old_deadline date,
    new_deadline date NOT NULL,
    reason text NOT NULL,
    requested_by uuid NOT NULL,
    requested_at timestamp with time zone DEFAULT now() NOT NULL,
    status text NOT NULL,
    decided_by uuid,
    decided_at timestamp with time zone,
    decision_comment text,
    CONSTRAINT quality_deadline_changes_status_check CHECK ((status = ANY (ARRAY['PENDING'::text, 'APPROVED'::text, 'REJECTED'::text])))
);


--
-- Name: quality_effectiveness_reviews; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quality_effectiveness_reviews (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    occurrence_id uuid NOT NULL,
    cycle integer NOT NULL,
    result text NOT NULL,
    criterion text NOT NULL,
    evidence_ids uuid[] DEFAULT '{}'::uuid[] NOT NULL,
    conclusion text NOT NULL,
    evaluator_id uuid NOT NULL,
    evaluated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT quality_effectiveness_reviews_result_check CHECK ((result = ANY (ARRAY['EFFECTIVE'::text, 'NOT_EFFECTIVE'::text])))
);


--
-- Name: quality_external_responses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quality_external_responses (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    occurrence_id uuid NOT NULL,
    cause_sent text,
    correction text,
    corrective_action text,
    implementation_due date,
    evidence_ids uuid[] DEFAULT '{}'::uuid[] NOT NULL,
    sent_at timestamp with time zone,
    status text NOT NULL,
    auditor_original_text text,
    auditor_name text,
    responded_at timestamp with time zone,
    acceptance text,
    additional_requests text,
    future_verification text,
    created_by uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: quality_findings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quality_findings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    audit_id uuid NOT NULL,
    classification text NOT NULL,
    original_text text NOT NULL,
    internal_context text,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: quality_occurrence_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quality_occurrence_categories (
    occurrence_id uuid NOT NULL,
    category_id uuid NOT NULL,
    organization_id uuid DEFAULT public.current_company_context() NOT NULL
);


--
-- Name: quality_occurrence_relations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quality_occurrence_relations (
    id bigint NOT NULL,
    occurrence_id uuid NOT NULL,
    related_occurrence_id uuid NOT NULL,
    relation_type text DEFAULT 'related'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    organization_id uuid DEFAULT public.current_company_context() NOT NULL
);


--
-- Name: TABLE quality_occurrence_relations; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.quality_occurrence_relations IS 'Relação entre ocorrências de qualidade (ex.: NC relacionada/recorrência).';


--
-- Name: quality_occurrence_relations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.quality_occurrence_relations ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.quality_occurrence_relations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: quality_occurrence_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quality_occurrence_tags (
    occurrence_id uuid NOT NULL,
    tag_id uuid NOT NULL,
    organization_id uuid DEFAULT public.current_company_context() NOT NULL
);


--
-- Name: quality_origins; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quality_origins (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    description text,
    active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    organization_id uuid DEFAULT public.current_company_context() NOT NULL
);


--
-- Name: quality_outbox; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quality_outbox (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    event_key text NOT NULL,
    entity_type text NOT NULL,
    entity_id uuid NOT NULL,
    recipient_id uuid NOT NULL,
    channel text DEFAULT 'email'::text NOT NULL,
    template text NOT NULL,
    subject text NOT NULL,
    message text NOT NULL,
    link text NOT NULL,
    status text DEFAULT 'PENDING'::text NOT NULL,
    attempts integer DEFAULT 0 NOT NULL,
    next_attempt_at timestamp with time zone DEFAULT now() NOT NULL,
    sent_at timestamp with time zone,
    last_error text,
    locked_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT quality_outbox_status_check CHECK ((status = ANY (ARRAY['PENDING'::text, 'SENDING'::text, 'SENT'::text, 'FAILED'::text])))
);


--
-- Name: quality_plan_approval_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quality_plan_approval_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    plan_id uuid NOT NULL,
    acao text NOT NULL,
    decidido_por uuid,
    decidido_em timestamp with time zone DEFAULT now() NOT NULL,
    motivo text,
    papel text,
    plan_status text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    organization_id uuid DEFAULT public.current_company_context() NOT NULL,
    CONSTRAINT quality_plan_approval_events_acao_check CHECK ((acao = ANY (ARRAY['APROVADO'::text, 'REJEITADO'::text, 'DESAPROVADO'::text, 'MARCADO_MANUAL'::text])))
);


--
-- Name: quality_progress_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quality_progress_history (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    entity_type text NOT NULL,
    entity_id uuid NOT NULL,
    percent_antes numeric(5,2),
    percent_depois numeric(5,2),
    origem text DEFAULT 'manual'::text,
    changed_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    organization_id uuid DEFAULT public.current_company_context() NOT NULL
);


--
-- Name: quality_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quality_settings (
    organization_id uuid NOT NULL,
    deadline_approval boolean DEFAULT false NOT NULL,
    reminder_days integer[] DEFAULT '{7,3,1}'::integer[] NOT NULL,
    retry_minutes integer[] DEFAULT '{5,30,120}'::integer[] NOT NULL,
    finding_classifications text[] DEFAULT '{Observação}'::text[] NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    overdue_reminder_days integer[] DEFAULT '{1,3}'::integer[] NOT NULL,
    quality_escalation_days integer DEFAULT 5 NOT NULL,
    leader_escalation_days integer DEFAULT 10 NOT NULL,
    escalation_leader_id uuid,
    CONSTRAINT quality_settings_leader_escalation_days_check CHECK ((leader_escalation_days > 0)),
    CONSTRAINT quality_settings_quality_escalation_days_check CHECK ((quality_escalation_days > 0))
);


--
-- Name: quality_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quality_tags (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    organization_id uuid DEFAULT public.current_company_context() NOT NULL
);


--
-- Name: quality_work_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quality_work_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    action_id uuid NOT NULL,
    logged_by uuid NOT NULL,
    work_date timestamp with time zone DEFAULT now() NOT NULL,
    descricao text,
    horas numeric(6,2) DEFAULT 0 NOT NULL,
    minutos integer DEFAULT 0 NOT NULL,
    percent_antes numeric(5,2),
    percent_depois numeric(5,2),
    bloqueio text,
    next_step text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    organization_id uuid DEFAULT public.current_company_context() NOT NULL
);


--
-- Name: risk_opportunities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.risk_opportunities (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    cycle_id uuid,
    reference text,
    type public.risk_opportunity_type NOT NULL,
    title text NOT NULL,
    description text,
    probability integer,
    impact integer,
    score integer GENERATED ALWAYS AS ((probability * impact)) STORED,
    status public.risk_opportunity_status DEFAULT 'identified'::public.risk_opportunity_status NOT NULL,
    mitigation text,
    responsible_id uuid,
    due_date date,
    closed_at timestamp with time zone,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    source_tows_id uuid,
    CONSTRAINT risk_opportunities_impact_check CHECK (((impact >= 1) AND (impact <= 5))),
    CONSTRAINT risk_opportunities_probability_check CHECK (((probability >= 1) AND (probability <= 5)))
);


--
-- Name: roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.roles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    name text NOT NULL,
    description text,
    permissions jsonb DEFAULT '[]'::jsonb,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: seq_action_ref; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.seq_action_ref
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: strategic_actions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.strategic_actions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    objective_id uuid NOT NULL,
    name text NOT NULL,
    description text,
    status public.strategic_action_status DEFAULT 'todo'::public.strategic_action_status NOT NULL,
    priority text,
    responsible_id uuid,
    start_date date,
    due_date date,
    completed_at timestamp with time zone,
    progress numeric(5,2) DEFAULT 0 NOT NULL,
    budget numeric(12,2),
    actual_cost numeric(12,2),
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: strategic_objectives; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.strategic_objectives (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    cycle_id uuid,
    parent_id uuid,
    code text NOT NULL,
    name text NOT NULL,
    description text,
    perspective text,
    weight numeric(5,2) DEFAULT 1,
    status public.strategic_objective_status DEFAULT 'draft'::public.strategic_objective_status NOT NULL,
    progress numeric(5,2) DEFAULT 0 NOT NULL,
    responsible_id uuid,
    start_date date,
    due_date date,
    achieved_at timestamp with time zone,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    risk_ids uuid[] DEFAULT '{}'::uuid[] NOT NULL
);


--
-- Name: strategy_area_teams; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.strategy_area_teams (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    area_id uuid NOT NULL,
    team_id uuid NOT NULL
);


--
-- Name: strategy_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.strategy_history (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    table_name text NOT NULL,
    record_id uuid NOT NULL,
    operation text NOT NULL,
    before_data jsonb,
    after_data jsonb,
    reviewed_by uuid NOT NULL,
    reviewed_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL
);


--
-- Name: strategy_thematic_areas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.strategy_thematic_areas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    name text NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT strategy_thematic_areas_name_check CHECK ((length(TRIM(BOTH FROM name)) > 0))
);


--
-- Name: submissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.submissions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    meeting_id uuid NOT NULL,
    objective_id uuid,
    kpi_id uuid,
    action_id uuid,
    project_id uuid,
    title text NOT NULL,
    content text,
    status public.submission_status DEFAULT 'draft'::public.submission_status NOT NULL,
    submitted_by uuid,
    submitted_at timestamp with time zone,
    reviewed_by uuid,
    reviewed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: swot_campaign_audience; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.swot_campaign_audience (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    campaign_id uuid NOT NULL,
    user_id uuid,
    team_id uuid,
    CONSTRAINT swot_campaign_audience_check CHECK (((((user_id IS NOT NULL))::integer + ((team_id IS NOT NULL))::integer) = 1))
);


--
-- Name: swot_campaign_validators; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.swot_campaign_validators (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    campaign_id uuid NOT NULL,
    user_id uuid NOT NULL,
    team_id uuid
);


--
-- Name: swot_campaigns; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.swot_campaigns (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    cycle_id uuid,
    name text NOT NULL,
    description text,
    status text DEFAULT 'draft'::text NOT NULL,
    starts_at timestamp with time zone,
    ends_at timestamp with time zone,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    is_demo boolean DEFAULT false NOT NULL,
    min_per_quadrant integer DEFAULT 0 NOT NULL,
    max_per_quadrant integer DEFAULT 20 NOT NULL,
    validation_rules text DEFAULT 'Consolidação e validação humana antes da SWOT oficial'::text NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    quota_mode text DEFAULT 'participant_context'::text NOT NULL,
    min_own integer DEFAULT 3 NOT NULL,
    max_own integer DEFAULT 5 NOT NULL,
    min_other integer DEFAULT 3 NOT NULL,
    max_other integer DEFAULT 5 NOT NULL,
    collection_revision smallint DEFAULT 2 NOT NULL,
    CONSTRAINT swot_campaigns_check CHECK ((max_per_quadrant >= min_per_quadrant)),
    CONSTRAINT swot_campaigns_check1 CHECK (((ends_at IS NULL) OR (starts_at IS NULL) OR (ends_at >= starts_at))),
    CONSTRAINT swot_campaigns_check2 CHECK (((min_own >= 1) AND (max_own >= min_own) AND (max_own <= 1000) AND (min_other >= 1) AND (max_other >= min_other) AND (max_other <= 1000))),
    CONSTRAINT swot_campaigns_collection_revision_check CHECK ((collection_revision = ANY (ARRAY[1, 2]))),
    CONSTRAINT swot_campaigns_max_per_quadrant_check CHECK ((max_per_quadrant > 0)),
    CONSTRAINT swot_campaigns_min_per_quadrant_check CHECK ((min_per_quadrant >= 0)),
    CONSTRAINT swot_campaigns_quota_mode_check CHECK ((quota_mode = ANY (ARRAY['legacy'::text, 'participant_context'::text])))
);


--
-- Name: swot_context_reviews; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.swot_context_reviews (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    contribution_id uuid NOT NULL,
    decision text NOT NULL,
    reason text NOT NULL,
    reviewer_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT swot_context_reviews_decision_check CHECK ((decision = ANY (ARRAY['approved'::text, 'rejected'::text])))
);


--
-- Name: swot_contributions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.swot_contributions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    item_id uuid,
    user_id uuid NOT NULL,
    contribution text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    campaign_id uuid NOT NULL,
    organization_id uuid NOT NULL,
    quadrant public.swot_quadrant,
    team_id uuid,
    source text DEFAULT 'Aplicação'::text NOT NULL,
    author_label text,
    thematic_area_id uuid,
    contribution_scope text,
    imported_by uuid,
    import_batch_id uuid,
    CONSTRAINT swot_contributions_contribution_scope_check CHECK ((contribution_scope = ANY (ARRAY['own_team'::text, 'organization'::text, 'other_team'::text])))
);


--
-- Name: swot_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.swot_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    campaign_id uuid NOT NULL,
    quadrant public.swot_quadrant NOT NULL,
    title text NOT NULL,
    description text,
    impact text,
    probability text,
    order_index integer DEFAULT 0 NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    thematic_area_id uuid,
    contribution_scope text,
    team_id uuid,
    CONSTRAINT swot_items_contribution_scope_check CHECK ((contribution_scope = ANY (ARRAY['own_team'::text, 'organization'::text, 'other_team'::text])))
);


--
-- Name: swot_participant_contexts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.swot_participant_contexts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    campaign_id uuid NOT NULL,
    user_id uuid NOT NULL,
    team_id uuid,
    label text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: swot_proposals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.swot_proposals (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    campaign_id uuid NOT NULL,
    quadrant public.swot_quadrant NOT NULL,
    title text NOT NULL,
    contribution_ids uuid[] NOT NULL,
    status text DEFAULT 'proposed'::text NOT NULL,
    item_id uuid,
    created_by uuid,
    validated_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    validated_at timestamp with time zone,
    thematic_area_id uuid,
    CONSTRAINT swot_proposals_status_check CHECK ((status = ANY (ARRAY['proposed'::text, 'validated'::text])))
);


--
-- Name: swot_submissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.swot_submissions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    campaign_id uuid NOT NULL,
    user_id uuid NOT NULL,
    submitted_at timestamp with time zone DEFAULT now() NOT NULL,
    completion_type text DEFAULT 'completed'::text NOT NULL,
    authorized_by uuid,
    exception_reason text,
    CONSTRAINT swot_submissions_check CHECK (((completion_type <> 'exception'::text) OR ((authorized_by IS NOT NULL) AND (length(TRIM(BOTH FROM exception_reason)) > 0)))),
    CONSTRAINT swot_submissions_completion_type_check CHECK ((completion_type = ANY (ARRAY['completed'::text, 'exception'::text])))
);


--
-- Name: teams; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.teams (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    name text NOT NULL,
    description text,
    color text,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: tows_crossings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tows_crossings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    campaign_id uuid NOT NULL,
    strategy_type public.tows_strategy_type NOT NULL,
    name text NOT NULL,
    description text,
    priority text,
    s_item_id uuid,
    w_item_id uuid,
    o_item_id uuid,
    t_item_id uuid,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    disposition text DEFAULT 'monitor'::text NOT NULL,
    CONSTRAINT tows_crossings_disposition_check CHECK ((disposition = ANY (ARRAY['monitor'::text, 'not_relevant'::text, 'risk'::text, 'opportunity'::text])))
);


--
-- Name: user_access_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_access_history (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    before_data jsonb,
    after_data jsonb,
    password_changed boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL
);


--
-- Name: COLUMN user_access_history.user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.user_access_history.user_id IS 'Retained UUID after authorised removal of an unused account; actor remains a foreign key.';


--
-- Name: user_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_assignments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    user_id uuid NOT NULL,
    kind text NOT NULL,
    team_id uuid,
    function_name text,
    module text,
    role text,
    active boolean DEFAULT true NOT NULL,
    starts_on date,
    ends_on date,
    used_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT user_assignments_check CHECK (((ends_on IS NULL) OR (starts_on IS NULL) OR (ends_on >= starts_on))),
    CONSTRAINT user_assignments_check1 CHECK ((((kind = 'team'::text) AND (team_id IS NOT NULL) AND (NULLIF(btrim(function_name), ''::text) IS NOT NULL) AND (module IS NULL) AND (role IS NULL)) OR ((kind = 'permission'::text) AND (module IS NOT NULL) AND (role IS NOT NULL) AND (team_id IS NULL)))),
    CONSTRAINT user_assignments_kind_check CHECK ((kind = ANY (ARRAY['team'::text, 'permission'::text]))),
    CONSTRAINT user_assignments_module_check CHECK ((module = ANY (ARRAY['quality'::text, 'strategy'::text, 'lifecycle'::text]))),
    CONSTRAINT user_assignments_role_check CHECK ((role = ANY (ARRAY['quality'::text, 'management'::text, 'action_owner'::text])))
);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: ai_action_logs ai_action_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_action_logs
    ADD CONSTRAINT ai_action_logs_pkey PRIMARY KEY (id);


--
-- Name: ai_interactions ai_interactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_interactions
    ADD CONSTRAINT ai_interactions_pkey PRIMARY KEY (id);


--
-- Name: ai_pending_actions ai_pending_actions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_pending_actions
    ADD CONSTRAINT ai_pending_actions_pkey PRIMARY KEY (id);


--
-- Name: ai_query_logs ai_query_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_query_logs
    ADD CONSTRAINT ai_query_logs_pkey PRIMARY KEY (id);


--
-- Name: app_settings app_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_settings
    ADD CONSTRAINT app_settings_pkey PRIMARY KEY (key);


--
-- Name: app_versions app_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_versions
    ADD CONSTRAINT app_versions_pkey PRIMARY KEY (id);


--
-- Name: app_versions app_versions_platform_version_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_versions
    ADD CONSTRAINT app_versions_platform_version_key UNIQUE (platform, version);


--
-- Name: archive_locations archive_locations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.archive_locations
    ADD CONSTRAINT archive_locations_pkey PRIMARY KEY (id);


--
-- Name: audit_log audit_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY (id);


--
-- Name: auth_password_resets auth_password_resets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_password_resets
    ADD CONSTRAINT auth_password_resets_pkey PRIMARY KEY (id);


--
-- Name: auth_password_resets auth_password_resets_token_hash_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_password_resets
    ADD CONSTRAINT auth_password_resets_token_hash_key UNIQUE (token_hash);


--
-- Name: auth_recovery_attempts auth_recovery_attempts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_recovery_attempts
    ADD CONSTRAINT auth_recovery_attempts_pkey PRIMARY KEY (id);


--
-- Name: brand_assets brand_assets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brand_assets
    ADD CONSTRAINT brand_assets_pkey PRIMARY KEY (id);


--
-- Name: brand_kits brand_kits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brand_kits
    ADD CONSTRAINT brand_kits_pkey PRIMARY KEY (id);


--
-- Name: connector_instances connector_instances_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.connector_instances
    ADD CONSTRAINT connector_instances_pkey PRIMARY KEY (id);


--
-- Name: connectors connectors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.connectors
    ADD CONSTRAINT connectors_pkey PRIMARY KEY (id);


--
-- Name: cycles cycles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cycles
    ADD CONSTRAINT cycles_pkey PRIMARY KEY (id);


--
-- Name: data_reset_history data_reset_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_reset_history
    ADD CONSTRAINT data_reset_history_pkey PRIMARY KEY (id);


--
-- Name: decisions decisions_organization_id_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.decisions
    ADD CONSTRAINT decisions_organization_id_code_key UNIQUE (organization_id, code);


--
-- Name: decisions decisions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.decisions
    ADD CONSTRAINT decisions_pkey PRIMARY KEY (id);


--
-- Name: effectiveness_evaluations effectiveness_evaluations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.effectiveness_evaluations
    ADD CONSTRAINT effectiveness_evaluations_pkey PRIMARY KEY (id);


--
-- Name: evidences evidences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evidences
    ADD CONSTRAINT evidences_pkey PRIMARY KEY (id);


--
-- Name: external_ai_identities external_ai_identities_channel_external_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.external_ai_identities
    ADD CONSTRAINT external_ai_identities_channel_external_user_id_key UNIQUE (channel, external_user_id);


--
-- Name: external_ai_identities external_ai_identities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.external_ai_identities
    ADD CONSTRAINT external_ai_identities_pkey PRIMARY KEY (id);


--
-- Name: feature_flags feature_flags_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feature_flags
    ADD CONSTRAINT feature_flags_key_key UNIQUE (key);


--
-- Name: feature_flags feature_flags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feature_flags
    ADD CONSTRAINT feature_flags_pkey PRIMARY KEY (id);


--
-- Name: frameworks frameworks_organization_id_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.frameworks
    ADD CONSTRAINT frameworks_organization_id_code_key UNIQUE (organization_id, code);


--
-- Name: frameworks frameworks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.frameworks
    ADD CONSTRAINT frameworks_pkey PRIMARY KEY (id);


--
-- Name: generated_files generated_files_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.generated_files
    ADD CONSTRAINT generated_files_pkey PRIMARY KEY (id);


--
-- Name: import_registry import_registry_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.import_registry
    ADD CONSTRAINT import_registry_pkey PRIMARY KEY (id);


--
-- Name: import_registry import_registry_src_file_row_num_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.import_registry
    ADD CONSTRAINT import_registry_src_file_row_num_key UNIQUE (src_file, row_num);


--
-- Name: kpi_results kpi_results_kpi_id_period_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kpi_results
    ADD CONSTRAINT kpi_results_kpi_id_period_key UNIQUE (kpi_id, period);


--
-- Name: kpi_results kpi_results_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kpi_results
    ADD CONSTRAINT kpi_results_pkey PRIMARY KEY (id);


--
-- Name: kpi_targets kpi_targets_kpi_id_period_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kpi_targets
    ADD CONSTRAINT kpi_targets_kpi_id_period_key UNIQUE (kpi_id, period);


--
-- Name: kpi_targets kpi_targets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kpi_targets
    ADD CONSTRAINT kpi_targets_pkey PRIMARY KEY (id);


--
-- Name: kpis kpis_organization_id_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kpis
    ADD CONSTRAINT kpis_organization_id_code_key UNIQUE (organization_id, code);


--
-- Name: kpis kpis_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kpis
    ADD CONSTRAINT kpis_pkey PRIMARY KEY (id);


--
-- Name: lifecycle_avaliacoes lifecycle_avaliacoes_caso_id_vaga_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_avaliacoes
    ADD CONSTRAINT lifecycle_avaliacoes_caso_id_vaga_id_key UNIQUE (caso_id, vaga_id);


--
-- Name: lifecycle_avaliacoes lifecycle_avaliacoes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_avaliacoes
    ADD CONSTRAINT lifecycle_avaliacoes_pkey PRIMARY KEY (id);


--
-- Name: lifecycle_casos lifecycle_casos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_casos
    ADD CONSTRAINT lifecycle_casos_pkey PRIMARY KEY (id);


--
-- Name: lifecycle_casos lifecycle_casos_reference_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_casos
    ADD CONSTRAINT lifecycle_casos_reference_key UNIQUE (reference);


--
-- Name: lifecycle_certificacoes lifecycle_certificacoes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_certificacoes
    ADD CONSTRAINT lifecycle_certificacoes_pkey PRIMARY KEY (id);


--
-- Name: lifecycle_competencias lifecycle_competencias_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_competencias
    ADD CONSTRAINT lifecycle_competencias_pkey PRIMARY KEY (id);


--
-- Name: lifecycle_comunicacoes lifecycle_comunicacoes_caso_id_ref_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_comunicacoes
    ADD CONSTRAINT lifecycle_comunicacoes_caso_id_ref_key UNIQUE (caso_id, ref);


--
-- Name: lifecycle_comunicacoes lifecycle_comunicacoes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_comunicacoes
    ADD CONSTRAINT lifecycle_comunicacoes_pkey PRIMARY KEY (id);


--
-- Name: lifecycle_cv_jobs lifecycle_cv_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_cv_jobs
    ADD CONSTRAINT lifecycle_cv_jobs_pkey PRIMARY KEY (id);


--
-- Name: lifecycle_entrevistas lifecycle_entrevistas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_entrevistas
    ADD CONSTRAINT lifecycle_entrevistas_pkey PRIMARY KEY (id);


--
-- Name: lifecycle_experiencias lifecycle_experiencias_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_experiencias
    ADD CONSTRAINT lifecycle_experiencias_pkey PRIMARY KEY (id);


--
-- Name: lifecycle_formacoes lifecycle_formacoes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_formacoes
    ADD CONSTRAINT lifecycle_formacoes_pkey PRIMARY KEY (id);


--
-- Name: lifecycle_idiomas lifecycle_idiomas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_idiomas
    ADD CONSTRAINT lifecycle_idiomas_pkey PRIMARY KEY (id);


--
-- Name: lifecycle_pessoas lifecycle_pessoas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_pessoas
    ADD CONSTRAINT lifecycle_pessoas_pkey PRIMARY KEY (id);


--
-- Name: lifecycle_projetos lifecycle_projetos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_projetos
    ADD CONSTRAINT lifecycle_projetos_pkey PRIMARY KEY (id);


--
-- Name: lifecycle_referencias lifecycle_referencias_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_referencias
    ADD CONSTRAINT lifecycle_referencias_pkey PRIMARY KEY (id);


--
-- Name: lifecycle_tarefas lifecycle_tarefas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_tarefas
    ADD CONSTRAINT lifecycle_tarefas_pkey PRIMARY KEY (id);


--
-- Name: lifecycle_vagas lifecycle_vagas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_vagas
    ADD CONSTRAINT lifecycle_vagas_pkey PRIMARY KEY (id);


--
-- Name: lifecycle_vagas lifecycle_vagas_reference_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_vagas
    ADD CONSTRAINT lifecycle_vagas_reference_key UNIQUE (reference);


--
-- Name: meeting_presenters meeting_presenters_meeting_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meeting_presenters
    ADD CONSTRAINT meeting_presenters_meeting_id_user_id_key UNIQUE (meeting_id, user_id);


--
-- Name: meeting_presenters meeting_presenters_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meeting_presenters
    ADD CONSTRAINT meeting_presenters_pkey PRIMARY KEY (id);


--
-- Name: meetings meetings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meetings
    ADD CONSTRAINT meetings_pkey PRIMARY KEY (id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: occurrence_counters occurrence_counters_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.occurrence_counters
    ADD CONSTRAINT occurrence_counters_pkey PRIMARY KEY (id);


--
-- Name: occurrence_counters occurrence_counters_type_year_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.occurrence_counters
    ADD CONSTRAINT occurrence_counters_type_year_key UNIQUE (type, year);


--
-- Name: organization_memberships organization_memberships_organization_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organization_memberships
    ADD CONSTRAINT organization_memberships_organization_id_user_id_key UNIQUE (organization_id, user_id);


--
-- Name: organization_memberships organization_memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organization_memberships
    ADD CONSTRAINT organization_memberships_pkey PRIMARY KEY (id);


--
-- Name: organizations organizations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_pkey PRIMARY KEY (id);


--
-- Name: organizations organizations_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_slug_key UNIQUE (slug);


--
-- Name: platform_admin_history platform_admin_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.platform_admin_history
    ADD CONSTRAINT platform_admin_history_pkey PRIMARY KEY (id);


--
-- Name: ppt_layouts ppt_layouts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ppt_layouts
    ADD CONSTRAINT ppt_layouts_pkey PRIMARY KEY (id);


--
-- Name: ppt_templates ppt_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ppt_templates
    ADD CONSTRAINT ppt_templates_pkey PRIMARY KEY (id);


--
-- Name: profiles profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);


--
-- Name: projects projects_organization_id_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_organization_id_code_key UNIQUE (organization_id, code);


--
-- Name: projects projects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


--
-- Name: lifecycle_formacoes q58_range_data_conclusao; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.lifecycle_formacoes
    ADD CONSTRAINT q58_range_data_conclusao CHECK (((data_inicio IS NULL) OR (data_conclusao IS NULL) OR (data_conclusao >= data_inicio))) NOT VALID;


--
-- Name: lifecycle_experiencias q58_range_data_fim; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.lifecycle_experiencias
    ADD CONSTRAINT q58_range_data_fim CHECK (((data_inicio IS NULL) OR (data_fim IS NULL) OR (data_fim >= data_inicio))) NOT VALID;


--
-- Name: lifecycle_casos q58_range_data_saida; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.lifecycle_casos
    ADD CONSTRAINT q58_range_data_saida CHECK (((data_entrada IS NULL) OR (data_saida IS NULL) OR (data_saida >= data_entrada))) NOT VALID;


--
-- Name: projects q58_range_due_date; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.projects
    ADD CONSTRAINT q58_range_due_date CHECK (((start_date IS NULL) OR (due_date IS NULL) OR (due_date >= start_date))) NOT VALID;


--
-- Name: strategic_actions q58_range_due_date; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.strategic_actions
    ADD CONSTRAINT q58_range_due_date CHECK (((start_date IS NULL) OR (due_date IS NULL) OR (due_date >= start_date))) NOT VALID;


--
-- Name: strategic_objectives q58_range_due_date; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.strategic_objectives
    ADD CONSTRAINT q58_range_due_date CHECK (((start_date IS NULL) OR (due_date IS NULL) OR (due_date >= start_date))) NOT VALID;


--
-- Name: cycles q58_range_end_date; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.cycles
    ADD CONSTRAINT q58_range_end_date CHECK (((start_date IS NULL) OR (end_date IS NULL) OR (end_date >= start_date))) NOT VALID;


--
-- Name: quality_audits q58_range_end_date; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.quality_audits
    ADD CONSTRAINT q58_range_end_date CHECK (((start_date IS NULL) OR (end_date IS NULL) OR (end_date >= start_date))) NOT VALID;


--
-- Name: lifecycle_projetos q58_year_data; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.lifecycle_projetos
    ADD CONSTRAINT q58_year_data CHECK (((data IS NULL) OR ((data >= '0001-01-01'::date) AND (data <= '9999-12-31'::date)))) NOT VALID;


--
-- Name: lifecycle_formacoes q58_year_data_conclusao; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.lifecycle_formacoes
    ADD CONSTRAINT q58_year_data_conclusao CHECK (((data_conclusao IS NULL) OR ((data_conclusao >= '0001-01-01'::date) AND (data_conclusao <= '9999-12-31'::date)))) NOT VALID;


--
-- Name: lifecycle_vagas q58_year_data_desejada; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.lifecycle_vagas
    ADD CONSTRAINT q58_year_data_desejada CHECK (((data_desejada IS NULL) OR ((data_desejada >= '0001-01-01'::date) AND (data_desejada <= '9999-12-31'::date)))) NOT VALID;


--
-- Name: lifecycle_certificacoes q58_year_data_emissao; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.lifecycle_certificacoes
    ADD CONSTRAINT q58_year_data_emissao CHECK (((data_emissao IS NULL) OR ((data_emissao >= '0001-01-01'::date) AND (data_emissao <= '9999-12-31'::date)))) NOT VALID;


--
-- Name: lifecycle_casos q58_year_data_entrada; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.lifecycle_casos
    ADD CONSTRAINT q58_year_data_entrada CHECK (((data_entrada IS NULL) OR ((data_entrada >= '0001-01-01'::date) AND (data_entrada <= '9999-12-31'::date)))) NOT VALID;


--
-- Name: lifecycle_experiencias q58_year_data_fim; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.lifecycle_experiencias
    ADD CONSTRAINT q58_year_data_fim CHECK (((data_fim IS NULL) OR ((data_fim >= '0001-01-01'::date) AND (data_fim <= '9999-12-31'::date)))) NOT VALID;


--
-- Name: lifecycle_experiencias q58_year_data_inicio; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.lifecycle_experiencias
    ADD CONSTRAINT q58_year_data_inicio CHECK (((data_inicio IS NULL) OR ((data_inicio >= '0001-01-01'::date) AND (data_inicio <= '9999-12-31'::date)))) NOT VALID;


--
-- Name: lifecycle_formacoes q58_year_data_inicio; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.lifecycle_formacoes
    ADD CONSTRAINT q58_year_data_inicio CHECK (((data_inicio IS NULL) OR ((data_inicio >= '0001-01-01'::date) AND (data_inicio <= '9999-12-31'::date)))) NOT VALID;


--
-- Name: quality_actions q58_year_data_inicio; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.quality_actions
    ADD CONSTRAINT q58_year_data_inicio CHECK (((data_inicio IS NULL) OR ((data_inicio >= '0001-01-01'::date) AND (data_inicio <= '9999-12-31'::date)))) NOT VALID;


--
-- Name: quality_compliance_plans q58_year_data_inicio; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.quality_compliance_plans
    ADD CONSTRAINT q58_year_data_inicio CHECK (((data_inicio IS NULL) OR ((data_inicio >= '0001-01-01'::date) AND (data_inicio <= '9999-12-31'::date)))) NOT VALID;


--
-- Name: lifecycle_pessoas q58_year_data_nascimento; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.lifecycle_pessoas
    ADD CONSTRAINT q58_year_data_nascimento CHECK (((data_nascimento IS NULL) OR ((data_nascimento >= '0001-01-01'::date) AND (data_nascimento <= '9999-12-31'::date)))) NOT VALID;


--
-- Name: quality_compliance_plans q58_year_data_prevista_fim; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.quality_compliance_plans
    ADD CONSTRAINT q58_year_data_prevista_fim CHECK (((data_prevista_fim IS NULL) OR ((data_prevista_fim >= '0001-01-01'::date) AND (data_prevista_fim <= '9999-12-31'::date)))) NOT VALID;


--
-- Name: lifecycle_casos q58_year_data_saida; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.lifecycle_casos
    ADD CONSTRAINT q58_year_data_saida CHECK (((data_saida IS NULL) OR ((data_saida >= '0001-01-01'::date) AND (data_saida <= '9999-12-31'::date)))) NOT VALID;


--
-- Name: quality_actions q58_year_deadline; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.quality_actions
    ADD CONSTRAINT q58_year_deadline CHECK (((deadline IS NULL) OR ((deadline >= '0001-01-01'::date) AND (deadline <= '9999-12-31'::date)))) NOT VALID;


--
-- Name: lifecycle_tarefas q58_year_due_date; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.lifecycle_tarefas
    ADD CONSTRAINT q58_year_due_date CHECK (((due_date IS NULL) OR ((due_date >= '0001-01-01'::date) AND (due_date <= '9999-12-31'::date)))) NOT VALID;


--
-- Name: projects q58_year_due_date; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.projects
    ADD CONSTRAINT q58_year_due_date CHECK (((due_date IS NULL) OR ((due_date >= '0001-01-01'::date) AND (due_date <= '9999-12-31'::date)))) NOT VALID;


--
-- Name: risk_opportunities q58_year_due_date; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.risk_opportunities
    ADD CONSTRAINT q58_year_due_date CHECK (((due_date IS NULL) OR ((due_date >= '0001-01-01'::date) AND (due_date <= '9999-12-31'::date)))) NOT VALID;


--
-- Name: strategic_actions q58_year_due_date; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.strategic_actions
    ADD CONSTRAINT q58_year_due_date CHECK (((due_date IS NULL) OR ((due_date >= '0001-01-01'::date) AND (due_date <= '9999-12-31'::date)))) NOT VALID;


--
-- Name: strategic_objectives q58_year_due_date; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.strategic_objectives
    ADD CONSTRAINT q58_year_due_date CHECK (((due_date IS NULL) OR ((due_date >= '0001-01-01'::date) AND (due_date <= '9999-12-31'::date)))) NOT VALID;


--
-- Name: quality_actions q58_year_effectiveness_due; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.quality_actions
    ADD CONSTRAINT q58_year_effectiveness_due CHECK (((effectiveness_due IS NULL) OR ((effectiveness_due >= '0001-01-01'::date) AND (effectiveness_due <= '9999-12-31'::date)))) NOT VALID;


--
-- Name: quality_occurrences q58_year_effectiveness_due; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.quality_occurrences
    ADD CONSTRAINT q58_year_effectiveness_due CHECK (((effectiveness_due IS NULL) OR ((effectiveness_due >= '0001-01-01'::date) AND (effectiveness_due <= '9999-12-31'::date)))) NOT VALID;


--
-- Name: cycles q58_year_end_date; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.cycles
    ADD CONSTRAINT q58_year_end_date CHECK (((end_date IS NULL) OR ((end_date >= '0001-01-01'::date) AND (end_date <= '9999-12-31'::date)))) NOT VALID;


--
-- Name: quality_audits q58_year_end_date; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.quality_audits
    ADD CONSTRAINT q58_year_end_date CHECK (((end_date IS NULL) OR ((end_date >= '0001-01-01'::date) AND (end_date <= '9999-12-31'::date)))) NOT VALID;


--
-- Name: quality_external_responses q58_year_implementation_due; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.quality_external_responses
    ADD CONSTRAINT q58_year_implementation_due CHECK (((implementation_due IS NULL) OR ((implementation_due >= '0001-01-01'::date) AND (implementation_due <= '9999-12-31'::date)))) NOT VALID;


--
-- Name: quality_deadline_changes q58_year_new_deadline; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.quality_deadline_changes
    ADD CONSTRAINT q58_year_new_deadline CHECK (((new_deadline IS NULL) OR ((new_deadline >= '0001-01-01'::date) AND (new_deadline <= '9999-12-31'::date)))) NOT VALID;


--
-- Name: quality_occurrences q58_year_occurrence_date; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.quality_occurrences
    ADD CONSTRAINT q58_year_occurrence_date CHECK (((occurrence_date IS NULL) OR ((occurrence_date >= '0001-01-01'::date) AND (occurrence_date <= '9999-12-31'::date)))) NOT VALID;


--
-- Name: quality_deadline_changes q58_year_old_deadline; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.quality_deadline_changes
    ADD CONSTRAINT q58_year_old_deadline CHECK (((old_deadline IS NULL) OR ((old_deadline >= '0001-01-01'::date) AND (old_deadline <= '9999-12-31'::date)))) NOT VALID;


--
-- Name: quality_actions q58_year_original_deadline; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.quality_actions
    ADD CONSTRAINT q58_year_original_deadline CHECK (((original_deadline IS NULL) OR ((original_deadline >= '0001-01-01'::date) AND (original_deadline <= '9999-12-31'::date)))) NOT VALID;


--
-- Name: cycles q58_year_start_date; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.cycles
    ADD CONSTRAINT q58_year_start_date CHECK (((start_date IS NULL) OR ((start_date >= '0001-01-01'::date) AND (start_date <= '9999-12-31'::date)))) NOT VALID;


--
-- Name: projects q58_year_start_date; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.projects
    ADD CONSTRAINT q58_year_start_date CHECK (((start_date IS NULL) OR ((start_date >= '0001-01-01'::date) AND (start_date <= '9999-12-31'::date)))) NOT VALID;


--
-- Name: quality_audits q58_year_start_date; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.quality_audits
    ADD CONSTRAINT q58_year_start_date CHECK (((start_date IS NULL) OR ((start_date >= '0001-01-01'::date) AND (start_date <= '9999-12-31'::date)))) NOT VALID;


--
-- Name: strategic_actions q58_year_start_date; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.strategic_actions
    ADD CONSTRAINT q58_year_start_date CHECK (((start_date IS NULL) OR ((start_date >= '0001-01-01'::date) AND (start_date <= '9999-12-31'::date)))) NOT VALID;


--
-- Name: strategic_objectives q58_year_start_date; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.strategic_objectives
    ADD CONSTRAINT q58_year_start_date CHECK (((start_date IS NULL) OR ((start_date >= '0001-01-01'::date) AND (start_date <= '9999-12-31'::date)))) NOT VALID;


--
-- Name: lifecycle_competencias q58_year_ultima_utilizacao; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.lifecycle_competencias
    ADD CONSTRAINT q58_year_ultima_utilizacao CHECK (((ultima_utilizacao IS NULL) OR ((ultima_utilizacao >= '0001-01-01'::date) AND (ultima_utilizacao <= '9999-12-31'::date)))) NOT VALID;


--
-- Name: lifecycle_certificacoes q58_year_validade; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.lifecycle_certificacoes
    ADD CONSTRAINT q58_year_validade CHECK (((validade IS NULL) OR ((validade >= '0001-01-01'::date) AND (validade <= '9999-12-31'::date)))) NOT VALID;


--
-- Name: quality_action_dependencies quality_action_dependencies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_action_dependencies
    ADD CONSTRAINT quality_action_dependencies_pkey PRIMARY KEY (id);


--
-- Name: quality_actions quality_actions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_actions
    ADD CONSTRAINT quality_actions_pkey PRIMARY KEY (id);


--
-- Name: quality_actions quality_actions_reference_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_actions
    ADD CONSTRAINT quality_actions_reference_key UNIQUE (reference);


--
-- Name: quality_approval_decisions quality_approval_decisions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_approval_decisions
    ADD CONSTRAINT quality_approval_decisions_pkey PRIMARY KEY (id);


--
-- Name: quality_areas quality_areas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_areas
    ADD CONSTRAINT quality_areas_pkey PRIMARY KEY (id);


--
-- Name: quality_attachments quality_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_attachments
    ADD CONSTRAINT quality_attachments_pkey PRIMARY KEY (id);


--
-- Name: quality_audit_scope quality_audit_scope_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_audit_scope
    ADD CONSTRAINT quality_audit_scope_pkey PRIMARY KEY (id);


--
-- Name: quality_auditors quality_auditors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_auditors
    ADD CONSTRAINT quality_auditors_pkey PRIMARY KEY (id);


--
-- Name: quality_audits quality_audits_organization_id_reference_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_audits
    ADD CONSTRAINT quality_audits_organization_id_reference_key UNIQUE (organization_id, reference);


--
-- Name: quality_audits quality_audits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_audits
    ADD CONSTRAINT quality_audits_pkey PRIMARY KEY (id);


--
-- Name: quality_catalogs quality_catalogs_organization_id_kind_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_catalogs
    ADD CONSTRAINT quality_catalogs_organization_id_kind_name_key UNIQUE (organization_id, kind, name);


--
-- Name: quality_catalogs quality_catalogs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_catalogs
    ADD CONSTRAINT quality_catalogs_pkey PRIMARY KEY (id);


--
-- Name: quality_categories quality_categories_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_categories
    ADD CONSTRAINT quality_categories_name_key UNIQUE (name);


--
-- Name: quality_categories quality_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_categories
    ADD CONSTRAINT quality_categories_pkey PRIMARY KEY (id);


--
-- Name: quality_comments quality_comments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_comments
    ADD CONSTRAINT quality_comments_pkey PRIMARY KEY (id);


--
-- Name: quality_compliance_plan_links quality_compliance_plan_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_compliance_plan_links
    ADD CONSTRAINT quality_compliance_plan_links_pkey PRIMARY KEY (id);


--
-- Name: quality_compliance_plans quality_compliance_plans_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_compliance_plans
    ADD CONSTRAINT quality_compliance_plans_pkey PRIMARY KEY (id);


--
-- Name: quality_deadline_changes quality_deadline_changes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_deadline_changes
    ADD CONSTRAINT quality_deadline_changes_pkey PRIMARY KEY (id);


--
-- Name: quality_effectiveness_reviews quality_effectiveness_reviews_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_effectiveness_reviews
    ADD CONSTRAINT quality_effectiveness_reviews_pkey PRIMARY KEY (id);


--
-- Name: quality_external_responses quality_external_responses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_external_responses
    ADD CONSTRAINT quality_external_responses_pkey PRIMARY KEY (id);


--
-- Name: quality_findings quality_findings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_findings
    ADD CONSTRAINT quality_findings_pkey PRIMARY KEY (id);


--
-- Name: quality_occurrence_categories quality_occurrence_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_occurrence_categories
    ADD CONSTRAINT quality_occurrence_categories_pkey PRIMARY KEY (occurrence_id, category_id);


--
-- Name: quality_occurrence_relations quality_occurrence_relations_occurrence_id_related_occurren_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_occurrence_relations
    ADD CONSTRAINT quality_occurrence_relations_occurrence_id_related_occurren_key UNIQUE (occurrence_id, related_occurrence_id, relation_type);


--
-- Name: quality_occurrence_relations quality_occurrence_relations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_occurrence_relations
    ADD CONSTRAINT quality_occurrence_relations_pkey PRIMARY KEY (id);


--
-- Name: quality_occurrence_tags quality_occurrence_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_occurrence_tags
    ADD CONSTRAINT quality_occurrence_tags_pkey PRIMARY KEY (occurrence_id, tag_id);


--
-- Name: quality_occurrences quality_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_occurrences
    ADD CONSTRAINT quality_occurrences_pkey PRIMARY KEY (id);


--
-- Name: quality_occurrences quality_occurrences_reference_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_occurrences
    ADD CONSTRAINT quality_occurrences_reference_key UNIQUE (reference);


--
-- Name: quality_origins quality_origins_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_origins
    ADD CONSTRAINT quality_origins_pkey PRIMARY KEY (id);


--
-- Name: quality_outbox quality_outbox_event_key_recipient_id_channel_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_outbox
    ADD CONSTRAINT quality_outbox_event_key_recipient_id_channel_key UNIQUE (event_key, recipient_id, channel);


--
-- Name: quality_outbox quality_outbox_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_outbox
    ADD CONSTRAINT quality_outbox_pkey PRIMARY KEY (id);


--
-- Name: quality_plan_approval_events quality_plan_approval_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_plan_approval_events
    ADD CONSTRAINT quality_plan_approval_events_pkey PRIMARY KEY (id);


--
-- Name: quality_progress_history quality_progress_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_progress_history
    ADD CONSTRAINT quality_progress_history_pkey PRIMARY KEY (id);


--
-- Name: quality_settings quality_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_settings
    ADD CONSTRAINT quality_settings_pkey PRIMARY KEY (organization_id);


--
-- Name: quality_tags quality_tags_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_tags
    ADD CONSTRAINT quality_tags_name_key UNIQUE (name);


--
-- Name: quality_tags quality_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_tags
    ADD CONSTRAINT quality_tags_pkey PRIMARY KEY (id);


--
-- Name: quality_work_logs quality_work_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_work_logs
    ADD CONSTRAINT quality_work_logs_pkey PRIMARY KEY (id);


--
-- Name: risk_opportunities risk_opportunities_organization_id_reference_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.risk_opportunities
    ADD CONSTRAINT risk_opportunities_organization_id_reference_key UNIQUE (organization_id, reference);


--
-- Name: risk_opportunities risk_opportunities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.risk_opportunities
    ADD CONSTRAINT risk_opportunities_pkey PRIMARY KEY (id);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: strategic_actions strategic_actions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.strategic_actions
    ADD CONSTRAINT strategic_actions_pkey PRIMARY KEY (id);


--
-- Name: strategic_objectives strategic_objectives_organization_id_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.strategic_objectives
    ADD CONSTRAINT strategic_objectives_organization_id_code_key UNIQUE (organization_id, code);


--
-- Name: strategic_objectives strategic_objectives_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.strategic_objectives
    ADD CONSTRAINT strategic_objectives_pkey PRIMARY KEY (id);


--
-- Name: strategy_area_teams strategy_area_teams_area_id_team_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.strategy_area_teams
    ADD CONSTRAINT strategy_area_teams_area_id_team_id_key UNIQUE (area_id, team_id);


--
-- Name: strategy_area_teams strategy_area_teams_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.strategy_area_teams
    ADD CONSTRAINT strategy_area_teams_pkey PRIMARY KEY (id);


--
-- Name: strategy_history strategy_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.strategy_history
    ADD CONSTRAINT strategy_history_pkey PRIMARY KEY (id);


--
-- Name: strategy_thematic_areas strategy_thematic_areas_organization_id_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.strategy_thematic_areas
    ADD CONSTRAINT strategy_thematic_areas_organization_id_name_key UNIQUE (organization_id, name);


--
-- Name: strategy_thematic_areas strategy_thematic_areas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.strategy_thematic_areas
    ADD CONSTRAINT strategy_thematic_areas_pkey PRIMARY KEY (id);


--
-- Name: submissions submissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.submissions
    ADD CONSTRAINT submissions_pkey PRIMARY KEY (id);


--
-- Name: swot_campaign_audience swot_campaign_audience_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_campaign_audience
    ADD CONSTRAINT swot_campaign_audience_pkey PRIMARY KEY (id);


--
-- Name: swot_campaign_validators swot_campaign_validators_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_campaign_validators
    ADD CONSTRAINT swot_campaign_validators_pkey PRIMARY KEY (id);


--
-- Name: swot_campaigns swot_campaigns_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_campaigns
    ADD CONSTRAINT swot_campaigns_pkey PRIMARY KEY (id);


--
-- Name: swot_context_reviews swot_context_reviews_contribution_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_context_reviews
    ADD CONSTRAINT swot_context_reviews_contribution_id_key UNIQUE (contribution_id);


--
-- Name: swot_context_reviews swot_context_reviews_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_context_reviews
    ADD CONSTRAINT swot_context_reviews_pkey PRIMARY KEY (id);


--
-- Name: swot_contributions swot_contributions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_contributions
    ADD CONSTRAINT swot_contributions_pkey PRIMARY KEY (id);


--
-- Name: swot_items swot_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_items
    ADD CONSTRAINT swot_items_pkey PRIMARY KEY (id);


--
-- Name: swot_participant_contexts swot_participant_contexts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_participant_contexts
    ADD CONSTRAINT swot_participant_contexts_pkey PRIMARY KEY (id);


--
-- Name: swot_proposals swot_proposals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_proposals
    ADD CONSTRAINT swot_proposals_pkey PRIMARY KEY (id);


--
-- Name: swot_submissions swot_submissions_campaign_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_submissions
    ADD CONSTRAINT swot_submissions_campaign_id_user_id_key UNIQUE (campaign_id, user_id);


--
-- Name: swot_submissions swot_submissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_submissions
    ADD CONSTRAINT swot_submissions_pkey PRIMARY KEY (id);


--
-- Name: teams teams_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teams
    ADD CONSTRAINT teams_pkey PRIMARY KEY (id);


--
-- Name: tows_crossings tows_crossings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tows_crossings
    ADD CONSTRAINT tows_crossings_pkey PRIMARY KEY (id);


--
-- Name: user_access_history user_access_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_access_history
    ADD CONSTRAINT user_access_history_pkey PRIMARY KEY (id);


--
-- Name: user_assignments user_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_assignments
    ADD CONSTRAINT user_assignments_pkey PRIMARY KEY (id);


--
-- Name: auth_recovery_recent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX auth_recovery_recent ON public.auth_recovery_attempts USING btree (email_hash, created_at);


--
-- Name: idx_actions_deadline; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_actions_deadline ON public.quality_actions USING btree (deadline);


--
-- Name: idx_actions_occurrence; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_actions_occurrence ON public.quality_actions USING btree (occurrence_id);


--
-- Name: idx_actions_plano; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_actions_plano ON public.quality_actions USING btree (plano_id);


--
-- Name: idx_actions_responsible; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_actions_responsible ON public.quality_actions USING btree (responsible_user_id);


--
-- Name: idx_actions_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_actions_status ON public.quality_actions USING btree (status);


--
-- Name: idx_actions_tipo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_actions_tipo ON public.quality_actions USING btree (tipo);


--
-- Name: idx_ai_logs_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ai_logs_created ON public.ai_query_logs USING btree (created_at);


--
-- Name: idx_ai_logs_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ai_logs_user ON public.ai_query_logs USING btree (user_id);


--
-- Name: idx_attachments_action; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_attachments_action ON public.quality_attachments USING btree (action_id);


--
-- Name: idx_attachments_occurrence; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_attachments_occurrence ON public.quality_attachments USING btree (occurrence_id);


--
-- Name: idx_attachments_plano; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_attachments_plano ON public.quality_attachments USING btree (plano_id);


--
-- Name: idx_audit_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_created ON public.audit_log USING btree (created_at);


--
-- Name: idx_audit_entity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_entity ON public.audit_log USING btree (entity_type, entity_id);


--
-- Name: idx_brand_kits_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_brand_kits_org ON public.brand_kits USING btree (organization_id);


--
-- Name: idx_comments_plano; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_comments_plano ON public.quality_comments USING btree (plano_id);


--
-- Name: idx_connector_instances_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_connector_instances_org ON public.connector_instances USING btree (organization_id);


--
-- Name: idx_connectors_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_connectors_org ON public.connectors USING btree (organization_id);


--
-- Name: idx_cplans_occurrence; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cplans_occurrence ON public.quality_compliance_plans USING btree (occurrence_id);


--
-- Name: idx_cplans_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cplans_status ON public.quality_compliance_plans USING btree (status);


--
-- Name: idx_cycles_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cycles_org ON public.cycles USING btree (organization_id);


--
-- Name: idx_decisions_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_decisions_org ON public.decisions USING btree (organization_id);


--
-- Name: idx_effectiveness_evaluations_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_effectiveness_evaluations_org ON public.effectiveness_evaluations USING btree (organization_id);


--
-- Name: idx_evidences_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_evidences_org ON public.evidences USING btree (organization_id);


--
-- Name: idx_frameworks_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_frameworks_org ON public.frameworks USING btree (organization_id);


--
-- Name: idx_generated_files_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_generated_files_org ON public.generated_files USING btree (organization_id);


--
-- Name: idx_import_registry_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_import_registry_ref ON public.import_registry USING btree (reference);


--
-- Name: idx_import_registry_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_import_registry_status ON public.import_registry USING btree (status);


--
-- Name: idx_kpi_results_kpi; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_kpi_results_kpi ON public.kpi_results USING btree (kpi_id);


--
-- Name: idx_kpi_targets_kpi; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_kpi_targets_kpi ON public.kpi_targets USING btree (kpi_id);


--
-- Name: idx_kpis_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_kpis_org ON public.kpis USING btree (organization_id);


--
-- Name: idx_lcj_arquivado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lcj_arquivado ON public.lifecycle_cv_jobs USING btree (arquivado_at);


--
-- Name: idx_lcj_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lcj_created ON public.lifecycle_cv_jobs USING btree (created_at DESC);


--
-- Name: idx_lcj_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lcj_hash ON public.lifecycle_cv_jobs USING btree (file_hash);


--
-- Name: idx_lcj_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lcj_status ON public.lifecycle_cv_jobs USING btree (status);


--
-- Name: idx_lcj_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lcj_user ON public.lifecycle_cv_jobs USING btree (user_id);


--
-- Name: idx_lice_av_caso; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lice_av_caso ON public.lifecycle_avaliacoes USING btree (caso_id);


--
-- Name: idx_lice_av_pessoa; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lice_av_pessoa ON public.lifecycle_avaliacoes USING btree (pessoa_id);


--
-- Name: idx_lice_cert_pessoa; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lice_cert_pessoa ON public.lifecycle_certificacoes USING btree (pessoa_id);


--
-- Name: idx_lice_comp_pessoa; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lice_comp_pessoa ON public.lifecycle_competencias USING btree (pessoa_id);


--
-- Name: idx_lice_ent_caso; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lice_ent_caso ON public.lifecycle_entrevistas USING btree (caso_id);


--
-- Name: idx_lice_ent_data; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lice_ent_data ON public.lifecycle_entrevistas USING btree (data_hora);


--
-- Name: idx_lice_exp_pessoa; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lice_exp_pessoa ON public.lifecycle_experiencias USING btree (pessoa_id);


--
-- Name: idx_lice_form_pessoa; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lice_form_pessoa ON public.lifecycle_formacoes USING btree (pessoa_id);


--
-- Name: idx_lice_idio_pessoa; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lice_idio_pessoa ON public.lifecycle_idiomas USING btree (pessoa_id);


--
-- Name: idx_lice_pessoas_cv_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lice_pessoas_cv_hash ON public.lifecycle_pessoas USING btree (cv_hash);


--
-- Name: idx_lice_pessoas_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lice_pessoas_email ON public.lifecycle_pessoas USING btree (email);


--
-- Name: idx_lice_pessoas_nome; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lice_pessoas_nome ON public.lifecycle_pessoas USING btree (nome_completo);


--
-- Name: idx_lice_pessoas_telefone; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lice_pessoas_telefone ON public.lifecycle_pessoas USING btree (telefone);


--
-- Name: idx_lice_proj_pessoa; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lice_proj_pessoa ON public.lifecycle_projetos USING btree (pessoa_id);


--
-- Name: idx_lice_ref_pessoa; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lice_ref_pessoa ON public.lifecycle_referencias USING btree (pessoa_id);


--
-- Name: idx_lifecycle_casos_admissao; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lifecycle_casos_admissao ON public.lifecycle_casos USING btree (estado_admissao);


--
-- Name: idx_lifecycle_casos_dedup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lifecycle_casos_dedup ON public.lifecycle_casos USING btree (dedup_hash);


--
-- Name: idx_lifecycle_casos_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lifecycle_casos_email ON public.lifecycle_casos USING btree (email);


--
-- Name: idx_lifecycle_casos_estado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lifecycle_casos_estado ON public.lifecycle_casos USING btree (estado);


--
-- Name: idx_lifecycle_casos_off; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lifecycle_casos_off ON public.lifecycle_casos USING btree (estado_offboarding);


--
-- Name: idx_lifecycle_casos_pessoa; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lifecycle_casos_pessoa ON public.lifecycle_casos USING btree (pessoa_id);


--
-- Name: idx_lifecycle_casos_vaga; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lifecycle_casos_vaga ON public.lifecycle_casos USING btree (vaga_id);


--
-- Name: idx_lifecycle_comunicacoes_caso; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lifecycle_comunicacoes_caso ON public.lifecycle_comunicacoes USING btree (caso_id);


--
-- Name: idx_lifecycle_tarefas_caso; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lifecycle_tarefas_caso ON public.lifecycle_tarefas USING btree (caso_id);


--
-- Name: idx_lifecycle_tarefas_caso_gate; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lifecycle_tarefas_caso_gate ON public.lifecycle_tarefas USING btree (caso_id, gate);


--
-- Name: idx_lifecycle_tarefas_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lifecycle_tarefas_status ON public.lifecycle_tarefas USING btree (status);


--
-- Name: idx_meetings_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_meetings_org ON public.meetings USING btree (organization_id);


--
-- Name: idx_notifications_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notifications_user ON public.notifications USING btree (user_id, read);


--
-- Name: idx_occurrence_relations_occ; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_occurrence_relations_occ ON public.quality_occurrence_relations USING btree (occurrence_id);


--
-- Name: idx_occurrences_area; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_occurrences_area ON public.quality_occurrences USING btree (area_id);


--
-- Name: idx_occurrences_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_occurrences_created ON public.quality_occurrences USING btree (created_at);


--
-- Name: idx_occurrences_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_occurrences_date ON public.quality_occurrences USING btree (occurrence_date);


--
-- Name: idx_occurrences_origin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_occurrences_origin ON public.quality_occurrences USING btree (origin_id);


--
-- Name: idx_occurrences_responsible; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_occurrences_responsible ON public.quality_occurrences USING btree (responsible_user_id);


--
-- Name: idx_occurrences_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_occurrences_status ON public.quality_occurrences USING btree (status);


--
-- Name: idx_occurrences_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_occurrences_type ON public.quality_occurrences USING btree (type);


--
-- Name: idx_occurrences_year; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_occurrences_year ON public.quality_occurrences USING btree (year);


--
-- Name: idx_org_memberships_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_org_memberships_org ON public.organization_memberships USING btree (organization_id);


--
-- Name: idx_org_memberships_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_org_memberships_user ON public.organization_memberships USING btree (user_id);


--
-- Name: idx_pending_token; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pending_token ON public.ai_pending_actions USING btree (confirmation_token_hash);


--
-- Name: idx_pending_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pending_user ON public.ai_pending_actions USING btree (user_id, status);


--
-- Name: idx_plan_approval_events_plan; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_plan_approval_events_plan ON public.quality_plan_approval_events USING btree (plan_id);


--
-- Name: idx_proghist_entity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_proghist_entity ON public.quality_progress_history USING btree (entity_type, entity_id);


--
-- Name: idx_projects_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_projects_org ON public.projects USING btree (organization_id);


--
-- Name: idx_risk_opportunities_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_risk_opportunities_org ON public.risk_opportunities USING btree (organization_id);


--
-- Name: idx_roles_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_roles_org ON public.roles USING btree (organization_id);


--
-- Name: idx_strategic_actions_objective; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_strategic_actions_objective ON public.strategic_actions USING btree (objective_id);


--
-- Name: idx_strategic_objectives_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_strategic_objectives_org ON public.strategic_objectives USING btree (organization_id);


--
-- Name: idx_swot_campaigns_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_swot_campaigns_org ON public.swot_campaigns USING btree (organization_id);


--
-- Name: idx_swot_items_campaign; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_swot_items_campaign ON public.swot_items USING btree (campaign_id);


--
-- Name: idx_teams_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_teams_org ON public.teams USING btree (organization_id);


--
-- Name: idx_tows_crossings_campaign; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tows_crossings_campaign ON public.tows_crossings USING btree (campaign_id);


--
-- Name: idx_worklogs_action; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_worklogs_action ON public.quality_work_logs USING btree (action_id);


--
-- Name: idx_worklogs_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_worklogs_by ON public.quality_work_logs USING btree (logged_by);


--
-- Name: notifications_event_recipient; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX notifications_event_recipient ON public.notifications USING btree (event_key, user_id) WHERE (event_key IS NOT NULL);


--
-- Name: one_super_administrator; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX one_super_administrator ON public.profiles USING btree (is_super_admin) WHERE is_super_admin;


--
-- Name: quality_areas_company_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX quality_areas_company_name ON public.quality_areas USING btree (organization_id, name);


--
-- Name: quality_audits_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX quality_audits_org ON public.quality_audits USING btree (organization_id, year);


--
-- Name: quality_deadline_pending; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX quality_deadline_pending ON public.quality_deadline_changes USING btree (organization_id, status);


--
-- Name: quality_occurrences_audit; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX quality_occurrences_audit ON public.quality_occurrences USING btree (audit_id);


--
-- Name: quality_origins_company_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX quality_origins_company_name ON public.quality_origins USING btree (organization_id, name);


--
-- Name: quality_outbox_due; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX quality_outbox_due ON public.quality_outbox USING btree (next_attempt_at) WHERE (status = 'PENDING'::text);


--
-- Name: quality_reviews_occurrence; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX quality_reviews_occurrence ON public.quality_effectiveness_reviews USING btree (occurrence_id, cycle);


--
-- Name: quality_scope_area; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX quality_scope_area ON public.quality_audit_scope USING btree (audit_id, area_id) WHERE (kind = 'area'::text);


--
-- Name: quality_scope_site; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX quality_scope_site ON public.quality_audit_scope USING btree (audit_id, site) WHERE (kind = 'site'::text);


--
-- Name: quality_scope_standard; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX quality_scope_standard ON public.quality_audit_scope USING btree (audit_id, standard_id) WHERE (kind = 'standard'::text);


--
-- Name: swot_participant_context_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX swot_participant_context_unique ON public.swot_participant_contexts USING btree (campaign_id, user_id, COALESCE(team_id, '00000000-0000-0000-0000-000000000000'::uuid));


--
-- Name: swot_validator_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX swot_validator_unique ON public.swot_campaign_validators USING btree (campaign_id, user_id, COALESCE(team_id, '00000000-0000-0000-0000-000000000000'::uuid));


--
-- Name: uq_action_dep; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_action_dep ON public.quality_action_dependencies USING btree (action_id, depends_on_id);


--
-- Name: uq_cplan_links; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_cplan_links ON public.quality_compliance_plan_links USING btree (plan_id, related_plan_id, relacao);


--
-- Name: users on_auth_user_created; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


--
-- Name: users protect_super_auth; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER protect_super_auth BEFORE DELETE OR UPDATE ON auth.users FOR EACH ROW EXECUTE FUNCTION public.protect_super_auth();


--
-- Name: lifecycle_avaliacoes aa_company_links; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER aa_company_links BEFORE INSERT OR UPDATE ON public.lifecycle_avaliacoes FOR EACH ROW EXECUTE FUNCTION public.enforce_company_links();


--
-- Name: lifecycle_casos aa_company_links; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER aa_company_links BEFORE INSERT OR UPDATE ON public.lifecycle_casos FOR EACH ROW EXECUTE FUNCTION public.enforce_company_links();


--
-- Name: lifecycle_certificacoes aa_company_links; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER aa_company_links BEFORE INSERT OR UPDATE ON public.lifecycle_certificacoes FOR EACH ROW EXECUTE FUNCTION public.enforce_company_links();


--
-- Name: lifecycle_competencias aa_company_links; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER aa_company_links BEFORE INSERT OR UPDATE ON public.lifecycle_competencias FOR EACH ROW EXECUTE FUNCTION public.enforce_company_links();


--
-- Name: lifecycle_comunicacoes aa_company_links; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER aa_company_links BEFORE INSERT OR UPDATE ON public.lifecycle_comunicacoes FOR EACH ROW EXECUTE FUNCTION public.enforce_company_links();


--
-- Name: lifecycle_cv_jobs aa_company_links; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER aa_company_links BEFORE INSERT OR UPDATE ON public.lifecycle_cv_jobs FOR EACH ROW EXECUTE FUNCTION public.enforce_company_links();


--
-- Name: lifecycle_entrevistas aa_company_links; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER aa_company_links BEFORE INSERT OR UPDATE ON public.lifecycle_entrevistas FOR EACH ROW EXECUTE FUNCTION public.enforce_company_links();


--
-- Name: lifecycle_experiencias aa_company_links; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER aa_company_links BEFORE INSERT OR UPDATE ON public.lifecycle_experiencias FOR EACH ROW EXECUTE FUNCTION public.enforce_company_links();


--
-- Name: lifecycle_formacoes aa_company_links; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER aa_company_links BEFORE INSERT OR UPDATE ON public.lifecycle_formacoes FOR EACH ROW EXECUTE FUNCTION public.enforce_company_links();


--
-- Name: lifecycle_idiomas aa_company_links; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER aa_company_links BEFORE INSERT OR UPDATE ON public.lifecycle_idiomas FOR EACH ROW EXECUTE FUNCTION public.enforce_company_links();


--
-- Name: lifecycle_pessoas aa_company_links; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER aa_company_links BEFORE INSERT OR UPDATE ON public.lifecycle_pessoas FOR EACH ROW EXECUTE FUNCTION public.enforce_company_links();


--
-- Name: lifecycle_projetos aa_company_links; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER aa_company_links BEFORE INSERT OR UPDATE ON public.lifecycle_projetos FOR EACH ROW EXECUTE FUNCTION public.enforce_company_links();


--
-- Name: lifecycle_referencias aa_company_links; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER aa_company_links BEFORE INSERT OR UPDATE ON public.lifecycle_referencias FOR EACH ROW EXECUTE FUNCTION public.enforce_company_links();


--
-- Name: lifecycle_tarefas aa_company_links; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER aa_company_links BEFORE INSERT OR UPDATE ON public.lifecycle_tarefas FOR EACH ROW EXECUTE FUNCTION public.enforce_company_links();


--
-- Name: lifecycle_vagas aa_company_links; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER aa_company_links BEFORE INSERT OR UPDATE ON public.lifecycle_vagas FOR EACH ROW EXECUTE FUNCTION public.enforce_company_links();


--
-- Name: quality_action_dependencies aa_company_links; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER aa_company_links BEFORE INSERT OR UPDATE ON public.quality_action_dependencies FOR EACH ROW EXECUTE FUNCTION public.enforce_company_links();


--
-- Name: quality_actions aa_company_links; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER aa_company_links BEFORE INSERT OR UPDATE ON public.quality_actions FOR EACH ROW EXECUTE FUNCTION public.enforce_company_links();


--
-- Name: quality_areas aa_company_links; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER aa_company_links BEFORE INSERT OR UPDATE ON public.quality_areas FOR EACH ROW EXECUTE FUNCTION public.enforce_company_links();


--
-- Name: quality_attachments aa_company_links; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER aa_company_links BEFORE INSERT OR UPDATE ON public.quality_attachments FOR EACH ROW EXECUTE FUNCTION public.enforce_company_links();


--
-- Name: quality_categories aa_company_links; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER aa_company_links BEFORE INSERT OR UPDATE ON public.quality_categories FOR EACH ROW EXECUTE FUNCTION public.enforce_company_links();


--
-- Name: quality_comments aa_company_links; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER aa_company_links BEFORE INSERT OR UPDATE ON public.quality_comments FOR EACH ROW EXECUTE FUNCTION public.enforce_company_links();


--
-- Name: quality_compliance_plan_links aa_company_links; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER aa_company_links BEFORE INSERT OR UPDATE ON public.quality_compliance_plan_links FOR EACH ROW EXECUTE FUNCTION public.enforce_company_links();


--
-- Name: quality_compliance_plans aa_company_links; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER aa_company_links BEFORE INSERT OR UPDATE ON public.quality_compliance_plans FOR EACH ROW EXECUTE FUNCTION public.enforce_company_links();


--
-- Name: quality_occurrence_categories aa_company_links; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER aa_company_links BEFORE INSERT OR UPDATE ON public.quality_occurrence_categories FOR EACH ROW EXECUTE FUNCTION public.enforce_company_links();


--
-- Name: quality_occurrence_relations aa_company_links; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER aa_company_links BEFORE INSERT OR UPDATE ON public.quality_occurrence_relations FOR EACH ROW EXECUTE FUNCTION public.enforce_company_links();


--
-- Name: quality_occurrence_tags aa_company_links; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER aa_company_links BEFORE INSERT OR UPDATE ON public.quality_occurrence_tags FOR EACH ROW EXECUTE FUNCTION public.enforce_company_links();


--
-- Name: quality_occurrences aa_company_links; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER aa_company_links BEFORE INSERT OR UPDATE ON public.quality_occurrences FOR EACH ROW EXECUTE FUNCTION public.enforce_company_links();


--
-- Name: quality_origins aa_company_links; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER aa_company_links BEFORE INSERT OR UPDATE ON public.quality_origins FOR EACH ROW EXECUTE FUNCTION public.enforce_company_links();


--
-- Name: quality_plan_approval_events aa_company_links; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER aa_company_links BEFORE INSERT OR UPDATE ON public.quality_plan_approval_events FOR EACH ROW EXECUTE FUNCTION public.enforce_company_links();


--
-- Name: quality_progress_history aa_company_links; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER aa_company_links BEFORE INSERT OR UPDATE ON public.quality_progress_history FOR EACH ROW EXECUTE FUNCTION public.enforce_company_links();


--
-- Name: quality_tags aa_company_links; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER aa_company_links BEFORE INSERT OR UPDATE ON public.quality_tags FOR EACH ROW EXECUTE FUNCTION public.enforce_company_links();


--
-- Name: quality_work_logs aa_company_links; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER aa_company_links BEFORE INSERT OR UPDATE ON public.quality_work_logs FOR EACH ROW EXECUTE FUNCTION public.enforce_company_links();


--
-- Name: quality_actions actions_update_occurrence_status; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER actions_update_occurrence_status AFTER INSERT OR DELETE OR UPDATE ON public.quality_actions FOR EACH ROW EXECUTE FUNCTION public.update_occurrence_status_from_actions();


--
-- Name: platform_admin_history admin_history_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER admin_history_immutable BEFORE DELETE OR UPDATE ON public.platform_admin_history FOR EACH ROW EXECUTE FUNCTION public.quality_immutable();


--
-- Name: quality_areas area_no_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER area_no_delete BEFORE DELETE ON public.quality_areas FOR EACH ROW EXECUTE FUNCTION public.protect_used_config();


--
-- Name: user_assignments assignments_integrity; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER assignments_integrity BEFORE INSERT OR UPDATE ON public.user_assignments FOR EACH ROW EXECUTE FUNCTION public.assignments_integrity();


--
-- Name: quality_actions audit_actions; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_actions AFTER INSERT OR DELETE OR UPDATE ON public.quality_actions FOR EACH ROW EXECUTE FUNCTION public.log_audit();


--
-- Name: quality_occurrences audit_occurrences; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_occurrences AFTER INSERT OR DELETE OR UPDATE ON public.quality_occurrences FOR EACH ROW EXECUTE FUNCTION public.log_audit();


--
-- Name: quality_auditors auditor_no_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER auditor_no_delete BEFORE DELETE ON public.quality_auditors FOR EACH ROW EXECUTE FUNCTION public.protect_used_config();


--
-- Name: brand_assets brand_assets_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER brand_assets_immutable BEFORE DELETE OR UPDATE ON public.brand_assets FOR EACH ROW EXECUTE FUNCTION public.quality_immutable();


--
-- Name: swot_campaigns campaign_version; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER campaign_version BEFORE UPDATE ON public.swot_campaigns FOR EACH ROW EXECUTE FUNCTION public.quality_version();


--
-- Name: quality_catalogs catalog_no_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER catalog_no_delete BEFORE DELETE ON public.quality_catalogs FOR EACH ROW EXECUTE FUNCTION public.protect_used_config();


--
-- Name: quality_auditors delta_history; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER delta_history AFTER INSERT OR DELETE OR UPDATE ON public.quality_auditors FOR EACH ROW EXECUTE FUNCTION public.log_audit();


--
-- Name: user_assignments delta_history; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER delta_history AFTER INSERT OR DELETE OR UPDATE ON public.user_assignments FOR EACH ROW EXECUTE FUNCTION public.log_audit();


--
-- Name: swot_items delta_swot_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER delta_swot_guard BEFORE INSERT OR DELETE OR UPDATE ON public.swot_items FOR EACH ROW EXECUTE FUNCTION public.delta_swot_guard();


--
-- Name: swot_contributions delta_swot_original; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER delta_swot_original BEFORE DELETE OR UPDATE ON public.swot_contributions FOR EACH ROW EXECUTE FUNCTION public.delta_swot_guard();


--
-- Name: frameworks framework_structure_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER framework_structure_guard BEFORE DELETE OR UPDATE ON public.frameworks FOR EACH ROW EXECUTE FUNCTION public.strategy_structure_guard();


--
-- Name: quality_actions gen_action_reference; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER gen_action_reference BEFORE INSERT ON public.quality_actions FOR EACH ROW WHEN ((new.reference IS NULL)) EXECUTE FUNCTION public.next_action_reference();


--
-- Name: quality_occurrences gen_occurrence_reference; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER gen_occurrence_reference BEFORE INSERT ON public.quality_occurrences FOR EACH ROW WHEN ((new.reference IS NULL)) EXECUTE FUNCTION public.next_occurrence_reference();


--
-- Name: quality_occurrences guard_close_occurrence; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER guard_close_occurrence BEFORE UPDATE ON public.quality_occurrences FOR EACH ROW EXECUTE FUNCTION public.guard_close_occurrence();


--
-- Name: quality_actions guard_complete_action; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER guard_complete_action BEFORE UPDATE ON public.quality_actions FOR EACH ROW EXECUTE FUNCTION public.guard_complete_action();


--
-- Name: quality_occurrences guard_reopen_occurrence; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER guard_reopen_occurrence BEFORE UPDATE ON public.quality_occurrences FOR EACH ROW EXECUTE FUNCTION public.guard_reopen_occurrence();


--
-- Name: quality_origins origin_no_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER origin_no_delete BEFORE DELETE ON public.quality_origins FOR EACH ROW EXECUTE FUNCTION public.protect_used_config();


--
-- Name: swot_participant_contexts participant_context_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER participant_context_immutable BEFORE DELETE OR UPDATE ON public.swot_participant_contexts FOR EACH ROW EXECUTE FUNCTION public.quality_immutable();


--
-- Name: ppt_templates ppt_structure_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER ppt_structure_guard BEFORE DELETE OR UPDATE ON public.ppt_templates FOR EACH ROW EXECUTE FUNCTION public.strategy_structure_guard();


--
-- Name: user_assignments preserve_used_assignment; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER preserve_used_assignment BEFORE DELETE ON public.user_assignments FOR EACH ROW EXECUTE FUNCTION public.preserve_used_assignment();


--
-- Name: swot_campaigns protect_campaign_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER protect_campaign_delete BEFORE DELETE ON public.swot_campaigns FOR EACH ROW EXECUTE FUNCTION public.protect_campaign_delete();


--
-- Name: profiles protect_super_administrator; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER protect_super_administrator BEFORE INSERT OR DELETE OR UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.protect_super_administrator();


--
-- Name: quality_actions quality_actions_version; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER quality_actions_version BEFORE UPDATE ON public.quality_actions FOR EACH ROW EXECUTE FUNCTION public.quality_version();


--
-- Name: quality_audits quality_audits_version; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER quality_audits_version BEFORE UPDATE ON public.quality_audits FOR EACH ROW EXECUTE FUNCTION public.quality_version();


--
-- Name: quality_occurrences quality_occurrences_version; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER quality_occurrences_version BEFORE UPDATE ON public.quality_occurrences FOR EACH ROW EXECUTE FUNCTION public.quality_version();


--
-- Name: quality_occurrences quality_original_text; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER quality_original_text BEFORE UPDATE ON public.quality_occurrences FOR EACH ROW EXECUTE FUNCTION public.quality_original_text();


--
-- Name: quality_catalogs quality_protect_nc_classification; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER quality_protect_nc_classification BEFORE UPDATE ON public.quality_catalogs FOR EACH ROW EXECUTE FUNCTION public.quality_protect_nc_classification();


--
-- Name: organizations quality_seed_nc_classifications; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER quality_seed_nc_classifications AFTER INSERT ON public.organizations FOR EACH ROW EXECUTE FUNCTION public.quality_seed_nc_classifications();


--
-- Name: quality_audit_scope scope_history; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER scope_history AFTER INSERT OR DELETE OR UPDATE ON public.quality_audit_scope FOR EACH ROW EXECUTE FUNCTION public.log_audit();


--
-- Name: quality_audit_scope scope_integrity; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER scope_integrity BEFORE INSERT OR UPDATE ON public.quality_audit_scope FOR EACH ROW EXECUTE FUNCTION public.quality_scope_integrity();


--
-- Name: lifecycle_casos set_lifecycle_casos_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_lifecycle_casos_updated_at BEFORE UPDATE ON public.lifecycle_casos FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: lifecycle_vagas set_lifecycle_vagas_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_lifecycle_vagas_updated_at BEFORE UPDATE ON public.lifecycle_vagas FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: profiles set_profiles_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: quality_actions set_quality_actions_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_quality_actions_updated_at BEFORE UPDATE ON public.quality_actions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: quality_areas set_quality_areas_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_quality_areas_updated_at BEFORE UPDATE ON public.quality_areas FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: quality_comments set_quality_comments_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_quality_comments_updated_at BEFORE UPDATE ON public.quality_comments FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: quality_compliance_plans set_quality_cplans_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_quality_cplans_updated_at BEFORE UPDATE ON public.quality_compliance_plans FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: quality_occurrences set_quality_occurrences_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_quality_occurrences_updated_at BEFORE UPDATE ON public.quality_occurrences FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: quality_origins set_quality_origins_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_quality_origins_updated_at BEFORE UPDATE ON public.quality_origins FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: swot_contributions strategy_context_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER strategy_context_guard BEFORE INSERT ON public.swot_contributions FOR EACH ROW EXECUTE FUNCTION public.strategy_context_guard();


--
-- Name: organization_memberships strategy_membership_active_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER strategy_membership_active_guard BEFORE INSERT OR UPDATE ON public.organization_memberships FOR EACH ROW EXECUTE FUNCTION public.strategy_membership_active_guard();


--
-- Name: cycles strategy_structure_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER strategy_structure_guard BEFORE DELETE OR UPDATE ON public.cycles FOR EACH ROW EXECUTE FUNCTION public.strategy_structure_guard();


--
-- Name: teams strategy_structure_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER strategy_structure_guard BEFORE DELETE OR UPDATE ON public.teams FOR EACH ROW EXECUTE FUNCTION public.strategy_structure_guard();


--
-- Name: kpi_results strategy_validate; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER strategy_validate BEFORE INSERT OR UPDATE ON public.kpi_results FOR EACH ROW EXECUTE FUNCTION public.validate_strategy_record();


--
-- Name: kpi_targets strategy_validate; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER strategy_validate BEFORE INSERT OR UPDATE ON public.kpi_targets FOR EACH ROW EXECUTE FUNCTION public.validate_strategy_record();


--
-- Name: kpis strategy_validate; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER strategy_validate BEFORE INSERT OR UPDATE ON public.kpis FOR EACH ROW EXECUTE FUNCTION public.validate_strategy_record();


--
-- Name: risk_opportunities strategy_validate; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER strategy_validate BEFORE INSERT OR UPDATE ON public.risk_opportunities FOR EACH ROW EXECUTE FUNCTION public.validate_strategy_record();


--
-- Name: strategic_actions strategy_validate; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER strategy_validate BEFORE INSERT OR UPDATE ON public.strategic_actions FOR EACH ROW EXECUTE FUNCTION public.validate_strategy_record();


--
-- Name: strategic_objectives strategy_validate; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER strategy_validate BEFORE INSERT OR UPDATE ON public.strategic_objectives FOR EACH ROW EXECUTE FUNCTION public.validate_strategy_record();


--
-- Name: swot_items strategy_validate; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER strategy_validate BEFORE INSERT OR UPDATE ON public.swot_items FOR EACH ROW EXECUTE FUNCTION public.validate_strategy_record();


--
-- Name: tows_crossings strategy_validate; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER strategy_validate BEFORE INSERT OR UPDATE ON public.tows_crossings FOR EACH ROW EXECUTE FUNCTION public.validate_strategy_record();


--
-- Name: swot_context_reviews swot_context_review_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER swot_context_review_immutable BEFORE DELETE OR UPDATE ON public.swot_context_reviews FOR EACH ROW EXECUTE FUNCTION public.quality_immutable();


--
-- Name: swot_submissions swot_submission_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER swot_submission_immutable BEFORE DELETE OR UPDATE ON public.swot_submissions FOR EACH ROW EXECUTE FUNCTION public.quality_immutable();


--
-- Name: audit_log track_assignment_usage; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER track_assignment_usage AFTER INSERT ON public.audit_log FOR EACH ROW EXECUTE FUNCTION public.track_assignment_usage();


--
-- Name: platform_admin_history track_strategy_assignment_usage; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER track_strategy_assignment_usage AFTER INSERT ON public.platform_admin_history FOR EACH ROW EXECUTE FUNCTION public.track_strategy_assignment_usage();


--
-- Name: strategy_history track_strategy_assignment_usage; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER track_strategy_assignment_usage AFTER INSERT ON public.strategy_history FOR EACH ROW EXECUTE FUNCTION public.track_strategy_assignment_usage();


--
-- Name: app_versions trg_app_versions_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_app_versions_set_updated_at BEFORE UPDATE ON public.app_versions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: archive_locations trg_archive_locations_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_archive_locations_set_updated_at BEFORE UPDATE ON public.archive_locations FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: brand_kits trg_brand_kits_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_brand_kits_set_updated_at BEFORE UPDATE ON public.brand_kits FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: connector_instances trg_connector_instances_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_connector_instances_set_updated_at BEFORE UPDATE ON public.connector_instances FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: connectors trg_connectors_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_connectors_set_updated_at BEFORE UPDATE ON public.connectors FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: cycles trg_cycles_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_cycles_set_updated_at BEFORE UPDATE ON public.cycles FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: decisions trg_decisions_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_decisions_set_updated_at BEFORE UPDATE ON public.decisions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: effectiveness_evaluations trg_effectiveness_evaluations_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_effectiveness_evaluations_set_updated_at BEFORE UPDATE ON public.effectiveness_evaluations FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: evidences trg_evidences_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_evidences_set_updated_at BEFORE UPDATE ON public.evidences FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: feature_flags trg_feature_flags_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_feature_flags_set_updated_at BEFORE UPDATE ON public.feature_flags FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: frameworks trg_frameworks_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_frameworks_set_updated_at BEFORE UPDATE ON public.frameworks FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: generated_files trg_generated_files_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_generated_files_set_updated_at BEFORE UPDATE ON public.generated_files FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: kpi_results trg_kpi_results_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_kpi_results_set_updated_at BEFORE UPDATE ON public.kpi_results FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: kpi_targets trg_kpi_targets_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_kpi_targets_set_updated_at BEFORE UPDATE ON public.kpi_targets FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: kpis trg_kpis_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_kpis_set_updated_at BEFORE UPDATE ON public.kpis FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: lifecycle_cv_jobs trg_lcj_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_lcj_updated_at BEFORE UPDATE ON public.lifecycle_cv_jobs FOR EACH ROW EXECUTE FUNCTION public.set_lifecycle_pessoas_updated_at();


--
-- Name: lifecycle_avaliacoes trg_lice_av_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_lice_av_updated_at BEFORE UPDATE ON public.lifecycle_avaliacoes FOR EACH ROW EXECUTE FUNCTION public.set_lifecycle_pessoas_updated_at();


--
-- Name: lifecycle_entrevistas trg_lice_ent_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_lice_ent_updated_at BEFORE UPDATE ON public.lifecycle_entrevistas FOR EACH ROW EXECUTE FUNCTION public.set_lifecycle_pessoas_updated_at();


--
-- Name: lifecycle_pessoas trg_lifecycle_pessoas_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_lifecycle_pessoas_updated_at BEFORE UPDATE ON public.lifecycle_pessoas FOR EACH ROW EXECUTE FUNCTION public.set_lifecycle_pessoas_updated_at();


--
-- Name: meeting_presenters trg_meeting_presenters_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_meeting_presenters_set_updated_at BEFORE UPDATE ON public.meeting_presenters FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: meetings trg_meetings_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_meetings_set_updated_at BEFORE UPDATE ON public.meetings FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: organization_memberships trg_organization_memberships_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_organization_memberships_set_updated_at BEFORE UPDATE ON public.organization_memberships FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: organizations trg_organizations_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_organizations_set_updated_at BEFORE UPDATE ON public.organizations FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: ppt_layouts trg_ppt_layouts_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_ppt_layouts_set_updated_at BEFORE UPDATE ON public.ppt_layouts FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: ppt_templates trg_ppt_templates_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_ppt_templates_set_updated_at BEFORE UPDATE ON public.ppt_templates FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: projects trg_projects_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_projects_set_updated_at BEFORE UPDATE ON public.projects FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: risk_opportunities trg_risk_opportunities_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_risk_opportunities_set_updated_at BEFORE UPDATE ON public.risk_opportunities FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: roles trg_roles_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_roles_set_updated_at BEFORE UPDATE ON public.roles FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: strategic_actions trg_strategic_actions_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_strategic_actions_set_updated_at BEFORE UPDATE ON public.strategic_actions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: strategic_objectives trg_strategic_objectives_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_strategic_objectives_set_updated_at BEFORE UPDATE ON public.strategic_objectives FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: submissions trg_submissions_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_submissions_set_updated_at BEFORE UPDATE ON public.submissions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: swot_campaigns trg_swot_campaigns_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_swot_campaigns_set_updated_at BEFORE UPDATE ON public.swot_campaigns FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: swot_contributions trg_swot_contributions_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_swot_contributions_set_updated_at BEFORE UPDATE ON public.swot_contributions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: swot_items trg_swot_items_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_swot_items_set_updated_at BEFORE UPDATE ON public.swot_items FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: teams trg_teams_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_teams_set_updated_at BEFORE UPDATE ON public.teams FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: tows_crossings trg_tows_crossings_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_tows_crossings_set_updated_at BEFORE UPDATE ON public.tows_crossings FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: quality_approval_decisions v25_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER v25_audit AFTER INSERT OR UPDATE ON public.quality_approval_decisions FOR EACH ROW EXECUTE FUNCTION public.log_audit();


--
-- Name: quality_attachments v25_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER v25_audit AFTER INSERT OR UPDATE ON public.quality_attachments FOR EACH ROW EXECUTE FUNCTION public.log_audit();


--
-- Name: quality_audits v25_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER v25_audit AFTER INSERT OR UPDATE ON public.quality_audits FOR EACH ROW EXECUTE FUNCTION public.log_audit();


--
-- Name: quality_comments v25_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER v25_audit AFTER INSERT OR UPDATE ON public.quality_comments FOR EACH ROW EXECUTE FUNCTION public.log_audit();


--
-- Name: quality_deadline_changes v25_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER v25_audit AFTER INSERT OR UPDATE ON public.quality_deadline_changes FOR EACH ROW EXECUTE FUNCTION public.log_audit();


--
-- Name: quality_effectiveness_reviews v25_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER v25_audit AFTER INSERT OR UPDATE ON public.quality_effectiveness_reviews FOR EACH ROW EXECUTE FUNCTION public.log_audit();


--
-- Name: quality_external_responses v25_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER v25_audit AFTER INSERT OR UPDATE ON public.quality_external_responses FOR EACH ROW EXECUTE FUNCTION public.log_audit();


--
-- Name: quality_findings v25_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER v25_audit AFTER INSERT OR UPDATE ON public.quality_findings FOR EACH ROW EXECUTE FUNCTION public.log_audit();


--
-- Name: audit_log v25_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER v25_immutable BEFORE DELETE OR UPDATE ON public.audit_log FOR EACH ROW EXECUTE FUNCTION public.quality_immutable();


--
-- Name: quality_approval_decisions v25_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER v25_immutable BEFORE DELETE OR UPDATE ON public.quality_approval_decisions FOR EACH ROW EXECUTE FUNCTION public.quality_immutable();


--
-- Name: quality_attachments v25_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER v25_immutable BEFORE DELETE OR UPDATE ON public.quality_attachments FOR EACH ROW EXECUTE FUNCTION public.quality_immutable();


--
-- Name: quality_effectiveness_reviews v25_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER v25_immutable BEFORE DELETE OR UPDATE ON public.quality_effectiveness_reviews FOR EACH ROW EXECUTE FUNCTION public.quality_immutable();


--
-- Name: quality_external_responses v25_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER v25_immutable BEFORE DELETE OR UPDATE ON public.quality_external_responses FOR EACH ROW EXECUTE FUNCTION public.quality_immutable();


--
-- Name: quality_findings v25_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER v25_immutable BEFORE DELETE OR UPDATE ON public.quality_findings FOR EACH ROW EXECUTE FUNCTION public.quality_immutable();


--
-- Name: quality_plan_approval_events v25_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER v25_immutable BEFORE DELETE OR UPDATE ON public.quality_plan_approval_events FOR EACH ROW EXECUTE FUNCTION public.quality_immutable();


--
-- Name: quality_actions v25_no_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER v25_no_delete BEFORE DELETE ON public.quality_actions FOR EACH ROW EXECUTE FUNCTION public.quality_immutable();


--
-- Name: quality_audits v25_no_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER v25_no_delete BEFORE DELETE ON public.quality_audits FOR EACH ROW EXECUTE FUNCTION public.quality_immutable();


--
-- Name: quality_compliance_plans v25_no_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER v25_no_delete BEFORE DELETE ON public.quality_compliance_plans FOR EACH ROW EXECUTE FUNCTION public.quality_immutable();


--
-- Name: quality_occurrences v25_no_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER v25_no_delete BEFORE DELETE ON public.quality_occurrences FOR EACH ROW EXECUTE FUNCTION public.quality_immutable();


--
-- Name: brand_kits zz_platform_timestamp; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER zz_platform_timestamp BEFORE UPDATE ON public.brand_kits FOR EACH ROW EXECUTE FUNCTION public.platform_module_timestamp();


--
-- Name: connectors zz_platform_timestamp; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER zz_platform_timestamp BEFORE UPDATE ON public.connectors FOR EACH ROW EXECUTE FUNCTION public.platform_module_timestamp();


--
-- Name: cycles zz_platform_timestamp; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER zz_platform_timestamp BEFORE UPDATE ON public.cycles FOR EACH ROW EXECUTE FUNCTION public.platform_module_timestamp();


--
-- Name: decisions zz_platform_timestamp; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER zz_platform_timestamp BEFORE UPDATE ON public.decisions FOR EACH ROW EXECUTE FUNCTION public.platform_module_timestamp();


--
-- Name: frameworks zz_platform_timestamp; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER zz_platform_timestamp BEFORE UPDATE ON public.frameworks FOR EACH ROW EXECUTE FUNCTION public.platform_module_timestamp();


--
-- Name: meeting_presenters zz_platform_timestamp; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER zz_platform_timestamp BEFORE UPDATE ON public.meeting_presenters FOR EACH ROW EXECUTE FUNCTION public.platform_module_timestamp();


--
-- Name: meetings zz_platform_timestamp; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER zz_platform_timestamp BEFORE UPDATE ON public.meetings FOR EACH ROW EXECUTE FUNCTION public.platform_module_timestamp();


--
-- Name: organization_memberships zz_platform_timestamp; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER zz_platform_timestamp BEFORE UPDATE ON public.organization_memberships FOR EACH ROW EXECUTE FUNCTION public.platform_module_timestamp();


--
-- Name: organizations zz_platform_timestamp; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER zz_platform_timestamp BEFORE UPDATE ON public.organizations FOR EACH ROW EXECUTE FUNCTION public.platform_module_timestamp();


--
-- Name: ppt_templates zz_platform_timestamp; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER zz_platform_timestamp BEFORE UPDATE ON public.ppt_templates FOR EACH ROW EXECUTE FUNCTION public.platform_module_timestamp();


--
-- Name: teams zz_platform_timestamp; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER zz_platform_timestamp BEFORE UPDATE ON public.teams FOR EACH ROW EXECUTE FUNCTION public.platform_module_timestamp();


--
-- Name: ai_action_logs ai_action_logs_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_action_logs
    ADD CONSTRAINT ai_action_logs_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: ai_action_logs ai_action_logs_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_action_logs
    ADD CONSTRAINT ai_action_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: ai_interactions ai_interactions_occurrence_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_interactions
    ADD CONSTRAINT ai_interactions_occurrence_id_fkey FOREIGN KEY (occurrence_id) REFERENCES public.quality_occurrences(id) ON DELETE SET NULL;


--
-- Name: ai_interactions ai_interactions_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_interactions
    ADD CONSTRAINT ai_interactions_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: ai_interactions ai_interactions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_interactions
    ADD CONSTRAINT ai_interactions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id);


--
-- Name: ai_pending_actions ai_pending_actions_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_pending_actions
    ADD CONSTRAINT ai_pending_actions_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: ai_pending_actions ai_pending_actions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_pending_actions
    ADD CONSTRAINT ai_pending_actions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: ai_query_logs ai_query_logs_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_query_logs
    ADD CONSTRAINT ai_query_logs_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: ai_query_logs ai_query_logs_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_query_logs
    ADD CONSTRAINT ai_query_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: archive_locations archive_locations_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.archive_locations
    ADD CONSTRAINT archive_locations_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: audit_log audit_log_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: audit_log audit_log_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id);


--
-- Name: auth_password_resets auth_password_resets_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_password_resets
    ADD CONSTRAINT auth_password_resets_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id);


--
-- Name: brand_assets brand_assets_brand_kit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brand_assets
    ADD CONSTRAINT brand_assets_brand_kit_id_fkey FOREIGN KEY (brand_kit_id) REFERENCES public.brand_kits(id);


--
-- Name: brand_assets brand_assets_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brand_assets
    ADD CONSTRAINT brand_assets_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id);


--
-- Name: brand_assets brand_assets_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brand_assets
    ADD CONSTRAINT brand_assets_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: brand_kits brand_kits_favicon_asset_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brand_kits
    ADD CONSTRAINT brand_kits_favicon_asset_id_fkey FOREIGN KEY (favicon_asset_id) REFERENCES public.brand_assets(id);


--
-- Name: brand_kits brand_kits_icon_asset_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brand_kits
    ADD CONSTRAINT brand_kits_icon_asset_id_fkey FOREIGN KEY (icon_asset_id) REFERENCES public.brand_assets(id);


--
-- Name: brand_kits brand_kits_logo_asset_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brand_kits
    ADD CONSTRAINT brand_kits_logo_asset_id_fkey FOREIGN KEY (logo_asset_id) REFERENCES public.brand_assets(id);


--
-- Name: brand_kits brand_kits_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brand_kits
    ADD CONSTRAINT brand_kits_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: connector_instances connector_instances_connector_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.connector_instances
    ADD CONSTRAINT connector_instances_connector_id_fkey FOREIGN KEY (connector_id) REFERENCES public.connectors(id) ON DELETE CASCADE;


--
-- Name: connector_instances connector_instances_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.connector_instances
    ADD CONSTRAINT connector_instances_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: connector_instances connector_instances_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.connector_instances
    ADD CONSTRAINT connector_instances_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: connectors connectors_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.connectors
    ADD CONSTRAINT connectors_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: cycles cycles_framework_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cycles
    ADD CONSTRAINT cycles_framework_id_fkey FOREIGN KEY (framework_id) REFERENCES public.frameworks(id) ON DELETE SET NULL;


--
-- Name: cycles cycles_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cycles
    ADD CONSTRAINT cycles_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: decisions decisions_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.decisions
    ADD CONSTRAINT decisions_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: decisions decisions_decided_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.decisions
    ADD CONSTRAINT decisions_decided_by_fkey FOREIGN KEY (decided_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: decisions decisions_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.decisions
    ADD CONSTRAINT decisions_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: effectiveness_evaluations effectiveness_evaluations_action_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.effectiveness_evaluations
    ADD CONSTRAINT effectiveness_evaluations_action_id_fkey FOREIGN KEY (action_id) REFERENCES public.strategic_actions(id) ON DELETE SET NULL;


--
-- Name: effectiveness_evaluations effectiveness_evaluations_evaluated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.effectiveness_evaluations
    ADD CONSTRAINT effectiveness_evaluations_evaluated_by_fkey FOREIGN KEY (evaluated_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: effectiveness_evaluations effectiveness_evaluations_kpi_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.effectiveness_evaluations
    ADD CONSTRAINT effectiveness_evaluations_kpi_id_fkey FOREIGN KEY (kpi_id) REFERENCES public.kpis(id) ON DELETE SET NULL;


--
-- Name: effectiveness_evaluations effectiveness_evaluations_objective_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.effectiveness_evaluations
    ADD CONSTRAINT effectiveness_evaluations_objective_id_fkey FOREIGN KEY (objective_id) REFERENCES public.strategic_objectives(id) ON DELETE SET NULL;


--
-- Name: effectiveness_evaluations effectiveness_evaluations_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.effectiveness_evaluations
    ADD CONSTRAINT effectiveness_evaluations_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: evidences evidences_action_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evidences
    ADD CONSTRAINT evidences_action_id_fkey FOREIGN KEY (action_id) REFERENCES public.strategic_actions(id) ON DELETE CASCADE;


--
-- Name: evidences evidences_decision_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evidences
    ADD CONSTRAINT evidences_decision_id_fkey FOREIGN KEY (decision_id) REFERENCES public.decisions(id) ON DELETE CASCADE;


--
-- Name: evidences evidences_kpi_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evidences
    ADD CONSTRAINT evidences_kpi_id_fkey FOREIGN KEY (kpi_id) REFERENCES public.kpis(id) ON DELETE CASCADE;


--
-- Name: evidences evidences_objective_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evidences
    ADD CONSTRAINT evidences_objective_id_fkey FOREIGN KEY (objective_id) REFERENCES public.strategic_objectives(id) ON DELETE CASCADE;


--
-- Name: evidences evidences_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evidences
    ADD CONSTRAINT evidences_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: evidences evidences_uploaded_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evidences
    ADD CONSTRAINT evidences_uploaded_by_fkey FOREIGN KEY (uploaded_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: external_ai_identities external_ai_identities_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.external_ai_identities
    ADD CONSTRAINT external_ai_identities_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: frameworks frameworks_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.frameworks
    ADD CONSTRAINT frameworks_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: generated_files generated_files_generated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.generated_files
    ADD CONSTRAINT generated_files_generated_by_fkey FOREIGN KEY (generated_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: generated_files generated_files_meeting_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.generated_files
    ADD CONSTRAINT generated_files_meeting_id_fkey FOREIGN KEY (meeting_id) REFERENCES public.meetings(id) ON DELETE SET NULL;


--
-- Name: generated_files generated_files_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.generated_files
    ADD CONSTRAINT generated_files_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: generated_files generated_files_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.generated_files
    ADD CONSTRAINT generated_files_template_id_fkey FOREIGN KEY (template_id) REFERENCES public.ppt_templates(id) ON DELETE SET NULL;


--
-- Name: import_registry import_registry_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.import_registry
    ADD CONSTRAINT import_registry_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: kpi_results kpi_results_entered_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kpi_results
    ADD CONSTRAINT kpi_results_entered_by_fkey FOREIGN KEY (entered_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: kpi_results kpi_results_kpi_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kpi_results
    ADD CONSTRAINT kpi_results_kpi_id_fkey FOREIGN KEY (kpi_id) REFERENCES public.kpis(id) ON DELETE CASCADE;


--
-- Name: kpi_targets kpi_targets_kpi_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kpi_targets
    ADD CONSTRAINT kpi_targets_kpi_id_fkey FOREIGN KEY (kpi_id) REFERENCES public.kpis(id) ON DELETE CASCADE;


--
-- Name: kpis kpis_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kpis
    ADD CONSTRAINT kpis_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: kpis kpis_objective_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kpis
    ADD CONSTRAINT kpis_objective_id_fkey FOREIGN KEY (objective_id) REFERENCES public.strategic_objectives(id) ON DELETE SET NULL;


--
-- Name: kpis kpis_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kpis
    ADD CONSTRAINT kpis_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: kpis kpis_responsible_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kpis
    ADD CONSTRAINT kpis_responsible_id_fkey FOREIGN KEY (responsible_id) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: lifecycle_avaliacoes lifecycle_avaliacoes_caso_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_avaliacoes
    ADD CONSTRAINT lifecycle_avaliacoes_caso_id_fkey FOREIGN KEY (caso_id) REFERENCES public.lifecycle_casos(id) ON DELETE CASCADE;


--
-- Name: lifecycle_avaliacoes lifecycle_avaliacoes_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_avaliacoes
    ADD CONSTRAINT lifecycle_avaliacoes_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id);


--
-- Name: lifecycle_avaliacoes lifecycle_avaliacoes_decisao_humana_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_avaliacoes
    ADD CONSTRAINT lifecycle_avaliacoes_decisao_humana_por_fkey FOREIGN KEY (decisao_humana_por) REFERENCES public.profiles(id);


--
-- Name: lifecycle_avaliacoes lifecycle_avaliacoes_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_avaliacoes
    ADD CONSTRAINT lifecycle_avaliacoes_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: lifecycle_avaliacoes lifecycle_avaliacoes_pessoa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_avaliacoes
    ADD CONSTRAINT lifecycle_avaliacoes_pessoa_id_fkey FOREIGN KEY (pessoa_id) REFERENCES public.lifecycle_pessoas(id) ON DELETE CASCADE;


--
-- Name: lifecycle_avaliacoes lifecycle_avaliacoes_vaga_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_avaliacoes
    ADD CONSTRAINT lifecycle_avaliacoes_vaga_id_fkey FOREIGN KEY (vaga_id) REFERENCES public.lifecycle_vagas(id) ON DELETE SET NULL;


--
-- Name: lifecycle_casos lifecycle_casos_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_casos
    ADD CONSTRAINT lifecycle_casos_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id);


--
-- Name: lifecycle_casos lifecycle_casos_duplicado_de_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_casos
    ADD CONSTRAINT lifecycle_casos_duplicado_de_fkey FOREIGN KEY (duplicado_de) REFERENCES public.lifecycle_casos(id) ON DELETE SET NULL;


--
-- Name: lifecycle_casos lifecycle_casos_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_casos
    ADD CONSTRAINT lifecycle_casos_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: lifecycle_casos lifecycle_casos_pessoa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_casos
    ADD CONSTRAINT lifecycle_casos_pessoa_id_fkey FOREIGN KEY (pessoa_id) REFERENCES public.lifecycle_pessoas(id) ON DELETE SET NULL;


--
-- Name: lifecycle_casos lifecycle_casos_vaga_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_casos
    ADD CONSTRAINT lifecycle_casos_vaga_id_fkey FOREIGN KEY (vaga_id) REFERENCES public.lifecycle_vagas(id);


--
-- Name: lifecycle_certificacoes lifecycle_certificacoes_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_certificacoes
    ADD CONSTRAINT lifecycle_certificacoes_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: lifecycle_certificacoes lifecycle_certificacoes_pessoa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_certificacoes
    ADD CONSTRAINT lifecycle_certificacoes_pessoa_id_fkey FOREIGN KEY (pessoa_id) REFERENCES public.lifecycle_pessoas(id) ON DELETE CASCADE;


--
-- Name: lifecycle_competencias lifecycle_competencias_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_competencias
    ADD CONSTRAINT lifecycle_competencias_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: lifecycle_competencias lifecycle_competencias_pessoa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_competencias
    ADD CONSTRAINT lifecycle_competencias_pessoa_id_fkey FOREIGN KEY (pessoa_id) REFERENCES public.lifecycle_pessoas(id) ON DELETE CASCADE;


--
-- Name: lifecycle_comunicacoes lifecycle_comunicacoes_caso_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_comunicacoes
    ADD CONSTRAINT lifecycle_comunicacoes_caso_id_fkey FOREIGN KEY (caso_id) REFERENCES public.lifecycle_casos(id) ON DELETE CASCADE;


--
-- Name: lifecycle_comunicacoes lifecycle_comunicacoes_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_comunicacoes
    ADD CONSTRAINT lifecycle_comunicacoes_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: lifecycle_cv_jobs lifecycle_cv_jobs_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_cv_jobs
    ADD CONSTRAINT lifecycle_cv_jobs_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: lifecycle_cv_jobs lifecycle_cv_jobs_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_cv_jobs
    ADD CONSTRAINT lifecycle_cv_jobs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id);


--
-- Name: lifecycle_entrevistas lifecycle_entrevistas_caso_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_entrevistas
    ADD CONSTRAINT lifecycle_entrevistas_caso_id_fkey FOREIGN KEY (caso_id) REFERENCES public.lifecycle_casos(id) ON DELETE CASCADE;


--
-- Name: lifecycle_entrevistas lifecycle_entrevistas_criado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_entrevistas
    ADD CONSTRAINT lifecycle_entrevistas_criado_por_fkey FOREIGN KEY (criado_por) REFERENCES public.profiles(id);


--
-- Name: lifecycle_entrevistas lifecycle_entrevistas_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_entrevistas
    ADD CONSTRAINT lifecycle_entrevistas_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: lifecycle_experiencias lifecycle_experiencias_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_experiencias
    ADD CONSTRAINT lifecycle_experiencias_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: lifecycle_experiencias lifecycle_experiencias_pessoa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_experiencias
    ADD CONSTRAINT lifecycle_experiencias_pessoa_id_fkey FOREIGN KEY (pessoa_id) REFERENCES public.lifecycle_pessoas(id) ON DELETE CASCADE;


--
-- Name: lifecycle_formacoes lifecycle_formacoes_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_formacoes
    ADD CONSTRAINT lifecycle_formacoes_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: lifecycle_formacoes lifecycle_formacoes_pessoa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_formacoes
    ADD CONSTRAINT lifecycle_formacoes_pessoa_id_fkey FOREIGN KEY (pessoa_id) REFERENCES public.lifecycle_pessoas(id) ON DELETE CASCADE;


--
-- Name: lifecycle_idiomas lifecycle_idiomas_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_idiomas
    ADD CONSTRAINT lifecycle_idiomas_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: lifecycle_idiomas lifecycle_idiomas_pessoa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_idiomas
    ADD CONSTRAINT lifecycle_idiomas_pessoa_id_fkey FOREIGN KEY (pessoa_id) REFERENCES public.lifecycle_pessoas(id) ON DELETE CASCADE;


--
-- Name: lifecycle_pessoas lifecycle_pessoas_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_pessoas
    ADD CONSTRAINT lifecycle_pessoas_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id);


--
-- Name: lifecycle_pessoas lifecycle_pessoas_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_pessoas
    ADD CONSTRAINT lifecycle_pessoas_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: lifecycle_projetos lifecycle_projetos_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_projetos
    ADD CONSTRAINT lifecycle_projetos_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: lifecycle_projetos lifecycle_projetos_pessoa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_projetos
    ADD CONSTRAINT lifecycle_projetos_pessoa_id_fkey FOREIGN KEY (pessoa_id) REFERENCES public.lifecycle_pessoas(id) ON DELETE CASCADE;


--
-- Name: lifecycle_referencias lifecycle_referencias_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_referencias
    ADD CONSTRAINT lifecycle_referencias_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: lifecycle_referencias lifecycle_referencias_pessoa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_referencias
    ADD CONSTRAINT lifecycle_referencias_pessoa_id_fkey FOREIGN KEY (pessoa_id) REFERENCES public.lifecycle_pessoas(id) ON DELETE CASCADE;


--
-- Name: lifecycle_tarefas lifecycle_tarefas_caso_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_tarefas
    ADD CONSTRAINT lifecycle_tarefas_caso_id_fkey FOREIGN KEY (caso_id) REFERENCES public.lifecycle_casos(id) ON DELETE CASCADE;


--
-- Name: lifecycle_tarefas lifecycle_tarefas_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_tarefas
    ADD CONSTRAINT lifecycle_tarefas_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id);


--
-- Name: lifecycle_tarefas lifecycle_tarefas_depends_on_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_tarefas
    ADD CONSTRAINT lifecycle_tarefas_depends_on_fkey FOREIGN KEY (depends_on) REFERENCES public.lifecycle_tarefas(id) ON DELETE SET NULL;


--
-- Name: lifecycle_tarefas lifecycle_tarefas_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_tarefas
    ADD CONSTRAINT lifecycle_tarefas_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: lifecycle_tarefas lifecycle_tarefas_responsavel_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_tarefas
    ADD CONSTRAINT lifecycle_tarefas_responsavel_fkey FOREIGN KEY (responsavel) REFERENCES public.profiles(id);


--
-- Name: lifecycle_vagas lifecycle_vagas_aprovador_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_vagas
    ADD CONSTRAINT lifecycle_vagas_aprovador_fkey FOREIGN KEY (aprovador) REFERENCES public.profiles(id);


--
-- Name: lifecycle_vagas lifecycle_vagas_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_vagas
    ADD CONSTRAINT lifecycle_vagas_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id);


--
-- Name: lifecycle_vagas lifecycle_vagas_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_vagas
    ADD CONSTRAINT lifecycle_vagas_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: meeting_presenters meeting_presenters_meeting_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meeting_presenters
    ADD CONSTRAINT meeting_presenters_meeting_id_fkey FOREIGN KEY (meeting_id) REFERENCES public.meetings(id) ON DELETE CASCADE;


--
-- Name: meeting_presenters meeting_presenters_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meeting_presenters
    ADD CONSTRAINT meeting_presenters_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: meetings meetings_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meetings
    ADD CONSTRAINT meetings_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: meetings meetings_cycle_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meetings
    ADD CONSTRAINT meetings_cycle_id_fkey FOREIGN KEY (cycle_id) REFERENCES public.cycles(id) ON DELETE SET NULL;


--
-- Name: meetings meetings_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meetings
    ADD CONSTRAINT meetings_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: notifications notifications_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: notifications notifications_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: organization_memberships organization_memberships_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organization_memberships
    ADD CONSTRAINT organization_memberships_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: organization_memberships organization_memberships_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organization_memberships
    ADD CONSTRAINT organization_memberships_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: platform_admin_history platform_admin_history_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.platform_admin_history
    ADD CONSTRAINT platform_admin_history_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.profiles(id);


--
-- Name: platform_admin_history platform_admin_history_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.platform_admin_history
    ADD CONSTRAINT platform_admin_history_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: ppt_layouts ppt_layouts_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ppt_layouts
    ADD CONSTRAINT ppt_layouts_template_id_fkey FOREIGN KEY (template_id) REFERENCES public.ppt_templates(id) ON DELETE CASCADE;


--
-- Name: ppt_templates ppt_templates_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ppt_templates
    ADD CONSTRAINT ppt_templates_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: ppt_templates ppt_templates_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ppt_templates
    ADD CONSTRAINT ppt_templates_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: profiles profiles_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: profiles profiles_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: projects projects_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: projects projects_objective_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_objective_id_fkey FOREIGN KEY (objective_id) REFERENCES public.strategic_objectives(id) ON DELETE SET NULL;


--
-- Name: projects projects_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: projects projects_responsible_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_responsible_id_fkey FOREIGN KEY (responsible_id) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: quality_action_dependencies quality_action_dependencies_action_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_action_dependencies
    ADD CONSTRAINT quality_action_dependencies_action_id_fkey FOREIGN KEY (action_id) REFERENCES public.quality_actions(id) ON DELETE CASCADE;


--
-- Name: quality_action_dependencies quality_action_dependencies_depends_on_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_action_dependencies
    ADD CONSTRAINT quality_action_dependencies_depends_on_id_fkey FOREIGN KEY (depends_on_id) REFERENCES public.quality_actions(id) ON DELETE CASCADE;


--
-- Name: quality_action_dependencies quality_action_dependencies_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_action_dependencies
    ADD CONSTRAINT quality_action_dependencies_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: quality_actions quality_actions_acknowledged_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_actions
    ADD CONSTRAINT quality_actions_acknowledged_by_fkey FOREIGN KEY (acknowledged_by) REFERENCES public.profiles(id);


--
-- Name: quality_actions quality_actions_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_actions
    ADD CONSTRAINT quality_actions_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id);


--
-- Name: quality_actions quality_actions_occurrence_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_actions
    ADD CONSTRAINT quality_actions_occurrence_id_fkey FOREIGN KEY (occurrence_id) REFERENCES public.quality_occurrences(id) ON DELETE CASCADE;


--
-- Name: quality_actions quality_actions_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_actions
    ADD CONSTRAINT quality_actions_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: quality_actions quality_actions_plano_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_actions
    ADD CONSTRAINT quality_actions_plano_id_fkey FOREIGN KEY (plano_id) REFERENCES public.quality_compliance_plans(id) ON DELETE SET NULL;


--
-- Name: quality_actions quality_actions_responsible_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_actions
    ADD CONSTRAINT quality_actions_responsible_user_id_fkey FOREIGN KEY (responsible_user_id) REFERENCES public.profiles(id);


--
-- Name: quality_approval_decisions quality_approval_decisions_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_approval_decisions
    ADD CONSTRAINT quality_approval_decisions_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.profiles(id);


--
-- Name: quality_approval_decisions quality_approval_decisions_occurrence_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_approval_decisions
    ADD CONSTRAINT quality_approval_decisions_occurrence_id_fkey FOREIGN KEY (occurrence_id) REFERENCES public.quality_occurrences(id);


--
-- Name: quality_approval_decisions quality_approval_decisions_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_approval_decisions
    ADD CONSTRAINT quality_approval_decisions_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: quality_areas quality_areas_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_areas
    ADD CONSTRAINT quality_areas_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: quality_attachments quality_attachments_action_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_attachments
    ADD CONSTRAINT quality_attachments_action_id_fkey FOREIGN KEY (action_id) REFERENCES public.quality_actions(id) ON DELETE CASCADE;


--
-- Name: quality_attachments quality_attachments_audit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_attachments
    ADD CONSTRAINT quality_attachments_audit_id_fkey FOREIGN KEY (audit_id) REFERENCES public.quality_audits(id);


--
-- Name: quality_attachments quality_attachments_external_response_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_attachments
    ADD CONSTRAINT quality_attachments_external_response_id_fkey FOREIGN KEY (external_response_id) REFERENCES public.quality_external_responses(id);


--
-- Name: quality_attachments quality_attachments_occurrence_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_attachments
    ADD CONSTRAINT quality_attachments_occurrence_id_fkey FOREIGN KEY (occurrence_id) REFERENCES public.quality_occurrences(id) ON DELETE CASCADE;


--
-- Name: quality_attachments quality_attachments_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_attachments
    ADD CONSTRAINT quality_attachments_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: quality_attachments quality_attachments_plano_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_attachments
    ADD CONSTRAINT quality_attachments_plano_id_fkey FOREIGN KEY (plano_id) REFERENCES public.quality_compliance_plans(id) ON DELETE CASCADE;


--
-- Name: quality_attachments quality_attachments_review_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_attachments
    ADD CONSTRAINT quality_attachments_review_id_fkey FOREIGN KEY (review_id) REFERENCES public.quality_effectiveness_reviews(id);


--
-- Name: quality_attachments quality_attachments_uploaded_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_attachments
    ADD CONSTRAINT quality_attachments_uploaded_by_fkey FOREIGN KEY (uploaded_by) REFERENCES public.profiles(id);


--
-- Name: quality_audit_scope quality_audit_scope_area_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_audit_scope
    ADD CONSTRAINT quality_audit_scope_area_id_fkey FOREIGN KEY (area_id) REFERENCES public.quality_areas(id);


--
-- Name: quality_audit_scope quality_audit_scope_audit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_audit_scope
    ADD CONSTRAINT quality_audit_scope_audit_id_fkey FOREIGN KEY (audit_id) REFERENCES public.quality_audits(id);


--
-- Name: quality_audit_scope quality_audit_scope_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_audit_scope
    ADD CONSTRAINT quality_audit_scope_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: quality_audit_scope quality_audit_scope_standard_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_audit_scope
    ADD CONSTRAINT quality_audit_scope_standard_id_fkey FOREIGN KEY (standard_id) REFERENCES public.quality_catalogs(id);


--
-- Name: quality_auditors quality_auditors_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_auditors
    ADD CONSTRAINT quality_auditors_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: quality_audits quality_audits_auditor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_audits
    ADD CONSTRAINT quality_audits_auditor_id_fkey FOREIGN KEY (auditor_id) REFERENCES public.quality_auditors(id);


--
-- Name: quality_audits quality_audits_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_audits
    ADD CONSTRAINT quality_audits_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id);


--
-- Name: quality_audits quality_audits_lead_auditor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_audits
    ADD CONSTRAINT quality_audits_lead_auditor_id_fkey FOREIGN KEY (lead_auditor_id) REFERENCES public.profiles(id);


--
-- Name: quality_audits quality_audits_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_audits
    ADD CONSTRAINT quality_audits_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: quality_catalogs quality_catalogs_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_catalogs
    ADD CONSTRAINT quality_catalogs_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: quality_categories quality_categories_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_categories
    ADD CONSTRAINT quality_categories_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: quality_categories quality_categories_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_categories
    ADD CONSTRAINT quality_categories_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.quality_categories(id);


--
-- Name: quality_comments quality_comments_action_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_comments
    ADD CONSTRAINT quality_comments_action_id_fkey FOREIGN KEY (action_id) REFERENCES public.quality_actions(id) ON DELETE CASCADE;


--
-- Name: quality_comments quality_comments_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_comments
    ADD CONSTRAINT quality_comments_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id);


--
-- Name: quality_comments quality_comments_occurrence_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_comments
    ADD CONSTRAINT quality_comments_occurrence_id_fkey FOREIGN KEY (occurrence_id) REFERENCES public.quality_occurrences(id) ON DELETE CASCADE;


--
-- Name: quality_comments quality_comments_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_comments
    ADD CONSTRAINT quality_comments_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: quality_comments quality_comments_plano_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_comments
    ADD CONSTRAINT quality_comments_plano_id_fkey FOREIGN KEY (plano_id) REFERENCES public.quality_compliance_plans(id) ON DELETE CASCADE;


--
-- Name: quality_compliance_plan_links quality_compliance_plan_links_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_compliance_plan_links
    ADD CONSTRAINT quality_compliance_plan_links_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: quality_compliance_plan_links quality_compliance_plan_links_plan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_compliance_plan_links
    ADD CONSTRAINT quality_compliance_plan_links_plan_id_fkey FOREIGN KEY (plan_id) REFERENCES public.quality_compliance_plans(id) ON DELETE CASCADE;


--
-- Name: quality_compliance_plan_links quality_compliance_plan_links_related_plan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_compliance_plan_links
    ADD CONSTRAINT quality_compliance_plan_links_related_plan_id_fkey FOREIGN KEY (related_plan_id) REFERENCES public.quality_compliance_plans(id) ON DELETE CASCADE;


--
-- Name: quality_compliance_plan_links quality_compliance_plan_links_seu_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_compliance_plan_links
    ADD CONSTRAINT quality_compliance_plan_links_seu_id_fkey FOREIGN KEY (seu_id) REFERENCES public.profiles(id);


--
-- Name: quality_compliance_plans quality_compliance_plans_aprovador_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_compliance_plans
    ADD CONSTRAINT quality_compliance_plans_aprovador_id_fkey FOREIGN KEY (aprovador_id) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: quality_compliance_plans quality_compliance_plans_occurrence_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_compliance_plans
    ADD CONSTRAINT quality_compliance_plans_occurrence_id_fkey FOREIGN KEY (occurrence_id) REFERENCES public.quality_occurrences(id) ON DELETE CASCADE;


--
-- Name: quality_compliance_plans quality_compliance_plans_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_compliance_plans
    ADD CONSTRAINT quality_compliance_plans_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: quality_compliance_plans quality_compliance_plans_rejeitado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_compliance_plans
    ADD CONSTRAINT quality_compliance_plans_rejeitado_por_fkey FOREIGN KEY (rejeitado_por) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: quality_deadline_changes quality_deadline_changes_action_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_deadline_changes
    ADD CONSTRAINT quality_deadline_changes_action_id_fkey FOREIGN KEY (action_id) REFERENCES public.quality_actions(id);


--
-- Name: quality_deadline_changes quality_deadline_changes_decided_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_deadline_changes
    ADD CONSTRAINT quality_deadline_changes_decided_by_fkey FOREIGN KEY (decided_by) REFERENCES public.profiles(id);


--
-- Name: quality_deadline_changes quality_deadline_changes_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_deadline_changes
    ADD CONSTRAINT quality_deadline_changes_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: quality_deadline_changes quality_deadline_changes_requested_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_deadline_changes
    ADD CONSTRAINT quality_deadline_changes_requested_by_fkey FOREIGN KEY (requested_by) REFERENCES public.profiles(id);


--
-- Name: quality_effectiveness_reviews quality_effectiveness_reviews_evaluator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_effectiveness_reviews
    ADD CONSTRAINT quality_effectiveness_reviews_evaluator_id_fkey FOREIGN KEY (evaluator_id) REFERENCES public.profiles(id);


--
-- Name: quality_effectiveness_reviews quality_effectiveness_reviews_occurrence_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_effectiveness_reviews
    ADD CONSTRAINT quality_effectiveness_reviews_occurrence_id_fkey FOREIGN KEY (occurrence_id) REFERENCES public.quality_occurrences(id);


--
-- Name: quality_effectiveness_reviews quality_effectiveness_reviews_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_effectiveness_reviews
    ADD CONSTRAINT quality_effectiveness_reviews_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: quality_external_responses quality_external_responses_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_external_responses
    ADD CONSTRAINT quality_external_responses_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id);


--
-- Name: quality_external_responses quality_external_responses_occurrence_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_external_responses
    ADD CONSTRAINT quality_external_responses_occurrence_id_fkey FOREIGN KEY (occurrence_id) REFERENCES public.quality_occurrences(id);


--
-- Name: quality_external_responses quality_external_responses_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_external_responses
    ADD CONSTRAINT quality_external_responses_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: quality_findings quality_findings_audit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_findings
    ADD CONSTRAINT quality_findings_audit_id_fkey FOREIGN KEY (audit_id) REFERENCES public.quality_audits(id);


--
-- Name: quality_findings quality_findings_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_findings
    ADD CONSTRAINT quality_findings_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id);


--
-- Name: quality_findings quality_findings_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_findings
    ADD CONSTRAINT quality_findings_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: quality_occurrence_categories quality_occurrence_categories_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_occurrence_categories
    ADD CONSTRAINT quality_occurrence_categories_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.quality_categories(id) ON DELETE CASCADE;


--
-- Name: quality_occurrence_categories quality_occurrence_categories_occurrence_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_occurrence_categories
    ADD CONSTRAINT quality_occurrence_categories_occurrence_id_fkey FOREIGN KEY (occurrence_id) REFERENCES public.quality_occurrences(id) ON DELETE CASCADE;


--
-- Name: quality_occurrence_categories quality_occurrence_categories_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_occurrence_categories
    ADD CONSTRAINT quality_occurrence_categories_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: quality_occurrence_relations quality_occurrence_relations_occurrence_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_occurrence_relations
    ADD CONSTRAINT quality_occurrence_relations_occurrence_id_fkey FOREIGN KEY (occurrence_id) REFERENCES public.quality_occurrences(id) ON DELETE CASCADE;


--
-- Name: quality_occurrence_relations quality_occurrence_relations_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_occurrence_relations
    ADD CONSTRAINT quality_occurrence_relations_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: quality_occurrence_relations quality_occurrence_relations_related_occurrence_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_occurrence_relations
    ADD CONSTRAINT quality_occurrence_relations_related_occurrence_id_fkey FOREIGN KEY (related_occurrence_id) REFERENCES public.quality_occurrences(id) ON DELETE CASCADE;


--
-- Name: quality_occurrence_tags quality_occurrence_tags_occurrence_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_occurrence_tags
    ADD CONSTRAINT quality_occurrence_tags_occurrence_id_fkey FOREIGN KEY (occurrence_id) REFERENCES public.quality_occurrences(id) ON DELETE CASCADE;


--
-- Name: quality_occurrence_tags quality_occurrence_tags_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_occurrence_tags
    ADD CONSTRAINT quality_occurrence_tags_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: quality_occurrence_tags quality_occurrence_tags_tag_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_occurrence_tags
    ADD CONSTRAINT quality_occurrence_tags_tag_id_fkey FOREIGN KEY (tag_id) REFERENCES public.quality_tags(id) ON DELETE CASCADE;


--
-- Name: quality_occurrences quality_occurrences_acknowledged_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_occurrences
    ADD CONSTRAINT quality_occurrences_acknowledged_by_fkey FOREIGN KEY (acknowledged_by) REFERENCES public.profiles(id);


--
-- Name: quality_occurrences quality_occurrences_approver_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_occurrences
    ADD CONSTRAINT quality_occurrences_approver_id_fkey FOREIGN KEY (approver_id) REFERENCES public.profiles(id);


--
-- Name: quality_occurrences quality_occurrences_area_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_occurrences
    ADD CONSTRAINT quality_occurrences_area_id_fkey FOREIGN KEY (area_id) REFERENCES public.quality_areas(id);


--
-- Name: quality_occurrences quality_occurrences_audit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_occurrences
    ADD CONSTRAINT quality_occurrences_audit_id_fkey FOREIGN KEY (audit_id) REFERENCES public.quality_audits(id);


--
-- Name: quality_occurrences quality_occurrences_cancelled_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_occurrences
    ADD CONSTRAINT quality_occurrences_cancelled_by_fkey FOREIGN KEY (cancelled_by) REFERENCES public.profiles(id);


--
-- Name: quality_occurrences quality_occurrences_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_occurrences
    ADD CONSTRAINT quality_occurrences_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id);


--
-- Name: quality_occurrences quality_occurrences_effectiveness_validated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_occurrences
    ADD CONSTRAINT quality_occurrences_effectiveness_validated_by_fkey FOREIGN KEY (effectiveness_validated_by) REFERENCES public.profiles(id);


--
-- Name: quality_occurrences quality_occurrences_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_occurrences
    ADD CONSTRAINT quality_occurrences_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: quality_occurrences quality_occurrences_origin_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_occurrences
    ADD CONSTRAINT quality_occurrences_origin_id_fkey FOREIGN KEY (origin_id) REFERENCES public.quality_origins(id);


--
-- Name: quality_occurrences quality_occurrences_related_occurrence_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_occurrences
    ADD CONSTRAINT quality_occurrences_related_occurrence_id_fkey FOREIGN KEY (related_occurrence_id) REFERENCES public.quality_occurrences(id);


--
-- Name: quality_occurrences quality_occurrences_reopened_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_occurrences
    ADD CONSTRAINT quality_occurrences_reopened_by_fkey FOREIGN KEY (reopened_by) REFERENCES public.profiles(id);


--
-- Name: quality_occurrences quality_occurrences_responsible_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_occurrences
    ADD CONSTRAINT quality_occurrences_responsible_user_id_fkey FOREIGN KEY (responsible_user_id) REFERENCES public.profiles(id);


--
-- Name: quality_occurrences quality_occurrences_root_cause_confirmed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_occurrences
    ADD CONSTRAINT quality_occurrences_root_cause_confirmed_by_fkey FOREIGN KEY (root_cause_confirmed_by) REFERENCES public.profiles(id);


--
-- Name: quality_occurrences quality_occurrences_site_scope_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_occurrences
    ADD CONSTRAINT quality_occurrences_site_scope_id_fkey FOREIGN KEY (site_scope_id) REFERENCES public.quality_audit_scope(id);


--
-- Name: quality_occurrences quality_occurrences_standard_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_occurrences
    ADD CONSTRAINT quality_occurrences_standard_id_fkey FOREIGN KEY (standard_id) REFERENCES public.quality_catalogs(id);


--
-- Name: quality_occurrences quality_occurrences_standard_scope_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_occurrences
    ADD CONSTRAINT quality_occurrences_standard_scope_id_fkey FOREIGN KEY (standard_scope_id) REFERENCES public.quality_audit_scope(id);


--
-- Name: quality_origins quality_origins_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_origins
    ADD CONSTRAINT quality_origins_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: quality_outbox quality_outbox_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_outbox
    ADD CONSTRAINT quality_outbox_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: quality_outbox quality_outbox_recipient_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_outbox
    ADD CONSTRAINT quality_outbox_recipient_id_fkey FOREIGN KEY (recipient_id) REFERENCES public.profiles(id);


--
-- Name: quality_plan_approval_events quality_plan_approval_events_decidido_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_plan_approval_events
    ADD CONSTRAINT quality_plan_approval_events_decidido_por_fkey FOREIGN KEY (decidido_por) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: quality_plan_approval_events quality_plan_approval_events_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_plan_approval_events
    ADD CONSTRAINT quality_plan_approval_events_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: quality_plan_approval_events quality_plan_approval_events_plan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_plan_approval_events
    ADD CONSTRAINT quality_plan_approval_events_plan_id_fkey FOREIGN KEY (plan_id) REFERENCES public.quality_compliance_plans(id) ON DELETE CASCADE;


--
-- Name: quality_progress_history quality_progress_history_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_progress_history
    ADD CONSTRAINT quality_progress_history_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: quality_settings quality_settings_escalation_leader_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_settings
    ADD CONSTRAINT quality_settings_escalation_leader_id_fkey FOREIGN KEY (escalation_leader_id) REFERENCES public.profiles(id);


--
-- Name: quality_settings quality_settings_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_settings
    ADD CONSTRAINT quality_settings_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: quality_tags quality_tags_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_tags
    ADD CONSTRAINT quality_tags_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: quality_work_logs quality_work_logs_action_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_work_logs
    ADD CONSTRAINT quality_work_logs_action_id_fkey FOREIGN KEY (action_id) REFERENCES public.quality_actions(id) ON DELETE CASCADE;


--
-- Name: quality_work_logs quality_work_logs_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_work_logs
    ADD CONSTRAINT quality_work_logs_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: risk_opportunities risk_opportunities_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.risk_opportunities
    ADD CONSTRAINT risk_opportunities_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: risk_opportunities risk_opportunities_cycle_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.risk_opportunities
    ADD CONSTRAINT risk_opportunities_cycle_id_fkey FOREIGN KEY (cycle_id) REFERENCES public.cycles(id) ON DELETE SET NULL;


--
-- Name: risk_opportunities risk_opportunities_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.risk_opportunities
    ADD CONSTRAINT risk_opportunities_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: risk_opportunities risk_opportunities_responsible_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.risk_opportunities
    ADD CONSTRAINT risk_opportunities_responsible_id_fkey FOREIGN KEY (responsible_id) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: risk_opportunities risk_opportunities_source_tows_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.risk_opportunities
    ADD CONSTRAINT risk_opportunities_source_tows_id_fkey FOREIGN KEY (source_tows_id) REFERENCES public.tows_crossings(id) ON DELETE RESTRICT;


--
-- Name: roles roles_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: strategic_actions strategic_actions_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.strategic_actions
    ADD CONSTRAINT strategic_actions_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: strategic_actions strategic_actions_objective_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.strategic_actions
    ADD CONSTRAINT strategic_actions_objective_id_fkey FOREIGN KEY (objective_id) REFERENCES public.strategic_objectives(id) ON DELETE CASCADE;


--
-- Name: strategic_actions strategic_actions_responsible_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.strategic_actions
    ADD CONSTRAINT strategic_actions_responsible_id_fkey FOREIGN KEY (responsible_id) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: strategic_objectives strategic_objectives_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.strategic_objectives
    ADD CONSTRAINT strategic_objectives_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: strategic_objectives strategic_objectives_cycle_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.strategic_objectives
    ADD CONSTRAINT strategic_objectives_cycle_id_fkey FOREIGN KEY (cycle_id) REFERENCES public.cycles(id) ON DELETE SET NULL;


--
-- Name: strategic_objectives strategic_objectives_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.strategic_objectives
    ADD CONSTRAINT strategic_objectives_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: strategic_objectives strategic_objectives_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.strategic_objectives
    ADD CONSTRAINT strategic_objectives_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.strategic_objectives(id) ON DELETE SET NULL;


--
-- Name: strategic_objectives strategic_objectives_responsible_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.strategic_objectives
    ADD CONSTRAINT strategic_objectives_responsible_id_fkey FOREIGN KEY (responsible_id) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: strategy_area_teams strategy_area_teams_area_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.strategy_area_teams
    ADD CONSTRAINT strategy_area_teams_area_id_fkey FOREIGN KEY (area_id) REFERENCES public.strategy_thematic_areas(id);


--
-- Name: strategy_area_teams strategy_area_teams_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.strategy_area_teams
    ADD CONSTRAINT strategy_area_teams_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: strategy_area_teams strategy_area_teams_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.strategy_area_teams
    ADD CONSTRAINT strategy_area_teams_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id);


--
-- Name: strategy_history strategy_history_reviewed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.strategy_history
    ADD CONSTRAINT strategy_history_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES public.profiles(id);


--
-- Name: strategy_thematic_areas strategy_thematic_areas_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.strategy_thematic_areas
    ADD CONSTRAINT strategy_thematic_areas_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: submissions submissions_action_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.submissions
    ADD CONSTRAINT submissions_action_id_fkey FOREIGN KEY (action_id) REFERENCES public.strategic_actions(id) ON DELETE SET NULL;


--
-- Name: submissions submissions_kpi_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.submissions
    ADD CONSTRAINT submissions_kpi_id_fkey FOREIGN KEY (kpi_id) REFERENCES public.kpis(id) ON DELETE SET NULL;


--
-- Name: submissions submissions_meeting_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.submissions
    ADD CONSTRAINT submissions_meeting_id_fkey FOREIGN KEY (meeting_id) REFERENCES public.meetings(id) ON DELETE CASCADE;


--
-- Name: submissions submissions_objective_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.submissions
    ADD CONSTRAINT submissions_objective_id_fkey FOREIGN KEY (objective_id) REFERENCES public.strategic_objectives(id) ON DELETE SET NULL;


--
-- Name: submissions submissions_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.submissions
    ADD CONSTRAINT submissions_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE SET NULL;


--
-- Name: submissions submissions_reviewed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.submissions
    ADD CONSTRAINT submissions_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: submissions submissions_submitted_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.submissions
    ADD CONSTRAINT submissions_submitted_by_fkey FOREIGN KEY (submitted_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: swot_campaign_audience swot_campaign_audience_campaign_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_campaign_audience
    ADD CONSTRAINT swot_campaign_audience_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES public.swot_campaigns(id);


--
-- Name: swot_campaign_audience swot_campaign_audience_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_campaign_audience
    ADD CONSTRAINT swot_campaign_audience_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: swot_campaign_audience swot_campaign_audience_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_campaign_audience
    ADD CONSTRAINT swot_campaign_audience_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id);


--
-- Name: swot_campaign_audience swot_campaign_audience_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_campaign_audience
    ADD CONSTRAINT swot_campaign_audience_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id);


--
-- Name: swot_campaign_validators swot_campaign_validators_campaign_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_campaign_validators
    ADD CONSTRAINT swot_campaign_validators_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES public.swot_campaigns(id);


--
-- Name: swot_campaign_validators swot_campaign_validators_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_campaign_validators
    ADD CONSTRAINT swot_campaign_validators_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: swot_campaign_validators swot_campaign_validators_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_campaign_validators
    ADD CONSTRAINT swot_campaign_validators_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id);


--
-- Name: swot_campaign_validators swot_campaign_validators_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_campaign_validators
    ADD CONSTRAINT swot_campaign_validators_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id);


--
-- Name: swot_campaigns swot_campaigns_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_campaigns
    ADD CONSTRAINT swot_campaigns_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: swot_campaigns swot_campaigns_cycle_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_campaigns
    ADD CONSTRAINT swot_campaigns_cycle_id_fkey FOREIGN KEY (cycle_id) REFERENCES public.cycles(id) ON DELETE SET NULL;


--
-- Name: swot_campaigns swot_campaigns_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_campaigns
    ADD CONSTRAINT swot_campaigns_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: swot_context_reviews swot_context_reviews_contribution_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_context_reviews
    ADD CONSTRAINT swot_context_reviews_contribution_id_fkey FOREIGN KEY (contribution_id) REFERENCES public.swot_contributions(id);


--
-- Name: swot_context_reviews swot_context_reviews_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_context_reviews
    ADD CONSTRAINT swot_context_reviews_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: swot_context_reviews swot_context_reviews_reviewer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_context_reviews
    ADD CONSTRAINT swot_context_reviews_reviewer_id_fkey FOREIGN KEY (reviewer_id) REFERENCES public.profiles(id);


--
-- Name: swot_contributions swot_contributions_campaign_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_contributions
    ADD CONSTRAINT swot_contributions_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES public.swot_campaigns(id);


--
-- Name: swot_contributions swot_contributions_imported_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_contributions
    ADD CONSTRAINT swot_contributions_imported_by_fkey FOREIGN KEY (imported_by) REFERENCES public.profiles(id);


--
-- Name: swot_contributions swot_contributions_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_contributions
    ADD CONSTRAINT swot_contributions_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.swot_items(id) ON DELETE CASCADE;


--
-- Name: swot_contributions swot_contributions_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_contributions
    ADD CONSTRAINT swot_contributions_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: swot_contributions swot_contributions_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_contributions
    ADD CONSTRAINT swot_contributions_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id);


--
-- Name: swot_contributions swot_contributions_thematic_area_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_contributions
    ADD CONSTRAINT swot_contributions_thematic_area_id_fkey FOREIGN KEY (thematic_area_id) REFERENCES public.strategy_thematic_areas(id);


--
-- Name: swot_contributions swot_contributions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_contributions
    ADD CONSTRAINT swot_contributions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: swot_items swot_items_campaign_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_items
    ADD CONSTRAINT swot_items_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES public.swot_campaigns(id) ON DELETE CASCADE;


--
-- Name: swot_items swot_items_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_items
    ADD CONSTRAINT swot_items_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: swot_items swot_items_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_items
    ADD CONSTRAINT swot_items_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id);


--
-- Name: swot_items swot_items_thematic_area_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_items
    ADD CONSTRAINT swot_items_thematic_area_id_fkey FOREIGN KEY (thematic_area_id) REFERENCES public.strategy_thematic_areas(id);


--
-- Name: swot_participant_contexts swot_participant_contexts_campaign_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_participant_contexts
    ADD CONSTRAINT swot_participant_contexts_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES public.swot_campaigns(id);


--
-- Name: swot_participant_contexts swot_participant_contexts_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_participant_contexts
    ADD CONSTRAINT swot_participant_contexts_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: swot_participant_contexts swot_participant_contexts_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_participant_contexts
    ADD CONSTRAINT swot_participant_contexts_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id);


--
-- Name: swot_participant_contexts swot_participant_contexts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_participant_contexts
    ADD CONSTRAINT swot_participant_contexts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id);


--
-- Name: swot_proposals swot_proposals_campaign_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_proposals
    ADD CONSTRAINT swot_proposals_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES public.swot_campaigns(id);


--
-- Name: swot_proposals swot_proposals_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_proposals
    ADD CONSTRAINT swot_proposals_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id);


--
-- Name: swot_proposals swot_proposals_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_proposals
    ADD CONSTRAINT swot_proposals_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.swot_items(id);


--
-- Name: swot_proposals swot_proposals_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_proposals
    ADD CONSTRAINT swot_proposals_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: swot_proposals swot_proposals_thematic_area_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_proposals
    ADD CONSTRAINT swot_proposals_thematic_area_id_fkey FOREIGN KEY (thematic_area_id) REFERENCES public.strategy_thematic_areas(id);


--
-- Name: swot_proposals swot_proposals_validated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_proposals
    ADD CONSTRAINT swot_proposals_validated_by_fkey FOREIGN KEY (validated_by) REFERENCES public.profiles(id);


--
-- Name: swot_submissions swot_submissions_authorized_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_submissions
    ADD CONSTRAINT swot_submissions_authorized_by_fkey FOREIGN KEY (authorized_by) REFERENCES public.profiles(id);


--
-- Name: swot_submissions swot_submissions_campaign_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_submissions
    ADD CONSTRAINT swot_submissions_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES public.swot_campaigns(id);


--
-- Name: swot_submissions swot_submissions_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_submissions
    ADD CONSTRAINT swot_submissions_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: swot_submissions swot_submissions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swot_submissions
    ADD CONSTRAINT swot_submissions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id);


--
-- Name: teams teams_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teams
    ADD CONSTRAINT teams_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: tows_crossings tows_crossings_campaign_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tows_crossings
    ADD CONSTRAINT tows_crossings_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES public.swot_campaigns(id) ON DELETE CASCADE;


--
-- Name: tows_crossings tows_crossings_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tows_crossings
    ADD CONSTRAINT tows_crossings_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: tows_crossings tows_crossings_o_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tows_crossings
    ADD CONSTRAINT tows_crossings_o_item_id_fkey FOREIGN KEY (o_item_id) REFERENCES public.swot_items(id) ON DELETE SET NULL;


--
-- Name: tows_crossings tows_crossings_s_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tows_crossings
    ADD CONSTRAINT tows_crossings_s_item_id_fkey FOREIGN KEY (s_item_id) REFERENCES public.swot_items(id) ON DELETE SET NULL;


--
-- Name: tows_crossings tows_crossings_t_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tows_crossings
    ADD CONSTRAINT tows_crossings_t_item_id_fkey FOREIGN KEY (t_item_id) REFERENCES public.swot_items(id) ON DELETE SET NULL;


--
-- Name: tows_crossings tows_crossings_w_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tows_crossings
    ADD CONSTRAINT tows_crossings_w_item_id_fkey FOREIGN KEY (w_item_id) REFERENCES public.swot_items(id) ON DELETE SET NULL;


--
-- Name: user_access_history user_access_history_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_access_history
    ADD CONSTRAINT user_access_history_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.profiles(id);


--
-- Name: user_assignments user_assignments_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_assignments
    ADD CONSTRAINT user_assignments_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: user_assignments user_assignments_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_assignments
    ADD CONSTRAINT user_assignments_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id);


--
-- Name: user_assignments user_assignments_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_assignments
    ADD CONSTRAINT user_assignments_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id);


--
-- Name: quality_actions actions_read_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY actions_read_authenticated ON public.quality_actions FOR SELECT USING (public.is_any_authenticated());


--
-- Name: quality_actions actions_update_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY actions_update_own ON public.quality_actions FOR UPDATE USING ((responsible_user_id = auth.uid())) WITH CHECK ((responsible_user_id = auth.uid()));


--
-- Name: quality_actions actions_write_quality; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY actions_write_quality ON public.quality_actions USING (public.is_quality_or_admin()) WITH CHECK (public.is_quality_or_admin());


--
-- Name: ai_action_logs ai_action_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ai_action_admin ON public.ai_action_logs USING (public.is_admin_user(auth.uid())) WITH CHECK (public.is_admin_user(auth.uid()));


--
-- Name: ai_action_logs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ai_action_logs ENABLE ROW LEVEL SECURITY;

--
-- Name: ai_action_logs ai_action_self; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ai_action_self ON public.ai_action_logs FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: ai_interactions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ai_interactions ENABLE ROW LEVEL SECURITY;

--
-- Name: ai_interactions ai_interactions_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ai_interactions_insert_own ON public.ai_interactions FOR INSERT WITH CHECK ((user_id = auth.uid()));


--
-- Name: ai_interactions ai_interactions_read_quality; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ai_interactions_read_quality ON public.ai_interactions FOR SELECT USING (public.is_quality_or_admin());


--
-- Name: ai_query_logs ai_logs_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ai_logs_insert ON public.ai_query_logs FOR INSERT WITH CHECK (true);


--
-- Name: ai_query_logs ai_logs_read_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ai_logs_read_own ON public.ai_query_logs FOR SELECT USING ((user_id = auth.uid()));


--
-- Name: ai_query_logs ai_logs_read_quality; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ai_logs_read_quality ON public.ai_query_logs FOR SELECT USING (public.is_quality_or_admin());


--
-- Name: ai_pending_actions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ai_pending_actions ENABLE ROW LEVEL SECURITY;

--
-- Name: ai_query_logs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ai_query_logs ENABLE ROW LEVEL SECURITY;

--
-- Name: app_settings; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

--
-- Name: app_settings app_settings_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY app_settings_read ON public.app_settings FOR SELECT USING (public.is_any_authenticated());


--
-- Name: app_settings app_settings_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY app_settings_update ON public.app_settings FOR UPDATE USING (public.is_quality_or_admin());


--
-- Name: app_settings app_settings_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY app_settings_write ON public.app_settings FOR INSERT WITH CHECK (public.is_quality_or_admin());


--
-- Name: app_versions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.app_versions ENABLE ROW LEVEL SECURITY;

--
-- Name: app_versions app_versions_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY app_versions_read ON public.app_versions FOR SELECT TO authenticated USING (true);


--
-- Name: app_versions app_versions_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY app_versions_write ON public.app_versions TO authenticated USING (public.is_quality_or_admin()) WITH CHECK (public.is_quality_or_admin());


--
-- Name: archive_locations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.archive_locations ENABLE ROW LEVEL SECURITY;

--
-- Name: archive_locations archive_locations_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY archive_locations_read ON public.archive_locations FOR SELECT TO authenticated USING (true);


--
-- Name: archive_locations archive_locations_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY archive_locations_write ON public.archive_locations TO authenticated USING (public.is_quality_or_admin()) WITH CHECK (public.is_quality_or_admin());


--
-- Name: quality_areas areas_read_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY areas_read_authenticated ON public.quality_areas FOR SELECT USING (public.is_any_authenticated());


--
-- Name: quality_areas areas_write_quality_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY areas_write_quality_admin ON public.quality_areas USING (public.is_quality_or_admin()) WITH CHECK (public.is_quality_or_admin());


--
-- Name: quality_attachments attachments_read_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY attachments_read_authenticated ON public.quality_attachments FOR SELECT USING (public.is_any_authenticated());


--
-- Name: quality_attachments attachments_write_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY attachments_write_own ON public.quality_attachments FOR INSERT WITH CHECK ((uploaded_by = auth.uid()));


--
-- Name: quality_attachments attachments_write_quality; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY attachments_write_quality ON public.quality_attachments USING (public.is_quality_or_admin()) WITH CHECK (public.is_quality_or_admin());


--
-- Name: audit_log audit_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY audit_insert_own ON public.audit_log FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: audit_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;

--
-- Name: audit_log audit_read_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY audit_read_own ON public.audit_log FOR SELECT USING ((user_id = auth.uid()));


--
-- Name: audit_log audit_read_quality_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY audit_read_quality_admin ON public.audit_log FOR SELECT USING (public.is_quality_or_admin());


--
-- Name: brand_assets; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.brand_assets ENABLE ROW LEVEL SECURITY;

--
-- Name: brand_kits; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.brand_kits ENABLE ROW LEVEL SECURITY;

--
-- Name: brand_kits brand_kits_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY brand_kits_read ON public.brand_kits FOR SELECT TO authenticated USING (true);


--
-- Name: brand_kits brand_kits_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY brand_kits_write ON public.brand_kits TO authenticated USING (public.is_quality_or_admin()) WITH CHECK (public.is_quality_or_admin());


--
-- Name: quality_categories categories_read_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY categories_read_authenticated ON public.quality_categories FOR SELECT USING (public.is_any_authenticated());


--
-- Name: quality_categories categories_write_quality; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY categories_write_quality ON public.quality_categories USING (public.is_quality_or_admin()) WITH CHECK (public.is_quality_or_admin());


--
-- Name: quality_comments comments_read_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY comments_read_authenticated ON public.quality_comments FOR SELECT USING (public.is_any_authenticated());


--
-- Name: quality_comments comments_write_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY comments_write_authenticated ON public.quality_comments FOR INSERT WITH CHECK ((created_by = auth.uid()));


--
-- Name: ai_action_logs company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY company_boundary ON public.ai_action_logs AS RESTRICTIVE USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())))) WITH CHECK ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: ai_interactions company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY company_boundary ON public.ai_interactions AS RESTRICTIVE USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())))) WITH CHECK ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: ai_pending_actions company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY company_boundary ON public.ai_pending_actions AS RESTRICTIVE USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())))) WITH CHECK ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: ai_query_logs company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY company_boundary ON public.ai_query_logs AS RESTRICTIVE USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())))) WITH CHECK ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: audit_log company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY company_boundary ON public.audit_log AS RESTRICTIVE USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())))) WITH CHECK ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: import_registry company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY company_boundary ON public.import_registry AS RESTRICTIVE USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())))) WITH CHECK ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: lifecycle_avaliacoes company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY company_boundary ON public.lifecycle_avaliacoes AS RESTRICTIVE USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())))) WITH CHECK ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: lifecycle_casos company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY company_boundary ON public.lifecycle_casos AS RESTRICTIVE USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())))) WITH CHECK ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: lifecycle_certificacoes company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY company_boundary ON public.lifecycle_certificacoes AS RESTRICTIVE USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())))) WITH CHECK ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: lifecycle_competencias company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY company_boundary ON public.lifecycle_competencias AS RESTRICTIVE USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())))) WITH CHECK ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: lifecycle_comunicacoes company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY company_boundary ON public.lifecycle_comunicacoes AS RESTRICTIVE USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())))) WITH CHECK ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: lifecycle_cv_jobs company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY company_boundary ON public.lifecycle_cv_jobs AS RESTRICTIVE USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())))) WITH CHECK ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: lifecycle_entrevistas company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY company_boundary ON public.lifecycle_entrevistas AS RESTRICTIVE USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())))) WITH CHECK ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: lifecycle_experiencias company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY company_boundary ON public.lifecycle_experiencias AS RESTRICTIVE USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())))) WITH CHECK ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: lifecycle_formacoes company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY company_boundary ON public.lifecycle_formacoes AS RESTRICTIVE USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())))) WITH CHECK ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: lifecycle_idiomas company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY company_boundary ON public.lifecycle_idiomas AS RESTRICTIVE USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())))) WITH CHECK ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: lifecycle_pessoas company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY company_boundary ON public.lifecycle_pessoas AS RESTRICTIVE USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())))) WITH CHECK ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: lifecycle_projetos company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY company_boundary ON public.lifecycle_projetos AS RESTRICTIVE USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())))) WITH CHECK ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: lifecycle_referencias company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY company_boundary ON public.lifecycle_referencias AS RESTRICTIVE USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())))) WITH CHECK ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: lifecycle_tarefas company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY company_boundary ON public.lifecycle_tarefas AS RESTRICTIVE USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())))) WITH CHECK ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: lifecycle_vagas company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY company_boundary ON public.lifecycle_vagas AS RESTRICTIVE USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())))) WITH CHECK ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: quality_action_dependencies company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY company_boundary ON public.quality_action_dependencies AS RESTRICTIVE USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())))) WITH CHECK ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: quality_actions company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY company_boundary ON public.quality_actions AS RESTRICTIVE USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())))) WITH CHECK ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: quality_areas company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY company_boundary ON public.quality_areas AS RESTRICTIVE USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())))) WITH CHECK ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: quality_attachments company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY company_boundary ON public.quality_attachments AS RESTRICTIVE USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())))) WITH CHECK ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: quality_categories company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY company_boundary ON public.quality_categories AS RESTRICTIVE USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())))) WITH CHECK ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: quality_comments company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY company_boundary ON public.quality_comments AS RESTRICTIVE USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())))) WITH CHECK ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: quality_compliance_plan_links company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY company_boundary ON public.quality_compliance_plan_links AS RESTRICTIVE USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())))) WITH CHECK ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: quality_compliance_plans company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY company_boundary ON public.quality_compliance_plans AS RESTRICTIVE USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())))) WITH CHECK ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: quality_occurrence_categories company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY company_boundary ON public.quality_occurrence_categories AS RESTRICTIVE USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())))) WITH CHECK ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: quality_occurrence_relations company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY company_boundary ON public.quality_occurrence_relations AS RESTRICTIVE USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())))) WITH CHECK ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: quality_occurrence_tags company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY company_boundary ON public.quality_occurrence_tags AS RESTRICTIVE USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())))) WITH CHECK ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: quality_occurrences company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY company_boundary ON public.quality_occurrences AS RESTRICTIVE USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())))) WITH CHECK ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: quality_origins company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY company_boundary ON public.quality_origins AS RESTRICTIVE USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())))) WITH CHECK ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: quality_plan_approval_events company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY company_boundary ON public.quality_plan_approval_events AS RESTRICTIVE USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())))) WITH CHECK ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: quality_progress_history company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY company_boundary ON public.quality_progress_history AS RESTRICTIVE USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())))) WITH CHECK ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: quality_tags company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY company_boundary ON public.quality_tags AS RESTRICTIVE USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())))) WITH CHECK ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: quality_work_logs company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY company_boundary ON public.quality_work_logs AS RESTRICTIVE USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())))) WITH CHECK ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: quality_auditors company_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY company_read ON public.quality_auditors FOR SELECT TO authenticated USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: strategy_area_teams company_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY company_read ON public.strategy_area_teams FOR SELECT TO authenticated USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())) AND public.has_module('strategy'::text)));


--
-- Name: strategy_thematic_areas company_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY company_read ON public.strategy_thematic_areas FOR SELECT TO authenticated USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())) AND public.has_module('strategy'::text)));


--
-- Name: swot_campaign_validators company_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY company_read ON public.swot_campaign_validators FOR SELECT TO authenticated USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())) AND public.has_module('strategy'::text)));


--
-- Name: swot_context_reviews company_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY company_read ON public.swot_context_reviews FOR SELECT TO authenticated USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())) AND public.has_module('strategy'::text)));


--
-- Name: swot_participant_contexts company_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY company_read ON public.swot_participant_contexts FOR SELECT TO authenticated USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())) AND public.has_module('strategy'::text)));


--
-- Name: swot_submissions company_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY company_read ON public.swot_submissions FOR SELECT TO authenticated USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())) AND public.has_module('strategy'::text)));


--
-- Name: user_assignments company_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY company_read ON public.user_assignments FOR SELECT TO authenticated USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: connector_instances; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.connector_instances ENABLE ROW LEVEL SECURITY;

--
-- Name: connector_instances connector_instances_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY connector_instances_read ON public.connector_instances FOR SELECT TO authenticated USING (true);


--
-- Name: connector_instances connector_instances_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY connector_instances_write ON public.connector_instances TO authenticated USING (public.is_quality_or_admin()) WITH CHECK (public.is_quality_or_admin());


--
-- Name: connectors; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.connectors ENABLE ROW LEVEL SECURITY;

--
-- Name: connectors connectors_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY connectors_read ON public.connectors FOR SELECT TO authenticated USING (true);


--
-- Name: connectors connectors_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY connectors_write ON public.connectors TO authenticated USING (public.has_responsibility('strategy'::text, ARRAY['admin'::text, 'quality'::text])) WITH CHECK (public.has_responsibility('strategy'::text, ARRAY['admin'::text, 'quality'::text]));


--
-- Name: cycles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.cycles ENABLE ROW LEVEL SECURITY;

--
-- Name: cycles cycles_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY cycles_read ON public.cycles FOR SELECT TO authenticated USING (true);


--
-- Name: cycles cycles_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY cycles_write ON public.cycles TO authenticated USING (public.has_responsibility('strategy'::text, ARRAY['admin'::text, 'quality'::text])) WITH CHECK (public.has_responsibility('strategy'::text, ARRAY['admin'::text, 'quality'::text]));


--
-- Name: data_reset_history; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.data_reset_history ENABLE ROW LEVEL SECURITY;

--
-- Name: decisions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.decisions ENABLE ROW LEVEL SECURITY;

--
-- Name: decisions decisions_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY decisions_read ON public.decisions FOR SELECT TO authenticated USING (true);


--
-- Name: decisions decisions_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY decisions_write ON public.decisions TO authenticated USING (public.has_responsibility('strategy'::text, ARRAY['admin'::text, 'quality'::text])) WITH CHECK (public.has_responsibility('strategy'::text, ARRAY['admin'::text, 'quality'::text]));


--
-- Name: brand_assets delta_company_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY delta_company_read ON public.brand_assets FOR SELECT TO authenticated USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: platform_admin_history delta_company_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY delta_company_read ON public.platform_admin_history FOR SELECT TO authenticated USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())) AND public.has_module('strategy'::text)));


--
-- Name: swot_campaign_audience delta_company_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY delta_company_read ON public.swot_campaign_audience FOR SELECT TO authenticated USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())) AND public.has_module('strategy'::text)));


--
-- Name: swot_proposals delta_company_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY delta_company_read ON public.swot_proposals FOR SELECT TO authenticated USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())) AND public.has_module('strategy'::text)));


--
-- Name: effectiveness_evaluations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.effectiveness_evaluations ENABLE ROW LEVEL SECURITY;

--
-- Name: effectiveness_evaluations effectiveness_evaluations_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY effectiveness_evaluations_read ON public.effectiveness_evaluations FOR SELECT TO authenticated USING (true);


--
-- Name: effectiveness_evaluations effectiveness_evaluations_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY effectiveness_evaluations_write ON public.effectiveness_evaluations TO authenticated USING (public.is_quality_or_admin()) WITH CHECK (public.is_quality_or_admin());


--
-- Name: evidences; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.evidences ENABLE ROW LEVEL SECURITY;

--
-- Name: evidences evidences_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY evidences_read ON public.evidences FOR SELECT TO authenticated USING (true);


--
-- Name: evidences evidences_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY evidences_write ON public.evidences TO authenticated USING (public.is_quality_or_admin()) WITH CHECK (public.is_quality_or_admin());


--
-- Name: external_ai_identities ext_ai_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ext_ai_admin ON public.external_ai_identities FOR SELECT USING (public.is_admin_user(auth.uid()));


--
-- Name: external_ai_identities ext_ai_self; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ext_ai_self ON public.external_ai_identities USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: external_ai_identities; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.external_ai_identities ENABLE ROW LEVEL SECURITY;

--
-- Name: feature_flags; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.feature_flags ENABLE ROW LEVEL SECURITY;

--
-- Name: feature_flags feature_flags_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY feature_flags_read ON public.feature_flags FOR SELECT TO authenticated USING (true);


--
-- Name: feature_flags feature_flags_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY feature_flags_write ON public.feature_flags TO authenticated USING (public.is_quality_or_admin()) WITH CHECK (public.is_quality_or_admin());


--
-- Name: feature_flags flags_read_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY flags_read_authenticated ON public.feature_flags FOR SELECT USING (public.is_any_authenticated());


--
-- Name: feature_flags flags_write_quality; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY flags_write_quality ON public.feature_flags USING (public.is_quality_or_admin()) WITH CHECK (public.is_quality_or_admin());


--
-- Name: frameworks; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.frameworks ENABLE ROW LEVEL SECURITY;

--
-- Name: frameworks frameworks_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY frameworks_read ON public.frameworks FOR SELECT TO authenticated USING (true);


--
-- Name: frameworks frameworks_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY frameworks_write ON public.frameworks TO authenticated USING (public.has_responsibility('strategy'::text, ARRAY['admin'::text, 'quality'::text])) WITH CHECK (public.has_responsibility('strategy'::text, ARRAY['admin'::text, 'quality'::text]));


--
-- Name: generated_files; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.generated_files ENABLE ROW LEVEL SECURITY;

--
-- Name: generated_files generated_files_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY generated_files_read ON public.generated_files FOR SELECT TO authenticated USING (true);


--
-- Name: generated_files generated_files_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY generated_files_write ON public.generated_files TO authenticated USING (public.has_responsibility('strategy'::text, ARRAY['admin'::text, 'quality'::text])) WITH CHECK (public.has_responsibility('strategy'::text, ARRAY['admin'::text, 'quality'::text]));


--
-- Name: import_registry; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.import_registry ENABLE ROW LEVEL SECURITY;

--
-- Name: kpi_results; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.kpi_results ENABLE ROW LEVEL SECURITY;

--
-- Name: kpi_results kpi_results_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY kpi_results_read ON public.kpi_results FOR SELECT TO authenticated USING (true);


--
-- Name: kpi_results kpi_results_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY kpi_results_write ON public.kpi_results TO authenticated USING (public.has_responsibility('strategy'::text, ARRAY['admin'::text, 'quality'::text])) WITH CHECK (public.has_responsibility('strategy'::text, ARRAY['admin'::text, 'quality'::text]));


--
-- Name: kpi_targets; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.kpi_targets ENABLE ROW LEVEL SECURITY;

--
-- Name: kpi_targets kpi_targets_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY kpi_targets_read ON public.kpi_targets FOR SELECT TO authenticated USING (true);


--
-- Name: kpi_targets kpi_targets_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY kpi_targets_write ON public.kpi_targets TO authenticated USING (public.has_responsibility('strategy'::text, ARRAY['admin'::text, 'quality'::text])) WITH CHECK (public.has_responsibility('strategy'::text, ARRAY['admin'::text, 'quality'::text]));


--
-- Name: kpis; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.kpis ENABLE ROW LEVEL SECURITY;

--
-- Name: kpis kpis_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY kpis_read ON public.kpis FOR SELECT TO authenticated USING (true);


--
-- Name: kpis kpis_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY kpis_write ON public.kpis TO authenticated USING (public.has_responsibility('strategy'::text, ARRAY['admin'::text, 'quality'::text])) WITH CHECK (public.has_responsibility('strategy'::text, ARRAY['admin'::text, 'quality'::text]));


--
-- Name: lifecycle_casos lc_casos_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY lc_casos_read ON public.lifecycle_casos FOR SELECT USING (public.is_any_authenticated());


--
-- Name: lifecycle_casos lc_casos_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY lc_casos_write ON public.lifecycle_casos TO authenticated USING (public.has_responsibility('lifecycle'::text, ARRAY['admin'::text, 'quality'::text])) WITH CHECK (public.has_responsibility('lifecycle'::text, ARRAY['admin'::text, 'quality'::text]));


--
-- Name: lifecycle_comunicacoes lc_com_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY lc_com_read ON public.lifecycle_comunicacoes FOR SELECT USING (public.is_any_authenticated());


--
-- Name: lifecycle_comunicacoes lc_com_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY lc_com_write ON public.lifecycle_comunicacoes TO authenticated USING (public.has_responsibility('lifecycle'::text, ARRAY['admin'::text, 'quality'::text])) WITH CHECK (public.has_responsibility('lifecycle'::text, ARRAY['admin'::text, 'quality'::text]));


--
-- Name: lifecycle_tarefas lc_tarefas_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY lc_tarefas_read ON public.lifecycle_tarefas FOR SELECT USING (public.is_any_authenticated());


--
-- Name: lifecycle_tarefas lc_tarefas_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY lc_tarefas_write ON public.lifecycle_tarefas TO authenticated USING (public.has_responsibility('lifecycle'::text, ARRAY['admin'::text, 'quality'::text])) WITH CHECK (public.has_responsibility('lifecycle'::text, ARRAY['admin'::text, 'quality'::text]));


--
-- Name: lifecycle_vagas lc_vagas_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY lc_vagas_read ON public.lifecycle_vagas FOR SELECT USING (public.is_any_authenticated());


--
-- Name: lifecycle_vagas lc_vagas_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY lc_vagas_write ON public.lifecycle_vagas TO authenticated USING (public.has_responsibility('lifecycle'::text, ARRAY['admin'::text, 'quality'::text])) WITH CHECK (public.has_responsibility('lifecycle'::text, ARRAY['admin'::text, 'quality'::text]));


--
-- Name: lifecycle_cv_jobs lcj_read_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY lcj_read_authenticated ON public.lifecycle_cv_jobs FOR SELECT USING (public.is_any_authenticated());


--
-- Name: lifecycle_cv_jobs lcj_write_owner; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY lcj_write_owner ON public.lifecycle_cv_jobs USING (public.is_any_authenticated()) WITH CHECK (((user_id = auth.uid()) OR (public.has_responsibility('lifecycle'::text, ARRAY['admin'::text, 'quality'::text]) OR public.has_responsibility('lifecycle'::text, ARRAY['management'::text]))));


--
-- Name: lifecycle_avaliacoes liceav_read_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY liceav_read_authenticated ON public.lifecycle_avaliacoes FOR SELECT USING (public.is_any_authenticated());


--
-- Name: lifecycle_avaliacoes liceav_write_manage; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY liceav_write_manage ON public.lifecycle_avaliacoes USING ((public.has_responsibility('lifecycle'::text, ARRAY['admin'::text, 'quality'::text]) OR public.has_responsibility('lifecycle'::text, ARRAY['management'::text]))) WITH CHECK ((public.has_responsibility('lifecycle'::text, ARRAY['admin'::text, 'quality'::text]) OR public.has_responsibility('lifecycle'::text, ARRAY['management'::text])));


--
-- Name: lifecycle_entrevistas liceent_read_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY liceent_read_authenticated ON public.lifecycle_entrevistas FOR SELECT USING (public.is_any_authenticated());


--
-- Name: lifecycle_entrevistas liceent_write_manage; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY liceent_write_manage ON public.lifecycle_entrevistas USING ((public.has_responsibility('lifecycle'::text, ARRAY['admin'::text, 'quality'::text]) OR public.has_responsibility('lifecycle'::text, ARRAY['management'::text]))) WITH CHECK ((public.has_responsibility('lifecycle'::text, ARRAY['admin'::text, 'quality'::text]) OR public.has_responsibility('lifecycle'::text, ARRAY['management'::text])));


--
-- Name: lifecycle_pessoas licpessoas_read_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY licpessoas_read_authenticated ON public.lifecycle_pessoas FOR SELECT USING (public.is_any_authenticated());


--
-- Name: lifecycle_pessoas licpessoas_write_manage; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY licpessoas_write_manage ON public.lifecycle_pessoas USING ((public.has_responsibility('lifecycle'::text, ARRAY['admin'::text, 'quality'::text]) OR public.has_responsibility('lifecycle'::text, ARRAY['management'::text]))) WITH CHECK ((public.has_responsibility('lifecycle'::text, ARRAY['admin'::text, 'quality'::text]) OR public.has_responsibility('lifecycle'::text, ARRAY['management'::text])));


--
-- Name: lifecycle_avaliacoes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.lifecycle_avaliacoes ENABLE ROW LEVEL SECURITY;

--
-- Name: lifecycle_casos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.lifecycle_casos ENABLE ROW LEVEL SECURITY;

--
-- Name: lifecycle_certificacoes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.lifecycle_certificacoes ENABLE ROW LEVEL SECURITY;

--
-- Name: lifecycle_competencias; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.lifecycle_competencias ENABLE ROW LEVEL SECURITY;

--
-- Name: lifecycle_comunicacoes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.lifecycle_comunicacoes ENABLE ROW LEVEL SECURITY;

--
-- Name: lifecycle_cv_jobs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.lifecycle_cv_jobs ENABLE ROW LEVEL SECURITY;

--
-- Name: lifecycle_entrevistas; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.lifecycle_entrevistas ENABLE ROW LEVEL SECURITY;

--
-- Name: lifecycle_experiencias; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.lifecycle_experiencias ENABLE ROW LEVEL SECURITY;

--
-- Name: lifecycle_formacoes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.lifecycle_formacoes ENABLE ROW LEVEL SECURITY;

--
-- Name: lifecycle_idiomas; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.lifecycle_idiomas ENABLE ROW LEVEL SECURITY;

--
-- Name: lifecycle_pessoas; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.lifecycle_pessoas ENABLE ROW LEVEL SECURITY;

--
-- Name: lifecycle_projetos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.lifecycle_projetos ENABLE ROW LEVEL SECURITY;

--
-- Name: lifecycle_referencias; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.lifecycle_referencias ENABLE ROW LEVEL SECURITY;

--
-- Name: lifecycle_tarefas; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.lifecycle_tarefas ENABLE ROW LEVEL SECURITY;

--
-- Name: lifecycle_vagas; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.lifecycle_vagas ENABLE ROW LEVEL SECURITY;

--
-- Name: meeting_presenters; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.meeting_presenters ENABLE ROW LEVEL SECURITY;

--
-- Name: meeting_presenters meeting_presenters_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY meeting_presenters_read ON public.meeting_presenters FOR SELECT TO authenticated USING (true);


--
-- Name: meeting_presenters meeting_presenters_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY meeting_presenters_write ON public.meeting_presenters TO authenticated USING (public.has_responsibility('strategy'::text, ARRAY['admin'::text, 'quality'::text])) WITH CHECK (public.has_responsibility('strategy'::text, ARRAY['admin'::text, 'quality'::text]));


--
-- Name: meetings; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.meetings ENABLE ROW LEVEL SECURITY;

--
-- Name: meetings meetings_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY meetings_read ON public.meetings FOR SELECT TO authenticated USING (true);


--
-- Name: meetings meetings_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY meetings_write ON public.meetings TO authenticated USING (public.has_responsibility('strategy'::text, ARRAY['admin'::text, 'quality'::text])) WITH CHECK (public.has_responsibility('strategy'::text, ARRAY['admin'::text, 'quality'::text]));


--
-- Name: organization_memberships memberships_company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY memberships_company_boundary ON public.organization_memberships AS RESTRICTIVE USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())))) WITH CHECK (public.access_admin());


--
-- Name: ai_action_logs module_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY module_boundary ON public.ai_action_logs AS RESTRICTIVE USING (public.has_module('quality'::text)) WITH CHECK (public.has_module('quality'::text));


--
-- Name: ai_interactions module_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY module_boundary ON public.ai_interactions AS RESTRICTIVE USING (public.has_module('quality'::text)) WITH CHECK (public.has_module('quality'::text));


--
-- Name: ai_pending_actions module_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY module_boundary ON public.ai_pending_actions AS RESTRICTIVE USING (public.has_module('quality'::text)) WITH CHECK (public.has_module('quality'::text));


--
-- Name: ai_query_logs module_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY module_boundary ON public.ai_query_logs AS RESTRICTIVE USING (public.has_module('quality'::text)) WITH CHECK (public.has_module('quality'::text));


--
-- Name: lifecycle_avaliacoes module_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY module_boundary ON public.lifecycle_avaliacoes AS RESTRICTIVE USING (public.has_module('lifecycle'::text)) WITH CHECK (public.has_module('lifecycle'::text));


--
-- Name: lifecycle_casos module_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY module_boundary ON public.lifecycle_casos AS RESTRICTIVE USING (public.has_module('lifecycle'::text)) WITH CHECK (public.has_module('lifecycle'::text));


--
-- Name: lifecycle_certificacoes module_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY module_boundary ON public.lifecycle_certificacoes AS RESTRICTIVE USING (public.has_module('lifecycle'::text)) WITH CHECK (public.has_module('lifecycle'::text));


--
-- Name: lifecycle_competencias module_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY module_boundary ON public.lifecycle_competencias AS RESTRICTIVE USING (public.has_module('lifecycle'::text)) WITH CHECK (public.has_module('lifecycle'::text));


--
-- Name: lifecycle_comunicacoes module_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY module_boundary ON public.lifecycle_comunicacoes AS RESTRICTIVE USING (public.has_module('lifecycle'::text)) WITH CHECK (public.has_module('lifecycle'::text));


--
-- Name: lifecycle_cv_jobs module_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY module_boundary ON public.lifecycle_cv_jobs AS RESTRICTIVE USING (public.has_module('lifecycle'::text)) WITH CHECK (public.has_module('lifecycle'::text));


--
-- Name: lifecycle_entrevistas module_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY module_boundary ON public.lifecycle_entrevistas AS RESTRICTIVE USING (public.has_module('lifecycle'::text)) WITH CHECK (public.has_module('lifecycle'::text));


--
-- Name: lifecycle_experiencias module_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY module_boundary ON public.lifecycle_experiencias AS RESTRICTIVE USING (public.has_module('lifecycle'::text)) WITH CHECK (public.has_module('lifecycle'::text));


--
-- Name: lifecycle_formacoes module_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY module_boundary ON public.lifecycle_formacoes AS RESTRICTIVE USING (public.has_module('lifecycle'::text)) WITH CHECK (public.has_module('lifecycle'::text));


--
-- Name: lifecycle_idiomas module_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY module_boundary ON public.lifecycle_idiomas AS RESTRICTIVE USING (public.has_module('lifecycle'::text)) WITH CHECK (public.has_module('lifecycle'::text));


--
-- Name: lifecycle_pessoas module_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY module_boundary ON public.lifecycle_pessoas AS RESTRICTIVE USING (public.has_module('lifecycle'::text)) WITH CHECK (public.has_module('lifecycle'::text));


--
-- Name: lifecycle_projetos module_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY module_boundary ON public.lifecycle_projetos AS RESTRICTIVE USING (public.has_module('lifecycle'::text)) WITH CHECK (public.has_module('lifecycle'::text));


--
-- Name: lifecycle_referencias module_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY module_boundary ON public.lifecycle_referencias AS RESTRICTIVE USING (public.has_module('lifecycle'::text)) WITH CHECK (public.has_module('lifecycle'::text));


--
-- Name: lifecycle_tarefas module_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY module_boundary ON public.lifecycle_tarefas AS RESTRICTIVE USING (public.has_module('lifecycle'::text)) WITH CHECK (public.has_module('lifecycle'::text));


--
-- Name: lifecycle_vagas module_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY module_boundary ON public.lifecycle_vagas AS RESTRICTIVE USING (public.has_module('lifecycle'::text)) WITH CHECK (public.has_module('lifecycle'::text));


--
-- Name: quality_action_dependencies module_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY module_boundary ON public.quality_action_dependencies AS RESTRICTIVE USING (public.has_module('quality'::text)) WITH CHECK (public.has_module('quality'::text));


--
-- Name: quality_actions module_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY module_boundary ON public.quality_actions AS RESTRICTIVE USING (public.has_module('quality'::text)) WITH CHECK (public.has_module('quality'::text));


--
-- Name: quality_areas module_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY module_boundary ON public.quality_areas AS RESTRICTIVE USING (public.has_module('quality'::text)) WITH CHECK (public.has_module('quality'::text));


--
-- Name: quality_attachments module_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY module_boundary ON public.quality_attachments AS RESTRICTIVE USING (public.has_module('quality'::text)) WITH CHECK (public.has_module('quality'::text));


--
-- Name: quality_categories module_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY module_boundary ON public.quality_categories AS RESTRICTIVE USING (public.has_module('quality'::text)) WITH CHECK (public.has_module('quality'::text));


--
-- Name: quality_comments module_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY module_boundary ON public.quality_comments AS RESTRICTIVE USING (public.has_module('quality'::text)) WITH CHECK (public.has_module('quality'::text));


--
-- Name: quality_compliance_plan_links module_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY module_boundary ON public.quality_compliance_plan_links AS RESTRICTIVE USING (public.has_module('quality'::text)) WITH CHECK (public.has_module('quality'::text));


--
-- Name: quality_compliance_plans module_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY module_boundary ON public.quality_compliance_plans AS RESTRICTIVE USING (public.has_module('quality'::text)) WITH CHECK (public.has_module('quality'::text));


--
-- Name: quality_occurrence_categories module_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY module_boundary ON public.quality_occurrence_categories AS RESTRICTIVE USING (public.has_module('quality'::text)) WITH CHECK (public.has_module('quality'::text));


--
-- Name: quality_occurrence_relations module_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY module_boundary ON public.quality_occurrence_relations AS RESTRICTIVE USING (public.has_module('quality'::text)) WITH CHECK (public.has_module('quality'::text));


--
-- Name: quality_occurrence_tags module_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY module_boundary ON public.quality_occurrence_tags AS RESTRICTIVE USING (public.has_module('quality'::text)) WITH CHECK (public.has_module('quality'::text));


--
-- Name: quality_occurrences module_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY module_boundary ON public.quality_occurrences AS RESTRICTIVE USING (public.has_module('quality'::text)) WITH CHECK (public.has_module('quality'::text));


--
-- Name: quality_origins module_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY module_boundary ON public.quality_origins AS RESTRICTIVE USING (public.has_module('quality'::text)) WITH CHECK (public.has_module('quality'::text));


--
-- Name: quality_plan_approval_events module_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY module_boundary ON public.quality_plan_approval_events AS RESTRICTIVE USING (public.has_module('quality'::text)) WITH CHECK (public.has_module('quality'::text));


--
-- Name: quality_progress_history module_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY module_boundary ON public.quality_progress_history AS RESTRICTIVE USING (public.has_module('quality'::text)) WITH CHECK (public.has_module('quality'::text));


--
-- Name: quality_tags module_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY module_boundary ON public.quality_tags AS RESTRICTIVE USING (public.has_module('quality'::text)) WITH CHECK (public.has_module('quality'::text));


--
-- Name: quality_work_logs module_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY module_boundary ON public.quality_work_logs AS RESTRICTIVE USING (public.has_module('quality'::text)) WITH CHECK (public.has_module('quality'::text));


--
-- Name: notifications; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

--
-- Name: notifications notifications_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY notifications_insert_own ON public.notifications FOR INSERT WITH CHECK ((user_id = auth.uid()));


--
-- Name: notifications notifications_read_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY notifications_read_own ON public.notifications FOR SELECT USING ((user_id = auth.uid()));


--
-- Name: notifications notifications_update_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY notifications_update_own ON public.notifications FOR UPDATE USING ((user_id = auth.uid())) WITH CHECK ((user_id = auth.uid()));


--
-- Name: quality_occurrence_categories occ_cat_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY occ_cat_read ON public.quality_occurrence_categories FOR SELECT USING (public.is_any_authenticated());


--
-- Name: quality_occurrence_categories occ_cat_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY occ_cat_write ON public.quality_occurrence_categories USING (public.is_quality_or_admin()) WITH CHECK (public.is_quality_or_admin());


--
-- Name: quality_occurrence_tags occ_tag_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY occ_tag_read ON public.quality_occurrence_tags FOR SELECT USING (public.is_any_authenticated());


--
-- Name: quality_occurrence_tags occ_tag_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY occ_tag_write ON public.quality_occurrence_tags USING (public.is_quality_or_admin()) WITH CHECK (public.is_quality_or_admin());


--
-- Name: quality_occurrences occurrences_read_as_action_owner; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY occurrences_read_as_action_owner ON public.quality_occurrences FOR SELECT USING ((public.is_any_authenticated() AND (EXISTS ( SELECT 1
   FROM public.quality_actions a
  WHERE ((a.occurrence_id = quality_occurrences.id) AND (a.responsible_user_id = auth.uid()))))));


--
-- Name: quality_occurrences occurrences_read_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY occurrences_read_authenticated ON public.quality_occurrences FOR SELECT USING ((public.is_any_authenticated() AND (public.is_quality_or_admin() OR public.is_management() OR (responsible_user_id = auth.uid()))));


--
-- Name: quality_occurrences occurrences_write_quality; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY occurrences_write_quality ON public.quality_occurrences USING (public.is_quality_or_admin()) WITH CHECK (public.is_quality_or_admin());


--
-- Name: organization_memberships; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.organization_memberships ENABLE ROW LEVEL SECURITY;

--
-- Name: organization_memberships organization_memberships_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY organization_memberships_read ON public.organization_memberships FOR SELECT TO authenticated USING (true);


--
-- Name: organization_memberships organization_memberships_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY organization_memberships_write ON public.organization_memberships TO authenticated USING (public.is_quality_or_admin()) WITH CHECK (public.is_quality_or_admin());


--
-- Name: organizations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;

--
-- Name: organizations organizations_company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY organizations_company_boundary ON public.organizations AS RESTRICTIVE USING ((public.session_valid() AND (public.access_admin() OR (id = public.my_organization())))) WITH CHECK (public.access_admin());


--
-- Name: organizations organizations_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY organizations_read ON public.organizations FOR SELECT TO authenticated USING (true);


--
-- Name: organizations organizations_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY organizations_write ON public.organizations TO authenticated USING (public.is_quality_or_admin()) WITH CHECK (public.is_quality_or_admin());


--
-- Name: quality_origins origins_read_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY origins_read_authenticated ON public.quality_origins FOR SELECT USING (public.is_any_authenticated());


--
-- Name: quality_origins origins_write_quality_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY origins_write_quality_admin ON public.quality_origins USING (public.is_quality_or_admin()) WITH CHECK (public.is_quality_or_admin());


--
-- Name: ai_pending_actions pend_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pend_admin ON public.ai_pending_actions USING (public.is_admin_user(auth.uid())) WITH CHECK (public.is_admin_user(auth.uid()));


--
-- Name: ai_pending_actions pend_self; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pend_self ON public.ai_pending_actions USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: quality_plan_approval_events plan_approval_events_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY plan_approval_events_insert ON public.quality_plan_approval_events FOR INSERT WITH CHECK ((auth.uid() IS NOT NULL));


--
-- Name: quality_plan_approval_events plan_approval_events_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY plan_approval_events_select ON public.quality_plan_approval_events FOR SELECT USING (true);


--
-- Name: platform_admin_history; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.platform_admin_history ENABLE ROW LEVEL SECURITY;

--
-- Name: ppt_layouts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ppt_layouts ENABLE ROW LEVEL SECURITY;

--
-- Name: ppt_layouts ppt_layouts_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ppt_layouts_read ON public.ppt_layouts FOR SELECT TO authenticated USING (true);


--
-- Name: ppt_layouts ppt_layouts_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ppt_layouts_write ON public.ppt_layouts TO authenticated USING (public.is_quality_or_admin()) WITH CHECK (public.is_quality_or_admin());


--
-- Name: ppt_templates; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ppt_templates ENABLE ROW LEVEL SECURITY;

--
-- Name: ppt_templates ppt_templates_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ppt_templates_read ON public.ppt_templates FOR SELECT TO authenticated USING (true);


--
-- Name: ppt_templates ppt_templates_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ppt_templates_write ON public.ppt_templates TO authenticated USING (public.has_responsibility('strategy'::text, ARRAY['admin'::text, 'quality'::text])) WITH CHECK (public.has_responsibility('strategy'::text, ARRAY['admin'::text, 'quality'::text]));


--
-- Name: profiles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

--
-- Name: profiles profiles_company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY profiles_company_boundary ON public.profiles AS RESTRICTIVE USING ((public.session_valid() AND (public.access_admin() OR ((NOT is_super_admin) AND (organization_id = public.my_organization()))))) WITH CHECK ((public.session_valid() AND (public.access_admin() OR ((id = auth.uid()) AND (organization_id = public.my_organization())))));


--
-- Name: profiles profiles_insert_quality_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY profiles_insert_quality_admin ON public.profiles FOR INSERT WITH CHECK (public.is_quality_or_admin());


--
-- Name: profiles profiles_read_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY profiles_read_authenticated ON public.profiles FOR SELECT USING (public.is_any_authenticated());


--
-- Name: profiles profiles_write_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY profiles_write_own ON public.profiles FOR UPDATE USING ((auth.uid() = id)) WITH CHECK ((auth.uid() = id));


--
-- Name: profiles profiles_write_quality_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY profiles_write_quality_admin ON public.profiles FOR UPDATE USING (public.is_quality_or_admin()) WITH CHECK (public.is_quality_or_admin());


--
-- Name: projects; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;

--
-- Name: projects projects_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY projects_read ON public.projects FOR SELECT TO authenticated USING (true);


--
-- Name: projects projects_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY projects_write ON public.projects TO authenticated USING (public.is_quality_or_admin()) WITH CHECK (public.is_quality_or_admin());


--
-- Name: quality_action_dependencies; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.quality_action_dependencies ENABLE ROW LEVEL SECURITY;

--
-- Name: quality_actions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.quality_actions ENABLE ROW LEVEL SECURITY;

--
-- Name: quality_approval_decisions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.quality_approval_decisions ENABLE ROW LEVEL SECURITY;

--
-- Name: quality_areas; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.quality_areas ENABLE ROW LEVEL SECURITY;

--
-- Name: quality_attachments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.quality_attachments ENABLE ROW LEVEL SECURITY;

--
-- Name: quality_audit_scope; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.quality_audit_scope ENABLE ROW LEVEL SECURITY;

--
-- Name: quality_auditors; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.quality_auditors ENABLE ROW LEVEL SECURITY;

--
-- Name: quality_audits; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.quality_audits ENABLE ROW LEVEL SECURITY;

--
-- Name: quality_catalogs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.quality_catalogs ENABLE ROW LEVEL SECURITY;

--
-- Name: quality_categories; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.quality_categories ENABLE ROW LEVEL SECURITY;

--
-- Name: quality_comments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.quality_comments ENABLE ROW LEVEL SECURITY;

--
-- Name: quality_compliance_plan_links; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.quality_compliance_plan_links ENABLE ROW LEVEL SECURITY;

--
-- Name: quality_compliance_plans; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.quality_compliance_plans ENABLE ROW LEVEL SECURITY;

--
-- Name: quality_deadline_changes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.quality_deadline_changes ENABLE ROW LEVEL SECURITY;

--
-- Name: quality_effectiveness_reviews; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.quality_effectiveness_reviews ENABLE ROW LEVEL SECURITY;

--
-- Name: quality_external_responses; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.quality_external_responses ENABLE ROW LEVEL SECURITY;

--
-- Name: quality_findings; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.quality_findings ENABLE ROW LEVEL SECURITY;

--
-- Name: quality_occurrence_categories; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.quality_occurrence_categories ENABLE ROW LEVEL SECURITY;

--
-- Name: quality_occurrence_relations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.quality_occurrence_relations ENABLE ROW LEVEL SECURITY;

--
-- Name: quality_occurrence_tags; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.quality_occurrence_tags ENABLE ROW LEVEL SECURITY;

--
-- Name: quality_occurrences; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.quality_occurrences ENABLE ROW LEVEL SECURITY;

--
-- Name: quality_origins; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.quality_origins ENABLE ROW LEVEL SECURITY;

--
-- Name: quality_outbox; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.quality_outbox ENABLE ROW LEVEL SECURITY;

--
-- Name: quality_plan_approval_events; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.quality_plan_approval_events ENABLE ROW LEVEL SECURITY;

--
-- Name: quality_progress_history; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.quality_progress_history ENABLE ROW LEVEL SECURITY;

--
-- Name: quality_settings; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.quality_settings ENABLE ROW LEVEL SECURITY;

--
-- Name: quality_tags; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.quality_tags ENABLE ROW LEVEL SECURITY;

--
-- Name: quality_work_logs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.quality_work_logs ENABLE ROW LEVEL SECURITY;

--
-- Name: risk_opportunities; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.risk_opportunities ENABLE ROW LEVEL SECURITY;

--
-- Name: risk_opportunities risk_opportunities_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY risk_opportunities_read ON public.risk_opportunities FOR SELECT TO authenticated USING (true);


--
-- Name: risk_opportunities risk_opportunities_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY risk_opportunities_write ON public.risk_opportunities TO authenticated USING (public.has_responsibility('strategy'::text, ARRAY['admin'::text, 'quality'::text])) WITH CHECK (public.has_responsibility('strategy'::text, ARRAY['admin'::text, 'quality'::text]));


--
-- Name: roles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;

--
-- Name: roles roles_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY roles_read ON public.roles FOR SELECT TO authenticated USING (true);


--
-- Name: roles roles_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY roles_write ON public.roles TO authenticated USING (public.is_quality_or_admin()) WITH CHECK (public.is_quality_or_admin());


--
-- Name: quality_audit_scope scope_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY scope_read ON public.quality_audit_scope FOR SELECT TO authenticated USING ((public.session_valid() AND public.has_module('quality'::text) AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: app_settings settings_delete_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_delete_boundary ON public.app_settings AS RESTRICTIVE FOR DELETE USING (public.access_admin());


--
-- Name: app_settings settings_insert_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_insert_boundary ON public.app_settings AS RESTRICTIVE FOR INSERT WITH CHECK (public.access_admin());


--
-- Name: app_settings settings_read_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_read_boundary ON public.app_settings AS RESTRICTIVE FOR SELECT USING (public.session_valid());


--
-- Name: app_settings settings_update_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_update_boundary ON public.app_settings AS RESTRICTIVE FOR UPDATE USING (public.access_admin()) WITH CHECK (public.access_admin());


--
-- Name: brand_kits shared_company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY shared_company_boundary ON public.brand_kits AS RESTRICTIVE USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())))) WITH CHECK (public.access_admin());


--
-- Name: roles shared_company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY shared_company_boundary ON public.roles AS RESTRICTIVE USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())))) WITH CHECK (public.access_admin());


--
-- Name: teams shared_company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY shared_company_boundary ON public.teams AS RESTRICTIVE USING ((public.session_valid() AND (public.access_admin() OR (organization_id = public.my_organization())))) WITH CHECK (public.access_admin());


--
-- Name: strategic_actions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.strategic_actions ENABLE ROW LEVEL SECURITY;

--
-- Name: strategic_actions strategic_actions_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY strategic_actions_read ON public.strategic_actions FOR SELECT TO authenticated USING (true);


--
-- Name: strategic_actions strategic_actions_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY strategic_actions_write ON public.strategic_actions TO authenticated USING (public.has_responsibility('strategy'::text, ARRAY['admin'::text, 'quality'::text])) WITH CHECK (public.has_responsibility('strategy'::text, ARRAY['admin'::text, 'quality'::text]));


--
-- Name: strategic_objectives; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.strategic_objectives ENABLE ROW LEVEL SECURITY;

--
-- Name: strategic_objectives strategic_objectives_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY strategic_objectives_read ON public.strategic_objectives FOR SELECT TO authenticated USING (true);


--
-- Name: strategic_objectives strategic_objectives_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY strategic_objectives_write ON public.strategic_objectives TO authenticated USING (public.has_responsibility('strategy'::text, ARRAY['admin'::text, 'quality'::text])) WITH CHECK (public.has_responsibility('strategy'::text, ARRAY['admin'::text, 'quality'::text]));


--
-- Name: strategy_area_teams; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.strategy_area_teams ENABLE ROW LEVEL SECURITY;

--
-- Name: archive_locations strategy_company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY strategy_company_boundary ON public.archive_locations AS RESTRICTIVE USING (public.can_strategy_record('archive_locations'::text, to_jsonb(archive_locations.*))) WITH CHECK (public.can_strategy_record('archive_locations'::text, to_jsonb(archive_locations.*)));


--
-- Name: connector_instances strategy_company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY strategy_company_boundary ON public.connector_instances AS RESTRICTIVE USING (public.can_strategy_record('connector_instances'::text, to_jsonb(connector_instances.*))) WITH CHECK (public.can_strategy_record('connector_instances'::text, to_jsonb(connector_instances.*)));


--
-- Name: connectors strategy_company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY strategy_company_boundary ON public.connectors AS RESTRICTIVE USING (public.can_strategy_record('connectors'::text, to_jsonb(connectors.*))) WITH CHECK (public.can_strategy_record('connectors'::text, to_jsonb(connectors.*)));


--
-- Name: cycles strategy_company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY strategy_company_boundary ON public.cycles AS RESTRICTIVE USING (public.can_strategy_record('cycles'::text, to_jsonb(cycles.*))) WITH CHECK (public.can_strategy_record('cycles'::text, to_jsonb(cycles.*)));


--
-- Name: decisions strategy_company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY strategy_company_boundary ON public.decisions AS RESTRICTIVE USING (public.can_strategy_record('decisions'::text, to_jsonb(decisions.*))) WITH CHECK (public.can_strategy_record('decisions'::text, to_jsonb(decisions.*)));


--
-- Name: effectiveness_evaluations strategy_company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY strategy_company_boundary ON public.effectiveness_evaluations AS RESTRICTIVE USING (public.can_strategy_record('effectiveness_evaluations'::text, to_jsonb(effectiveness_evaluations.*))) WITH CHECK (public.can_strategy_record('effectiveness_evaluations'::text, to_jsonb(effectiveness_evaluations.*)));


--
-- Name: evidences strategy_company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY strategy_company_boundary ON public.evidences AS RESTRICTIVE USING (public.can_strategy_record('evidences'::text, to_jsonb(evidences.*))) WITH CHECK (public.can_strategy_record('evidences'::text, to_jsonb(evidences.*)));


--
-- Name: frameworks strategy_company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY strategy_company_boundary ON public.frameworks AS RESTRICTIVE USING (public.can_strategy_record('frameworks'::text, to_jsonb(frameworks.*))) WITH CHECK (public.can_strategy_record('frameworks'::text, to_jsonb(frameworks.*)));


--
-- Name: generated_files strategy_company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY strategy_company_boundary ON public.generated_files AS RESTRICTIVE USING (public.can_strategy_record('generated_files'::text, to_jsonb(generated_files.*))) WITH CHECK (public.can_strategy_record('generated_files'::text, to_jsonb(generated_files.*)));


--
-- Name: kpi_results strategy_company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY strategy_company_boundary ON public.kpi_results AS RESTRICTIVE USING (public.can_strategy_record('kpi_results'::text, to_jsonb(kpi_results.*))) WITH CHECK (public.can_strategy_record('kpi_results'::text, to_jsonb(kpi_results.*)));


--
-- Name: kpi_targets strategy_company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY strategy_company_boundary ON public.kpi_targets AS RESTRICTIVE USING (public.can_strategy_record('kpi_targets'::text, to_jsonb(kpi_targets.*))) WITH CHECK (public.can_strategy_record('kpi_targets'::text, to_jsonb(kpi_targets.*)));


--
-- Name: kpis strategy_company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY strategy_company_boundary ON public.kpis AS RESTRICTIVE USING (public.can_strategy_record('kpis'::text, to_jsonb(kpis.*))) WITH CHECK (public.can_strategy_record('kpis'::text, to_jsonb(kpis.*)));


--
-- Name: meeting_presenters strategy_company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY strategy_company_boundary ON public.meeting_presenters AS RESTRICTIVE USING (public.can_strategy_record('meeting_presenters'::text, to_jsonb(meeting_presenters.*))) WITH CHECK (public.can_strategy_record('meeting_presenters'::text, to_jsonb(meeting_presenters.*)));


--
-- Name: meetings strategy_company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY strategy_company_boundary ON public.meetings AS RESTRICTIVE USING (public.can_strategy_record('meetings'::text, to_jsonb(meetings.*))) WITH CHECK (public.can_strategy_record('meetings'::text, to_jsonb(meetings.*)));


--
-- Name: ppt_layouts strategy_company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY strategy_company_boundary ON public.ppt_layouts AS RESTRICTIVE USING (public.can_strategy_record('ppt_layouts'::text, to_jsonb(ppt_layouts.*))) WITH CHECK (public.can_strategy_record('ppt_layouts'::text, to_jsonb(ppt_layouts.*)));


--
-- Name: ppt_templates strategy_company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY strategy_company_boundary ON public.ppt_templates AS RESTRICTIVE USING (public.can_strategy_record('ppt_templates'::text, to_jsonb(ppt_templates.*))) WITH CHECK (public.can_strategy_record('ppt_templates'::text, to_jsonb(ppt_templates.*)));


--
-- Name: projects strategy_company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY strategy_company_boundary ON public.projects AS RESTRICTIVE USING (public.can_strategy_record('projects'::text, to_jsonb(projects.*))) WITH CHECK (public.can_strategy_record('projects'::text, to_jsonb(projects.*)));


--
-- Name: risk_opportunities strategy_company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY strategy_company_boundary ON public.risk_opportunities AS RESTRICTIVE USING (public.can_strategy_record('risk_opportunities'::text, to_jsonb(risk_opportunities.*))) WITH CHECK (public.can_strategy_record('risk_opportunities'::text, to_jsonb(risk_opportunities.*)));


--
-- Name: strategic_actions strategy_company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY strategy_company_boundary ON public.strategic_actions AS RESTRICTIVE USING (public.can_strategy_record('strategic_actions'::text, to_jsonb(strategic_actions.*))) WITH CHECK (public.can_strategy_record('strategic_actions'::text, to_jsonb(strategic_actions.*)));


--
-- Name: strategic_objectives strategy_company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY strategy_company_boundary ON public.strategic_objectives AS RESTRICTIVE USING (public.can_strategy_record('strategic_objectives'::text, to_jsonb(strategic_objectives.*))) WITH CHECK (public.can_strategy_record('strategic_objectives'::text, to_jsonb(strategic_objectives.*)));


--
-- Name: submissions strategy_company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY strategy_company_boundary ON public.submissions AS RESTRICTIVE USING (public.can_strategy_record('submissions'::text, to_jsonb(submissions.*))) WITH CHECK (public.can_strategy_record('submissions'::text, to_jsonb(submissions.*)));


--
-- Name: swot_campaigns strategy_company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY strategy_company_boundary ON public.swot_campaigns AS RESTRICTIVE USING (public.can_strategy_record('swot_campaigns'::text, to_jsonb(swot_campaigns.*))) WITH CHECK (public.can_strategy_record('swot_campaigns'::text, to_jsonb(swot_campaigns.*)));


--
-- Name: swot_contributions strategy_company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY strategy_company_boundary ON public.swot_contributions AS RESTRICTIVE USING (public.can_strategy_record('swot_contributions'::text, to_jsonb(swot_contributions.*))) WITH CHECK (public.can_strategy_record('swot_contributions'::text, to_jsonb(swot_contributions.*)));


--
-- Name: swot_items strategy_company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY strategy_company_boundary ON public.swot_items AS RESTRICTIVE USING (public.can_strategy_record('swot_items'::text, to_jsonb(swot_items.*))) WITH CHECK (public.can_strategy_record('swot_items'::text, to_jsonb(swot_items.*)));


--
-- Name: tows_crossings strategy_company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY strategy_company_boundary ON public.tows_crossings AS RESTRICTIVE USING (public.can_strategy_record('tows_crossings'::text, to_jsonb(tows_crossings.*))) WITH CHECK (public.can_strategy_record('tows_crossings'::text, to_jsonb(tows_crossings.*)));


--
-- Name: strategy_history; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.strategy_history ENABLE ROW LEVEL SECURITY;

--
-- Name: strategy_history strategy_history_company_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY strategy_history_company_boundary ON public.strategy_history AS RESTRICTIVE FOR SELECT USING ((public.access_admin() OR public.can_strategy_record(table_name, COALESCE(after_data, before_data))));


--
-- Name: strategy_history strategy_history_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY strategy_history_read ON public.strategy_history FOR SELECT TO authenticated USING (public.has_responsibility('strategy'::text, ARRAY['admin'::text, 'quality'::text]));


--
-- Name: strategy_thematic_areas; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.strategy_thematic_areas ENABLE ROW LEVEL SECURITY;

--
-- Name: submissions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.submissions ENABLE ROW LEVEL SECURITY;

--
-- Name: submissions submissions_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY submissions_read ON public.submissions FOR SELECT TO authenticated USING (true);


--
-- Name: submissions submissions_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY submissions_write ON public.submissions TO authenticated USING (public.is_quality_or_admin()) WITH CHECK (public.is_quality_or_admin());


--
-- Name: swot_campaign_audience; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.swot_campaign_audience ENABLE ROW LEVEL SECURITY;

--
-- Name: swot_campaign_validators; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.swot_campaign_validators ENABLE ROW LEVEL SECURITY;

--
-- Name: swot_campaigns; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.swot_campaigns ENABLE ROW LEVEL SECURITY;

--
-- Name: swot_campaigns swot_campaigns_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY swot_campaigns_read ON public.swot_campaigns FOR SELECT TO authenticated USING (true);


--
-- Name: swot_campaigns swot_campaigns_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY swot_campaigns_write ON public.swot_campaigns TO authenticated USING (public.has_responsibility('strategy'::text, ARRAY['admin'::text, 'quality'::text])) WITH CHECK (public.has_responsibility('strategy'::text, ARRAY['admin'::text, 'quality'::text]));


--
-- Name: swot_context_reviews; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.swot_context_reviews ENABLE ROW LEVEL SECURITY;

--
-- Name: swot_contributions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.swot_contributions ENABLE ROW LEVEL SECURITY;

--
-- Name: swot_contributions swot_contributions_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY swot_contributions_read ON public.swot_contributions FOR SELECT TO authenticated USING (true);


--
-- Name: swot_contributions swot_contributions_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY swot_contributions_write ON public.swot_contributions TO authenticated USING (public.has_responsibility('strategy'::text, ARRAY['admin'::text, 'quality'::text])) WITH CHECK (public.has_responsibility('strategy'::text, ARRAY['admin'::text, 'quality'::text]));


--
-- Name: swot_items; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.swot_items ENABLE ROW LEVEL SECURITY;

--
-- Name: swot_items swot_items_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY swot_items_read ON public.swot_items FOR SELECT TO authenticated USING (true);


--
-- Name: swot_items swot_items_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY swot_items_write ON public.swot_items TO authenticated USING (public.has_responsibility('strategy'::text, ARRAY['admin'::text, 'quality'::text])) WITH CHECK (public.has_responsibility('strategy'::text, ARRAY['admin'::text, 'quality'::text]));


--
-- Name: swot_participant_contexts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.swot_participant_contexts ENABLE ROW LEVEL SECURITY;

--
-- Name: swot_proposals; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.swot_proposals ENABLE ROW LEVEL SECURITY;

--
-- Name: swot_submissions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.swot_submissions ENABLE ROW LEVEL SECURITY;

--
-- Name: quality_tags tags_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tags_read ON public.quality_tags FOR SELECT USING (public.is_any_authenticated());


--
-- Name: quality_tags tags_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tags_write ON public.quality_tags USING (public.is_quality_or_admin()) WITH CHECK (public.is_quality_or_admin());


--
-- Name: teams; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.teams ENABLE ROW LEVEL SECURITY;

--
-- Name: teams teams_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY teams_read ON public.teams FOR SELECT TO authenticated USING (true);


--
-- Name: teams teams_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY teams_write ON public.teams TO authenticated USING (public.is_quality_or_admin()) WITH CHECK (public.is_quality_or_admin());


--
-- Name: tows_crossings; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.tows_crossings ENABLE ROW LEVEL SECURITY;

--
-- Name: tows_crossings tows_crossings_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tows_crossings_read ON public.tows_crossings FOR SELECT TO authenticated USING (true);


--
-- Name: tows_crossings tows_crossings_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tows_crossings_write ON public.tows_crossings TO authenticated USING (public.has_responsibility('strategy'::text, ARRAY['admin'::text, 'quality'::text])) WITH CHECK (public.has_responsibility('strategy'::text, ARRAY['admin'::text, 'quality'::text]));


--
-- Name: user_access_history; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_access_history ENABLE ROW LEVEL SECURITY;

--
-- Name: user_assignments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_assignments ENABLE ROW LEVEL SECURITY;

--
-- Name: notifications v25_notification_boundary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY v25_notification_boundary ON public.notifications AS RESTRICTIVE TO authenticated USING ((public.session_valid() AND public.has_module('quality'::text) AND (public.access_admin() OR (organization_id = public.my_organization())))) WITH CHECK ((public.session_valid() AND public.has_module('quality'::text) AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: quality_approval_decisions v25_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY v25_read ON public.quality_approval_decisions FOR SELECT TO authenticated USING ((public.session_valid() AND public.has_module('quality'::text) AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: quality_audits v25_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY v25_read ON public.quality_audits FOR SELECT TO authenticated USING ((public.session_valid() AND public.has_module('quality'::text) AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: quality_catalogs v25_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY v25_read ON public.quality_catalogs FOR SELECT TO authenticated USING ((public.session_valid() AND public.has_module('quality'::text) AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: quality_deadline_changes v25_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY v25_read ON public.quality_deadline_changes FOR SELECT TO authenticated USING ((public.session_valid() AND public.has_module('quality'::text) AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: quality_effectiveness_reviews v25_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY v25_read ON public.quality_effectiveness_reviews FOR SELECT TO authenticated USING ((public.session_valid() AND public.has_module('quality'::text) AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: quality_external_responses v25_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY v25_read ON public.quality_external_responses FOR SELECT TO authenticated USING ((public.session_valid() AND public.has_module('quality'::text) AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: quality_findings v25_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY v25_read ON public.quality_findings FOR SELECT TO authenticated USING ((public.session_valid() AND public.has_module('quality'::text) AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: quality_outbox v25_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY v25_read ON public.quality_outbox FOR SELECT TO authenticated USING ((public.session_valid() AND public.has_module('quality'::text) AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- Name: quality_settings v25_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY v25_read ON public.quality_settings FOR SELECT TO authenticated USING ((public.session_valid() AND public.has_module('quality'::text) AND (public.access_admin() OR (organization_id = public.my_organization()))));


--
-- PostgreSQL database dump complete
--

\unrestrict kExQtnl0C24c41r7dNklXr1AcOIu68AckFduVFw649txACWjIuLJQVJsnYbEYil

