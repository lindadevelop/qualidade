BEGIN;
-- Old originals remain unchanged. New campaigns use participant/context quotas.
ALTER TABLE swot_campaigns ADD COLUMN quota_mode text NOT NULL DEFAULT 'legacy' CHECK(quota_mode IN ('legacy','participant_context')),
 ADD COLUMN min_own integer NOT NULL DEFAULT 3, ADD COLUMN max_own integer NOT NULL DEFAULT 5,
 ADD COLUMN min_other integer NOT NULL DEFAULT 3, ADD COLUMN max_other integer NOT NULL DEFAULT 5,
 ADD CHECK(min_own>=1 AND max_own>=min_own AND max_own<=1000 AND min_other>=1 AND max_other>=min_other AND max_other<=1000);
ALTER TABLE swot_campaigns ALTER COLUMN quota_mode SET DEFAULT 'participant_context';
CREATE TABLE strategy_thematic_areas(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),organization_id uuid NOT NULL REFERENCES organizations(id),name text NOT NULL CHECK(length(trim(name))>0),active boolean NOT NULL DEFAULT true,created_at timestamptz NOT NULL DEFAULT now(),updated_at timestamptz NOT NULL DEFAULT now(),UNIQUE(organization_id,name));
CREATE TABLE strategy_area_teams(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),organization_id uuid NOT NULL REFERENCES organizations(id),area_id uuid NOT NULL REFERENCES strategy_thematic_areas(id),team_id uuid NOT NULL REFERENCES teams(id),UNIQUE(area_id,team_id));
CREATE TABLE swot_campaign_validators(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),organization_id uuid NOT NULL REFERENCES organizations(id),campaign_id uuid NOT NULL REFERENCES swot_campaigns(id),user_id uuid NOT NULL REFERENCES profiles(id),team_id uuid REFERENCES teams(id));
CREATE UNIQUE INDEX swot_validator_unique ON swot_campaign_validators(campaign_id,user_id,coalesce(team_id,'00000000-0000-0000-0000-000000000000'::uuid));
ALTER TABLE swot_contributions ADD COLUMN thematic_area_id uuid REFERENCES strategy_thematic_areas(id), ADD COLUMN contribution_scope text CHECK(contribution_scope IN ('own_team','organization','other_team'));
ALTER TABLE swot_items ADD COLUMN thematic_area_id uuid REFERENCES strategy_thematic_areas(id);
ALTER TABLE swot_proposals ADD COLUMN thematic_area_id uuid REFERENCES strategy_thematic_areas(id);
CREATE TABLE swot_submissions(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),organization_id uuid NOT NULL REFERENCES organizations(id),campaign_id uuid NOT NULL REFERENCES swot_campaigns(id),user_id uuid NOT NULL REFERENCES profiles(id),submitted_at timestamptz NOT NULL DEFAULT now(),UNIQUE(campaign_id,user_id));
CREATE TABLE swot_context_reviews(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),organization_id uuid NOT NULL REFERENCES organizations(id),contribution_id uuid NOT NULL UNIQUE REFERENCES swot_contributions(id),decision text NOT NULL CHECK(decision IN ('approved','rejected')),reason text NOT NULL,reviewer_id uuid NOT NULL REFERENCES profiles(id),created_at timestamptz NOT NULL DEFAULT now());
CREATE TRIGGER swot_submission_immutable BEFORE UPDATE OR DELETE ON swot_submissions FOR EACH ROW EXECUTE FUNCTION quality_immutable();
CREATE TRIGGER swot_context_review_immutable BEFORE UPDATE OR DELETE ON swot_context_reviews FOR EACH ROW EXECUTE FUNCTION quality_immutable();
CREATE FUNCTION strategy_context_guard() RETURNS trigger LANGUAGE plpgsql AS $$ DECLARE campaign swot_campaigns; BEGIN
 SELECT * INTO campaign FROM swot_campaigns WHERE id=NEW.campaign_id FOR UPDATE;
 IF campaign.organization_id IS DISTINCT FROM NEW.organization_id THEN RAISE EXCEPTION 'Campanha de outra empresa.'; END IF;
 IF campaign.quota_mode='participant_context' THEN
  IF NEW.thematic_area_id IS NULL OR NEW.contribution_scope IS NULL OR NOT EXISTS(SELECT 1 FROM strategy_thematic_areas WHERE id=NEW.thematic_area_id AND organization_id=NEW.organization_id AND active) THEN RAISE EXCEPTION 'Seleciona a área temática e o contexto.'; END IF;
  IF (NEW.contribution_scope='organization') IS DISTINCT FROM (NEW.team_id IS NULL) THEN RAISE EXCEPTION 'Seleciona a equipa correspondente ao contexto.'; END IF;
  IF EXISTS(SELECT 1 FROM swot_submissions WHERE campaign_id=NEW.campaign_id AND user_id=NEW.user_id) THEN RAISE EXCEPTION 'Participação já submetida.'; END IF;
 END IF; RETURN NEW;
END $$;
CREATE TRIGGER strategy_context_guard BEFORE INSERT ON swot_contributions FOR EACH ROW EXECUTE FUNCTION strategy_context_guard();
CREATE FUNCTION strategy_structure_guard() RETURNS trigger LANGUAGE plpgsql AS $$ DECLARE used boolean; BEGIN
 used:=record_has_usage(TG_TABLE_NAME,OLD.id,OLD.organization_id) OR EXISTS(SELECT 1 FROM platform_admin_history WHERE organization_id=OLD.organization_id AND entity_type<>TG_TABLE_NAME AND (before_data::text LIKE '%'||OLD.id||'%' OR after_data::text LIKE '%'||OLD.id||'%')) OR EXISTS(SELECT 1 FROM strategy_history WHERE table_name<>TG_TABLE_NAME AND (before_data::text LIKE '%'||OLD.id||'%' OR after_data::text LIKE '%'||OLD.id||'%'));
 IF used AND TG_OP='DELETE' THEN RAISE EXCEPTION 'Registo utilizado. Desative ou arquive para preservar as dependências e o histórico.'; END IF;
 IF TG_TABLE_NAME='cycles' AND TG_OP='UPDATE' AND used THEN
  IF NEW.framework_id IS DISTINCT FROM OLD.framework_id OR NEW.organization_id IS DISTINCT FROM OLD.organization_id THEN RAISE EXCEPTION 'Um ciclo utilizado mantém a empresa e o framework.'; END IF;
  IF NEW.start_date>OLD.start_date OR (NEW.end_date IS NOT NULL AND (OLD.end_date IS NULL OR NEW.end_date<OLD.end_date)) THEN RAISE EXCEPTION 'Um ciclo utilizado não pode ter o período reduzido. Pode alargar as datas ou criar um novo ciclo.'; END IF;
 END IF;
 IF TG_OP='UPDATE' AND NEW.organization_id IS DISTINCT FROM OLD.organization_id THEN RAISE EXCEPTION 'Não é possível transferir este registo para outra empresa.'; END IF;
 RETURN coalesce(NEW,OLD);
END $$;
CREATE TRIGGER strategy_structure_guard BEFORE UPDATE OR DELETE ON teams FOR EACH ROW EXECUTE FUNCTION strategy_structure_guard();
CREATE TRIGGER strategy_structure_guard BEFORE UPDATE OR DELETE ON cycles FOR EACH ROW EXECUTE FUNCTION strategy_structure_guard();
DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['strategy_thematic_areas','strategy_area_teams','swot_campaign_validators','swot_submissions','swot_context_reviews'] LOOP
 EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY',t);
 EXECUTE format('CREATE POLICY company_read ON %I FOR SELECT TO authenticated USING(session_valid() AND (access_admin() OR organization_id=my_organization()) AND has_module(''strategy''))',t);
 EXECUTE format('REVOKE ALL ON %I FROM PUBLIC,anon,authenticated',t);
 EXECUTE format('GRANT SELECT ON %I TO authenticated',t);
 END LOOP;
END $$;
CREATE FUNCTION strategy_membership_active_guard() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
 IF NEW.active AND (TG_OP='INSERT' OR NEW.user_id IS DISTINCT FROM OLD.user_id OR NOT OLD.active) AND NOT EXISTS(SELECT 1 FROM profiles WHERE id=NEW.user_id AND active AND organization_id=NEW.organization_id) THEN RAISE EXCEPTION 'Só é possível associar utilizadores ativos da organização selecionada.'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER strategy_membership_active_guard BEFORE INSERT OR UPDATE ON organization_memberships FOR EACH ROW EXECUTE FUNCTION strategy_membership_active_guard();
NOTIFY pgrst,'reload schema';
COMMIT;
