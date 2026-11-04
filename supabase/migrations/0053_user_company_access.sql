BEGIN;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_super_admin boolean NOT NULL DEFAULT false;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS organization_id uuid REFERENCES public.organizations(id);
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS module_access jsonb NOT NULL DEFAULT '{"quality":true,"strategy":true,"lifecycle":true}';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS session_version integer NOT NULL DEFAULT 0;
UPDATE public.profiles SET organization_id=(SELECT id FROM public.organizations WHERE name ILIKE 'Samsys%' ORDER BY created_at LIMIT 1) WHERE organization_id IS NULL;
INSERT INTO organization_memberships(organization_id,user_id,role,active) SELECT organization_id,id,'member',active FROM profiles WHERE organization_id IS NOT NULL ON CONFLICT(organization_id,user_id) DO NOTHING;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_modules_valid CHECK (jsonb_typeof(module_access)='object' AND module_access ?& ARRAY['quality','strategy','lifecycle'] AND jsonb_typeof(module_access->'quality')='boolean' AND jsonb_typeof(module_access->'strategy')='boolean' AND jsonb_typeof(module_access->'lifecycle')='boolean');
CREATE TABLE public.user_access_history (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES public.profiles(id), actor_id uuid NOT NULL REFERENCES public.profiles(id),
 before_data jsonb,after_data jsonb,password_changed boolean NOT NULL DEFAULT false,created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
ALTER TABLE public.user_access_history ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.user_access_history FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.session_valid() RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT EXISTS(SELECT 1 FROM profiles p WHERE p.id=auth.uid() AND p.active AND p.session_version=coalesce(nullif(current_setting('request.jwt.claims',true),'')::jsonb->>'sv','0')::integer)
$$;
CREATE OR REPLACE FUNCTION public.access_admin() RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT public.session_valid() AND EXISTS(SELECT 1 FROM profiles WHERE id=auth.uid() AND is_super_admin)
$$;
CREATE OR REPLACE FUNCTION public.my_organization() RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT organization_id FROM profiles WHERE id=auth.uid() AND public.session_valid()
$$;
CREATE OR REPLACE FUNCTION public.has_module(p_module text) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT public.session_valid() AND EXISTS(SELECT 1 FROM profiles p WHERE p.id=auth.uid() AND (p.role='admin' OR coalesce((p.module_access->>p_module)::boolean,false)))
$$;
CREATE OR REPLACE FUNCTION public.is_quality_or_admin() RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT public.session_valid() AND EXISTS(SELECT 1 FROM profiles WHERE id=auth.uid() AND role IN ('admin','quality'))
$$;
CREATE POLICY profiles_company_boundary ON public.profiles AS RESTRICTIVE FOR ALL TO PUBLIC
 USING(public.session_valid() AND (public.access_admin() OR NOT is_super_admin AND organization_id=public.my_organization()))
 WITH CHECK(public.session_valid() AND (public.access_admin() OR id=auth.uid() AND organization_id=public.my_organization()));
REVOKE INSERT,UPDATE,DELETE ON public.profiles FROM PUBLIC,anon,authenticated;

CREATE POLICY organizations_company_boundary ON public.organizations AS RESTRICTIVE FOR ALL TO PUBLIC
 USING(public.session_valid() AND (public.access_admin() OR id=public.my_organization()))
 WITH CHECK(public.access_admin());
CREATE POLICY memberships_company_boundary ON public.organization_memberships AS RESTRICTIVE FOR ALL TO PUBLIC
 USING(public.session_valid() AND (public.access_admin() OR organization_id=public.my_organization())) WITH CHECK(public.access_admin());
CREATE OR REPLACE FUNCTION public.can_strategy_record(t text,j jsonb) RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
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
DO $$ DECLARE t record; module_name text; expression text; BEGIN
 FOR t IN SELECT tablename FROM pg_tables WHERE schemaname='public' LOOP
  module_name:=CASE WHEN t.tablename LIKE 'quality_%' OR t.tablename IN ('ai_interactions','ai_query_logs','ai_action_logs','ai_pending_actions') THEN 'quality' WHEN t.tablename LIKE 'lifecycle_%' THEN 'lifecycle' ELSE NULL END;
  IF module_name IS NOT NULL THEN
   EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t.tablename);
   EXECUTE format('CREATE POLICY module_boundary ON public.%I AS RESTRICTIVE FOR ALL TO PUBLIC USING(public.has_module(%L)) WITH CHECK(public.has_module(%L))',t.tablename,module_name,module_name);
  END IF;
 END LOOP;
END $$;
DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['frameworks','cycles','swot_campaigns','swot_items','swot_contributions','tows_crossings','risk_opportunities','strategic_objectives','strategic_actions','kpis','kpi_targets','kpi_results','effectiveness_evaluations','projects','decisions','evidences','meetings','meeting_presenters','submissions','ppt_templates','ppt_layouts','generated_files','archive_locations','connectors','connector_instances'] LOOP
  EXECUTE format('CREATE POLICY strategy_company_boundary ON public.%I AS RESTRICTIVE FOR ALL TO PUBLIC USING(public.can_strategy_record(%L,to_jsonb(%I.*))) WITH CHECK(public.can_strategy_record(%L,to_jsonb(%I.*)))',t,t,t,t,t);
 END LOOP;
 FOREACH t IN ARRAY ARRAY['brand_kits','teams','roles'] LOOP
  EXECUTE format('CREATE POLICY shared_company_boundary ON public.%I AS RESTRICTIVE FOR ALL TO PUBLIC USING(public.session_valid() AND (public.access_admin() OR organization_id=public.my_organization())) WITH CHECK(public.access_admin())',t);
 END LOOP;
END $$;
CREATE POLICY strategy_history_company_boundary ON public.strategy_history AS RESTRICTIVE FOR SELECT TO PUBLIC
 USING(public.access_admin() OR public.can_strategy_record(table_name,coalesce(after_data,before_data)));
-- Aggregate queries must respect module policies instead of bypassing RLS.
ALTER FUNCTION public.get_dashboard_metrics() SECURITY INVOKER;
ALTER FUNCTION public.get_actions_by_responsible() SECURITY INVOKER;
ALTER FUNCTION public.get_occurrence_evolution(integer) SECURITY INVOKER;
ALTER FUNCTION public.get_occurrences_by_area() SECURITY INVOKER;
ALTER FUNCTION public.get_occurrences_by_origin() SECURITY INVOKER;
ALTER FUNCTION public.get_occurrences_by_status() SECURITY INVOKER;
ALTER FUNCTION public.get_urgent_actions(integer) SECURITY INVOKER;
CREATE OR REPLACE FUNCTION public.strategy_write(p_table text, p_operation text, p_payload jsonb DEFAULT '{}'::jsonb, p_id uuid DEFAULT NULL::uuid, p_expected_updated_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_human_confirmed boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE actor uuid := auth.uid(); before_row jsonb; after_row jsonb; fields text; vals text; assignments text; allowed text[]; bad text;
BEGIN
 IF NOT public.has_module('strategy') THEN RAISE EXCEPTION 'Sem acesso ao módulo Estratégia' USING ERRCODE='42501'; END IF;
 IF p_id IS NOT NULL AND p_table IN ('swot_items','tows_crossings','risk_opportunities','strategic_objectives','strategic_actions','kpis','kpi_targets','kpi_results') THEN
 EXECUTE format('SELECT to_jsonb(t) FROM public.%I t WHERE id=$1',p_table) INTO before_row USING p_id;
 IF NOT public.can_strategy_record(p_table,before_row) THEN RAISE EXCEPTION 'Registo de outra empresa' USING ERRCODE='42501'; END IF;
 ELSIF NOT public.can_strategy_record(p_table,p_payload) THEN RAISE EXCEPTION 'Empresa inválida' USING ERRCODE='42501'; END IF;

 IF actor IS NULL OR NOT public.is_quality_or_admin() THEN RAISE EXCEPTION 'Sem permissão para alterar estratégia' USING ERRCODE='42501'; END IF;
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
END $function$
;
CREATE OR REPLACE FUNCTION public.platform_module_write(p_table text, p_payload jsonb, p_id uuid DEFAULT NULL::uuid, p_expected_updated_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_human_confirmed boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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

 IF actor IS NULL OR NOT public.is_quality_or_admin() THEN RAISE EXCEPTION 'Sem permissão' USING ERRCODE='42501'; END IF;
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
END $function$
;
CREATE OR REPLACE FUNCTION public.import_kpi_csv(p_connector_id uuid, p_rows jsonb, p_human_confirmed boolean DEFAULT false)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE conn public.connectors; item jsonb; k public.kpis; existing public.kpi_results; n integer:=0;
BEGIN
 IF NOT public.has_module('strategy') OR NOT EXISTS(SELECT 1 FROM public.connectors c WHERE c.id=p_connector_id AND public.can_strategy_record('connectors',to_jsonb(c))) THEN RAISE EXCEPTION 'Sem acesso ao conector' USING ERRCODE='42501'; END IF;

 IF auth.uid() IS NULL OR NOT public.is_quality_or_admin() OR p_human_confirmed IS DISTINCT FROM true THEN RAISE EXCEPTION 'Validação humana e permissão obrigatórias' USING ERRCODE='42501'; END IF;
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
END $function$
;


-- Explicit bootstrap authorized by the owner; never exposed as an application operation.
DO $$ DECLARE n integer; BEGIN
 SELECT count(*) INTO n FROM auth.users u JOIN profiles p ON p.id=u.id WHERE lower(u.email)='geral@samsys.pt';
 IF n<>1 THEN RAISE EXCEPTION 'A conta geral@samsys.pt deve existir e ser única'; END IF;
 UPDATE profiles SET is_super_admin=true,role='admin',active=true,module_access='{"quality":true,"strategy":true,"lifecycle":true}',session_version=session_version+1 WHERE id=(SELECT id FROM auth.users WHERE lower(email)='geral@samsys.pt');
END $$;
CREATE UNIQUE INDEX one_super_administrator ON public.profiles(is_super_admin) WHERE is_super_admin;
CREATE FUNCTION public.protect_super_administrator() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP='INSERT' THEN IF NEW.is_super_admin THEN RAISE EXCEPTION 'Não é permitido criar superadministradores'; END IF; RETURN NEW; END IF;
 IF TG_OP='DELETE' THEN IF OLD.is_super_admin THEN RAISE EXCEPTION 'Superadministrador protegido'; END IF; RETURN OLD; END IF;
 IF NEW.is_super_admin IS DISTINCT FROM OLD.is_super_admin OR OLD.is_super_admin AND (NEW.role<>'admin' OR NOT NEW.active OR NEW.email IS DISTINCT FROM OLD.email OR NEW.organization_id IS DISTINCT FROM OLD.organization_id) THEN RAISE EXCEPTION 'Superadministrador protegido'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER protect_super_administrator BEFORE INSERT OR UPDATE OR DELETE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.protect_super_administrator();
CREATE FUNCTION public.protect_super_auth() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
 IF EXISTS(SELECT 1 FROM public.profiles WHERE id=OLD.id AND is_super_admin) AND (TG_OP='DELETE' OR NEW.email IS DISTINCT FROM OLD.email) THEN RAISE EXCEPTION 'Identidade do superadministrador protegida'; END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; END IF; RETURN NEW;
END $$;
CREATE TRIGGER protect_super_auth BEFORE UPDATE OR DELETE ON auth.users FOR EACH ROW EXECUTE FUNCTION public.protect_super_auth();


-- Legacy modules gain an explicit company boundary; existing records belong to Samsys.
CREATE FUNCTION public.current_company_context() RETURNS uuid LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE selected uuid; own uuid;
BEGIN
 own:=public.my_organization();
 IF auth.uid() IS NULL THEN RETURN (SELECT id FROM organizations WHERE name ILIKE 'Samsys%' ORDER BY created_at LIMIT 1); END IF;
 selected:=nullif(nullif(current_setting('request.headers',true),'')::jsonb->>'x-organization-id','')::uuid;
 IF selected IS NULL THEN RETURN own; END IF;
 IF NOT public.access_admin() AND selected IS DISTINCT FROM own THEN RAISE EXCEPTION 'Empresa não autorizada' USING ERRCODE='42501'; END IF;
 RETURN selected;
END $$;
DO $$ DECLARE t record; home uuid; BEGIN
 SELECT id INTO home FROM organizations WHERE name ILIKE 'Samsys%' ORDER BY created_at LIMIT 1;
 FOR t IN SELECT tablename FROM pg_tables WHERE schemaname='public' AND (tablename LIKE 'quality_%' OR tablename LIKE 'lifecycle_%' OR tablename IN ('audit_log','quality_progress_history','import_registry','ai_interactions','ai_query_logs','ai_action_logs','ai_pending_actions')) LOOP
  EXECUTE format('ALTER TABLE public.%I ADD COLUMN organization_id uuid REFERENCES public.organizations(id)',t.tablename);
  EXECUTE format('UPDATE public.%I SET organization_id=$1 WHERE organization_id IS NULL',t.tablename) USING home;
  EXECUTE format('ALTER TABLE public.%I ALTER COLUMN organization_id SET DEFAULT public.current_company_context(), ALTER COLUMN organization_id SET NOT NULL',t.tablename);
  EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t.tablename);
  EXECUTE format('CREATE POLICY company_boundary ON public.%I AS RESTRICTIVE FOR ALL TO PUBLIC USING(public.session_valid() AND (public.access_admin() OR organization_id=public.my_organization())) WITH CHECK(public.session_valid() AND (public.access_admin() OR organization_id=public.my_organization()))',t.tablename);
 END LOOP;
END $$;
CREATE FUNCTION public.enforce_company_links() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
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
END $$;
DO $$ DECLARE t record; BEGIN
 FOR t IN SELECT tablename FROM pg_tables WHERE schemaname='public' AND (tablename LIKE 'quality_%' OR tablename LIKE 'lifecycle_%') LOOP
  EXECUTE format('CREATE TRIGGER aa_company_links BEFORE INSERT OR UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.enforce_company_links()',t.tablename);
 END LOOP;
END $$;
ALTER FUNCTION public.cv_recover_stale_jobs(integer) SECURITY INVOKER;
CREATE POLICY settings_read_boundary ON public.app_settings AS RESTRICTIVE FOR SELECT TO PUBLIC USING(public.session_valid());
CREATE POLICY settings_insert_boundary ON public.app_settings AS RESTRICTIVE FOR INSERT TO PUBLIC WITH CHECK(public.access_admin());
CREATE POLICY settings_update_boundary ON public.app_settings AS RESTRICTIVE FOR UPDATE TO PUBLIC USING(public.access_admin()) WITH CHECK(public.access_admin());
CREATE POLICY settings_delete_boundary ON public.app_settings AS RESTRICTIVE FOR DELETE TO PUBLIC USING(public.access_admin());

NOTIFY pgrst,'reload schema';
COMMIT;
