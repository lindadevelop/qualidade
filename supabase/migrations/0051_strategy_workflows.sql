-- Reviewed strategic writes, history, traceability and domain validation.
BEGIN;
ALTER TABLE public.risk_opportunities ADD COLUMN IF NOT EXISTS source_tows_id uuid REFERENCES public.tows_crossings(id) ON DELETE RESTRICT;
ALTER TABLE public.strategic_objectives ADD COLUMN IF NOT EXISTS risk_ids uuid[] NOT NULL DEFAULT '{}';
ALTER TABLE public.tows_crossings ADD COLUMN IF NOT EXISTS disposition text NOT NULL DEFAULT 'monitor' CHECK (disposition IN ('monitor','not_relevant','risk','opportunity'));

CREATE TABLE IF NOT EXISTS public.strategy_history (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), table_name text NOT NULL, record_id uuid NOT NULL,
 operation text NOT NULL, before_data jsonb, after_data jsonb,
 reviewed_by uuid NOT NULL REFERENCES public.profiles(id), reviewed_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
ALTER TABLE public.strategy_history ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS strategy_history_read ON public.strategy_history;
CREATE POLICY strategy_history_read ON public.strategy_history FOR SELECT TO authenticated USING (public.is_quality_or_admin());
GRANT SELECT ON public.strategy_history TO authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.strategy_history FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.validate_strategy_record() RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
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
END $$;

-- Existing API clients cannot bypass the reviewed write operation. Authenticated
-- quality/admin users explicitly confirm each write; this is not an AI endpoint.
CREATE OR REPLACE FUNCTION public.strategy_write(p_table text, p_operation text, p_payload jsonb DEFAULT '{}', p_id uuid DEFAULT NULL, p_expected_updated_at timestamptz DEFAULT NULL, p_human_confirmed boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE actor uuid := auth.uid(); before_row jsonb; after_row jsonb; fields text; vals text; assignments text; allowed text[]; bad text;
BEGIN
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
END $$;
REVOKE ALL ON FUNCTION public.strategy_write(text,text,jsonb,uuid,timestamptz,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.strategy_write(text,text,jsonb,uuid,timestamptz,boolean) TO authenticated;
DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['swot_items','tows_crossings','risk_opportunities','strategic_objectives','strategic_actions','kpis','kpi_targets','kpi_results'] LOOP
  EXECUTE format('DROP TRIGGER IF EXISTS strategy_validate ON public.%I',t);
  EXECUTE format('CREATE TRIGGER strategy_validate BEFORE INSERT OR UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.validate_strategy_record()',t);
  EXECUTE format('REVOKE INSERT,UPDATE,DELETE ON public.%I FROM PUBLIC,anon,authenticated',t);
 END LOOP;
END $$;
NOTIFY pgrst, 'reload schema';
COMMIT;

