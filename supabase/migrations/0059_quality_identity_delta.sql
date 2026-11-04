BEGIN;
CREATE TABLE quality_auditors (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid NOT NULL REFERENCES organizations(id),
 name text NOT NULL CHECK(btrim(name)<>''), kind text NOT NULL CHECK(kind IN ('INTERNAL','EXTERNAL')),
 entity text, contact text, active boolean NOT NULL DEFAULT true,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE quality_audits ADD COLUMN auditor_id uuid REFERENCES quality_auditors(id);
-- Existing auditor text/identity remains available; migrate unambiguous names only.
INSERT INTO quality_auditors(organization_id,name,kind)
 SELECT DISTINCT a.organization_id,coalesce(p.full_name,nullif(btrim(a.lead_auditor),'')),a.kind
 FROM quality_audits a LEFT JOIN profiles p ON p.id=a.lead_auditor_id
 WHERE coalesce(p.full_name,nullif(btrim(a.lead_auditor),'')) IS NOT NULL;
UPDATE quality_audits a SET auditor_id=u.id FROM quality_auditors u LEFT JOIN profiles p ON p.organization_id=u.organization_id AND p.full_name=u.name
 WHERE a.organization_id=u.organization_id AND a.kind=u.kind AND (a.lead_auditor_id=p.id OR a.lead_auditor=u.name);
ALTER TABLE profiles ADD COLUMN account_used boolean NOT NULL DEFAULT false;
-- Before this release login tracking was incomplete: preserve pre-existing identities.
UPDATE profiles SET account_used=true;
CREATE TABLE user_assignments (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid NOT NULL REFERENCES organizations(id),
 user_id uuid NOT NULL REFERENCES profiles(id), kind text NOT NULL CHECK(kind IN ('team','permission')),
 team_id uuid REFERENCES teams(id), function_name text, module text CHECK(module IN ('quality','strategy','lifecycle')),
 role text CHECK(role IN ('quality','management','action_owner')), active boolean NOT NULL DEFAULT true,
 starts_on date, ends_on date, used_at timestamptz, created_at timestamptz NOT NULL DEFAULT now(),
 CHECK(ends_on IS NULL OR starts_on IS NULL OR ends_on>=starts_on),
 CHECK((kind='team' AND team_id IS NOT NULL AND nullif(btrim(function_name),'') IS NOT NULL AND module IS NULL AND role IS NULL)
 OR (kind='permission' AND module IS NOT NULL AND role IS NOT NULL AND team_id IS NULL))
);
ALTER TABLE profiles ADD COLUMN assignments_configured boolean NOT NULL DEFAULT false;
INSERT INTO user_assignments(organization_id,user_id,kind,module,role,used_at)
 SELECT p.organization_id,p.id,'permission',m,p.role::text,now() FROM profiles p CROSS JOIN unnest(ARRAY['quality','strategy','lifecycle']) m
 WHERE p.organization_id IS NOT NULL AND p.role::text IN ('quality','management','action_owner');
UPDATE profiles SET assignments_configured=true;
ALTER TABLE user_access_history DROP CONSTRAINT user_access_history_user_id_fkey;
COMMENT ON COLUMN user_access_history.user_id IS 'Retained UUID after authorised removal of an unused account; actor remains a foreign key.';
CREATE FUNCTION effective_roles(p_user uuid,p_module text) RETURNS text[] LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT CASE WHEN p.role='admin' THEN ARRAY['admin'] WHEN NOT p.assignments_configured THEN ARRAY[p.role::text]
 ELSE coalesce((SELECT array_agg(DISTINCT a.role) FROM user_assignments a WHERE a.user_id=p.id AND a.kind='permission' AND a.module=p_module AND a.active AND (a.starts_on IS NULL OR a.starts_on<=current_date) AND (a.ends_on IS NULL OR a.ends_on>=current_date)),ARRAY[]::text[]) END
 FROM profiles p WHERE p.id=p_user
$$;
CREATE FUNCTION has_responsibility(p_module text,p_roles text[]) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT session_valid() AND has_module(p_module) AND effective_roles(auth.uid(),p_module)&&p_roles
$$;
CREATE OR REPLACE FUNCTION is_quality_or_admin() RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT has_responsibility('quality',ARRAY['admin','quality'])
$$;
-- Only the named RPCs change permission evaluation; module grants remain separate.
DO $$ DECLARE r record; definition text; BEGIN
 FOR r IN SELECT oid FROM pg_proc WHERE pronamespace='public'::regnamespace AND proname IN ('strategy_write','platform_module_write','import_kpi_csv') LOOP
 definition:=pg_get_functiondef(r.oid);
 definition:=replace(definition,'public.is_quality_or_admin()', 'public.has_responsibility(''strategy'',ARRAY[''admin'',''quality''])');
 EXECUTE definition;
 END LOOP;
END $$;
-- Evaluate each module's existing row policies with that module's responsibilities.
DO $$ DECLARE r record; module_name text; expression text; statement text; BEGIN
 FOR r IN SELECT * FROM pg_policies WHERE schemaname='public' AND (tablename LIKE 'lifecycle_%' OR tablename IN ('frameworks','cycles','swot_campaigns','swot_items','swot_contributions','tows_crossings','risk_opportunities','strategic_objectives','strategic_actions','kpis','kpi_targets','kpi_results','meetings','meeting_presenters','decisions','generated_files','strategy_history','ppt_templates','connectors')) LOOP
 module_name:=CASE WHEN r.tablename LIKE 'lifecycle_%' THEN 'lifecycle' ELSE 'strategy' END;
 statement:=format('ALTER POLICY %I ON public.%I',r.policyname,r.tablename);
 IF r.qual IS NOT NULL THEN
 expression:=replace(replace(replace(r.qual,'is_quality_or_admin()',format('has_responsibility(%L,ARRAY[''admin'',''quality''])',module_name)),'is_management()',format('has_responsibility(%L,ARRAY[''management''])',module_name)),'is_management_or_quality_or_admin()',format('has_responsibility(%L,ARRAY[''admin'',''quality'',''management''])',module_name));statement:=statement||' USING ('||expression||')';
 END IF;
 IF r.with_check IS NOT NULL THEN
 expression:=replace(replace(replace(r.with_check,'is_quality_or_admin()',format('has_responsibility(%L,ARRAY[''admin'',''quality''])',module_name)),'is_management()',format('has_responsibility(%L,ARRAY[''management''])',module_name)),'is_management_or_quality_or_admin()',format('has_responsibility(%L,ARRAY[''admin'',''quality'',''management''])',module_name));statement:=statement||' WITH CHECK ('||expression||')';
 END IF; EXECUTE statement;
 END LOOP;
END $$;
CREATE FUNCTION record_has_usage(p_table text,p_id uuid,p_org uuid) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
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
END $$;
REVOKE ALL ON FUNCTION record_has_usage(text,uuid,uuid) FROM PUBLIC;
CREATE FUNCTION protect_used_config() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
 IF (TG_TABLE_NAME='quality_catalogs' AND to_jsonb(OLD)->>'is_system'='true') OR record_has_usage(TG_TABLE_NAME,OLD.id,OLD.organization_id) THEN RAISE EXCEPTION 'Este valor está protegido ou já foi utilizado e não pode ser eliminado. Preserve o histórico; pode desativá-lo para impedir novas utilizações.'; END IF;
 RETURN OLD;
END $$;
DROP TRIGGER area_no_delete ON quality_areas;
CREATE TRIGGER area_no_delete BEFORE DELETE ON quality_areas FOR EACH ROW EXECUTE FUNCTION protect_used_config();
CREATE TRIGGER catalog_no_delete BEFORE DELETE ON quality_catalogs FOR EACH ROW EXECUTE FUNCTION protect_used_config();
CREATE TRIGGER auditor_no_delete BEFORE DELETE ON quality_auditors FOR EACH ROW EXECUTE FUNCTION protect_used_config();
-- Keep update protection, move deletion protection to the dependency-aware guard.
DROP TRIGGER quality_protect_nc_classification ON quality_catalogs;
CREATE TRIGGER quality_protect_nc_classification BEFORE UPDATE ON quality_catalogs FOR EACH ROW EXECUTE FUNCTION quality_protect_nc_classification();
CREATE FUNCTION assignments_integrity() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM profiles WHERE id=NEW.user_id AND organization_id=NEW.organization_id) OR (NEW.team_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM teams WHERE id=NEW.team_id AND organization_id=NEW.organization_id)) THEN RAISE EXCEPTION 'Atribuição de outra empresa.'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER assignments_integrity BEFORE INSERT OR UPDATE ON user_assignments FOR EACH ROW EXECUTE FUNCTION assignments_integrity();
CREATE FUNCTION track_assignment_usage() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
 IF NEW.entity_type NOT IN ('user_assignments','profiles','organization_memberships','quality_auditors','quality_catalogs') THEN
 UPDATE user_assignments SET used_at=now() WHERE used_at IS NULL AND active AND (user_id=NEW.user_id OR user_id::text=NEW.new_data->>'responsible_user_id' OR user_id::text=NEW.new_data->>'responsible_id' OR user_id::text=NEW.new_data->>'approver_id');
 UPDATE profiles SET account_used=true WHERE NOT account_used AND (id=NEW.user_id OR id::text=NEW.new_data->>'responsible_user_id' OR id::text=NEW.new_data->>'responsible_id');
 END IF; RETURN NEW;
END $$;
CREATE TRIGGER track_assignment_usage AFTER INSERT ON audit_log FOR EACH ROW EXECUTE FUNCTION track_assignment_usage();
CREATE FUNCTION preserve_used_assignment() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
 IF OLD.used_at IS NOT NULL THEN RAISE EXCEPTION 'Atribuição já utilizada. Termine a atribuição para preservar o histórico.'; END IF; RETURN OLD;
END $$;
CREATE TRIGGER preserve_used_assignment BEFORE DELETE ON user_assignments FOR EACH ROW EXECUTE FUNCTION preserve_used_assignment();
DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['quality_auditors','user_assignments'] LOOP
 EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY',t);
 EXECUTE format('CREATE POLICY company_read ON %I FOR SELECT TO authenticated USING(session_valid() AND (access_admin() OR organization_id=my_organization()))',t);
 EXECUTE format('REVOKE ALL ON %I FROM PUBLIC,anon,authenticated',t);
 EXECUTE format('GRANT SELECT ON %I TO authenticated',t);
 EXECUTE format('CREATE TRIGGER delta_history AFTER INSERT OR UPDATE OR DELETE ON %I FOR EACH ROW EXECUTE FUNCTION log_audit()',t);
 END LOOP;
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;

