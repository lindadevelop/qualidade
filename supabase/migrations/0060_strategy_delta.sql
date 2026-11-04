BEGIN;
ALTER TABLE swot_campaigns ADD COLUMN is_demo boolean NOT NULL DEFAULT false,
 ADD COLUMN min_per_quadrant integer NOT NULL DEFAULT 0 CHECK(min_per_quadrant>=0),
 ADD COLUMN max_per_quadrant integer NOT NULL DEFAULT 20 CHECK(max_per_quadrant>0),
 ADD COLUMN validation_rules text NOT NULL DEFAULT 'Consolidação e validação humana antes da SWOT oficial',
 ADD COLUMN version integer NOT NULL DEFAULT 1,
 ADD CHECK(max_per_quadrant>=min_per_quadrant), ADD CHECK(ends_at IS NULL OR starts_at IS NULL OR ends_at>=starts_at);
ALTER TABLE swot_campaigns ALTER COLUMN status SET DEFAULT 'draft';
UPDATE swot_campaigns SET is_demo=true WHERE name ILIKE '%demo%';
CREATE TABLE swot_campaign_audience(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),organization_id uuid NOT NULL REFERENCES organizations(id),campaign_id uuid NOT NULL REFERENCES swot_campaigns(id),user_id uuid REFERENCES profiles(id),team_id uuid REFERENCES teams(id),CHECK((user_id IS NOT NULL)::int+(team_id IS NOT NULL)::int=1));
ALTER TABLE swot_contributions ALTER COLUMN item_id DROP NOT NULL;
ALTER TABLE swot_contributions ADD COLUMN updated_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE swot_contributions ADD COLUMN campaign_id uuid REFERENCES swot_campaigns(id), ADD COLUMN organization_id uuid REFERENCES organizations(id),ADD COLUMN quadrant swot_quadrant, ADD COLUMN team_id uuid REFERENCES teams(id),ADD COLUMN source text NOT NULL DEFAULT 'Aplicação', ADD COLUMN author_label text;
UPDATE swot_contributions r SET campaign_id=i.campaign_id,organization_id=c.organization_id,quadrant=i.quadrant FROM swot_items i JOIN swot_campaigns c ON c.id=i.campaign_id WHERE r.item_id=i.id;
ALTER TABLE swot_contributions ALTER COLUMN campaign_id SET NOT NULL, ALTER COLUMN organization_id SET NOT NULL;
CREATE TABLE swot_proposals(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),organization_id uuid NOT NULL REFERENCES organizations(id),campaign_id uuid NOT NULL REFERENCES swot_campaigns(id),quadrant swot_quadrant NOT NULL,title text NOT NULL,contribution_ids uuid[] NOT NULL, status text NOT NULL DEFAULT 'proposed' CHECK(status IN ('proposed','validated')),item_id uuid REFERENCES swot_items(id),created_by uuid REFERENCES profiles(id),validated_by uuid REFERENCES profiles(id),created_at timestamptz NOT NULL DEFAULT now(),validated_at timestamptz);
CREATE TABLE platform_admin_history(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),organization_id uuid NOT NULL REFERENCES organizations(id),entity_type text NOT NULL,entity_id uuid NOT NULL,action text NOT NULL,before_data jsonb,after_data jsonb,actor_id uuid NOT NULL REFERENCES profiles(id),created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE brand_assets(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),organization_id uuid NOT NULL REFERENCES organizations(id),brand_kit_id uuid NOT NULL REFERENCES brand_kits(id),kind text NOT NULL CHECK(kind IN ('logo','icon','favicon')),mime_type text NOT NULL,content_base64 text NOT NULL,width integer NOT NULL,height integer NOT NULL,created_by uuid REFERENCES profiles(id),created_at timestamptz NOT NULL DEFAULT now());
ALTER TABLE brand_kits ADD COLUMN logo_asset_id uuid REFERENCES brand_assets(id),ADD COLUMN icon_asset_id uuid REFERENCES brand_assets(id),ADD COLUMN favicon_asset_id uuid REFERENCES brand_assets(id);
CREATE FUNCTION delta_swot_guard() RETURNS trigger LANGUAGE plpgsql AS $$ DECLARE campaign swot_campaigns; BEGIN
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
CREATE TRIGGER delta_swot_guard BEFORE INSERT OR UPDATE OR DELETE ON swot_items FOR EACH ROW EXECUTE FUNCTION delta_swot_guard();
CREATE TRIGGER delta_swot_original BEFORE UPDATE OR DELETE ON swot_contributions FOR EACH ROW EXECUTE FUNCTION delta_swot_guard();
CREATE TRIGGER campaign_version BEFORE UPDATE ON swot_campaigns FOR EACH ROW EXECUTE FUNCTION quality_version();
CREATE TRIGGER admin_history_immutable BEFORE UPDATE OR DELETE ON platform_admin_history FOR EACH ROW EXECUTE FUNCTION quality_immutable();
CREATE TRIGGER brand_assets_immutable BEFORE UPDATE OR DELETE ON brand_assets FOR EACH ROW EXECUTE FUNCTION quality_immutable();
CREATE FUNCTION track_strategy_assignment_usage() RETURNS trigger LANGUAGE plpgsql AS $$ DECLARE actor uuid; BEGIN
 actor:=coalesce((to_jsonb(NEW)->>'actor_id')::uuid,(to_jsonb(NEW)->>'reviewed_by')::uuid);
 UPDATE user_assignments SET used_at=now() WHERE used_at IS NULL AND active AND (user_id=actor OR user_id::text=NEW.after_data->>'responsible_id') AND (starts_on IS NULL OR starts_on<=current_date) AND (ends_on IS NULL OR ends_on>=current_date);
 UPDATE profiles SET account_used=true WHERE NOT account_used AND id=actor;
 RETURN NEW; END $$;
CREATE TRIGGER track_strategy_assignment_usage AFTER INSERT ON platform_admin_history FOR EACH ROW EXECUTE FUNCTION track_strategy_assignment_usage();
CREATE TRIGGER track_strategy_assignment_usage AFTER INSERT ON strategy_history FOR EACH ROW EXECUTE FUNCTION track_strategy_assignment_usage();
REVOKE INSERT,UPDATE,DELETE ON swot_campaigns,swot_contributions FROM PUBLIC,anon,authenticated;
DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['swot_campaign_audience','swot_proposals','platform_admin_history','brand_assets'] LOOP
 EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY',t);
 EXECUTE format('CREATE POLICY delta_company_read ON %I FOR SELECT TO authenticated USING(session_valid() AND (access_admin() OR organization_id=my_organization()) AND has_module(''strategy''))',t);
 EXECUTE format('REVOKE ALL ON %I FROM PUBLIC,anon,authenticated',t);
 EXECUTE format('GRANT SELECT ON %I TO authenticated',t);
 END LOOP;
END $$;
DROP POLICY delta_company_read ON brand_assets;
CREATE POLICY delta_company_read ON brand_assets FOR SELECT TO authenticated USING(session_valid() AND (access_admin() OR organization_id=my_organization()));
-- Dependencies used in the past also prevent deletion even after relations change.
CREATE FUNCTION protect_campaign_delete() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
 IF EXISTS(SELECT 1 FROM swot_items WHERE campaign_id=OLD.id) OR EXISTS(SELECT 1 FROM swot_contributions WHERE campaign_id=OLD.id) OR EXISTS(SELECT 1 FROM platform_admin_history WHERE entity_id=OLD.id AND action NOT IN ('create','edit')) THEN RAISE EXCEPTION 'Campanha já utilizada. Arquive para preservar o histórico.'; END IF; RETURN OLD;
END $$;
CREATE TRIGGER protect_campaign_delete BEFORE DELETE ON swot_campaigns FOR EACH ROW EXECUTE FUNCTION protect_campaign_delete();
NOTIFY pgrst,'reload schema';
COMMIT;
