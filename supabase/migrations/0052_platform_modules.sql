BEGIN;
ALTER TABLE public.meeting_presenters ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE public.meeting_presenters ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE public.ppt_templates ADD COLUMN IF NOT EXISTS include_cover boolean NOT NULL DEFAULT true;
ALTER TABLE public.ppt_templates ADD COLUMN IF NOT EXISTS sections text[] NOT NULL DEFAULT ARRAY['meeting','swot','tows','risks','objectives','actions','kpis','decisions'];
ALTER TABLE public.ppt_templates ADD COLUMN IF NOT EXISTS body_font_size integer NOT NULL DEFAULT 18;
ALTER TABLE public.ppt_templates ADD COLUMN IF NOT EXISTS lines_per_slide integer NOT NULL DEFAULT 10;
CREATE OR REPLACE FUNCTION public.platform_module_write(p_table text,p_payload jsonb,p_id uuid DEFAULT NULL,p_expected_updated_at timestamptz DEFAULT NULL,p_human_confirmed boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE actor uuid:=auth.uid(); before_row jsonb; after_row jsonb; merged jsonb; allowed text[]; bad text; fields text; vals text; assignments text; org uuid; other jsonb; old_status text; new_status text;
BEGIN
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
END $$;
REVOKE ALL ON FUNCTION public.platform_module_write(text,jsonb,uuid,timestamptz,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.platform_module_write(text,jsonb,uuid,timestamptz,boolean) TO authenticated;
REVOKE INSERT,UPDATE,DELETE ON public.organizations,public.teams,public.organization_memberships,public.brand_kits,public.frameworks,public.cycles,public.meetings,public.meeting_presenters,public.decisions,public.ppt_templates,public.connectors FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.platform_module_timestamp() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN NEW.updated_at:=clock_timestamp(); RETURN NEW; END $$;
DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['organizations','teams','organization_memberships','brand_kits','frameworks','cycles','meetings','meeting_presenters','decisions','ppt_templates','connectors'] LOOP
  EXECUTE format('CREATE OR REPLACE TRIGGER zz_platform_timestamp BEFORE UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.platform_module_timestamp()',t);
 END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.import_kpi_csv(p_connector_id uuid,p_rows jsonb,p_human_confirmed boolean DEFAULT false)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE conn public.connectors; item jsonb; k public.kpis; existing public.kpi_results; n integer:=0;
BEGIN
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
END $$;
REVOKE ALL ON FUNCTION public.import_kpi_csv(uuid,jsonb,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.import_kpi_csv(uuid,jsonb,boolean) TO authenticated;

NOTIFY pgrst,'reload schema';
COMMIT;