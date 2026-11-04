BEGIN;
ALTER TABLE quality_settings
 ADD COLUMN overdue_reminder_days integer[] NOT NULL DEFAULT '{1,3}',
 ADD COLUMN quality_escalation_days integer NOT NULL DEFAULT 5 CHECK(quality_escalation_days>0),
 ADD COLUMN leader_escalation_days integer NOT NULL DEFAULT 10 CHECK(leader_escalation_days>0),
 ADD COLUMN escalation_leader_id uuid REFERENCES profiles(id);
-- Defaults only: never overwrite an organization's saved reminder/retry choices.
ALTER TABLE quality_settings ALTER COLUMN reminder_days SET DEFAULT '{7,3,1}';
ALTER TABLE quality_settings ALTER COLUMN retry_minutes SET DEFAULT '{5,30,120}';
ALTER TABLE quality_settings ALTER COLUMN finding_classifications SET DEFAULT '{Observação}';
ALTER TABLE quality_catalogs DROP CONSTRAINT quality_catalogs_kind_check;
ALTER TABLE quality_catalogs ADD CONSTRAINT quality_catalogs_kind_check CHECK(kind IN ('finding','standard','nc_classification'));
ALTER TABLE quality_catalogs ADD COLUMN is_system boolean NOT NULL DEFAULT false;

INSERT INTO quality_catalogs(organization_id,kind,name,active,is_system)
 SELECT o.id,'nc_classification',n,true,true FROM organizations o CROSS JOIN unnest(ARRAY['NC Menor','NC Maior']) n;
-- Retain original arrays as audit-finding configuration. Copy custom NC names,
-- without turning the former default Observação into a new NC classification.
INSERT INTO quality_catalogs(organization_id,kind,name)
 SELECT DISTINCT organization_id,'nc_classification',btrim(n)
 FROM quality_settings CROSS JOIN LATERAL unnest(finding_classifications) n
 WHERE btrim(n)<>'' AND lower(btrim(n)) NOT IN ('nc menor','nc maior','observação')
 ON CONFLICT DO NOTHING;
-- Existing NC text remains unchanged; retain all actually used names, including
-- Observação if it really was used in a historical NC.
INSERT INTO quality_catalogs(organization_id,kind,name)
 SELECT DISTINCT organization_id,'nc_classification',btrim(classification)
 FROM quality_occurrences WHERE type='NC' AND nullif(btrim(classification),'') IS NOT NULL
 AND lower(btrim(classification)) NOT IN ('nc menor','nc maior') ON CONFLICT DO NOTHING;

CREATE FUNCTION quality_seed_nc_classifications() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 INSERT INTO quality_catalogs(organization_id,kind,name,active,is_system)
 VALUES(NEW.id,'nc_classification','NC Menor',true,true),(NEW.id,'nc_classification','NC Maior',true,true);
 RETURN NEW;
END $$;
CREATE TRIGGER quality_seed_nc_classifications AFTER INSERT ON organizations FOR EACH ROW EXECUTE FUNCTION quality_seed_nc_classifications();
CREATE FUNCTION quality_protect_nc_classification() RETURNS trigger LANGUAGE plpgsql SET search_path=public AS $$
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
CREATE TRIGGER quality_protect_nc_classification BEFORE UPDATE OR DELETE ON quality_catalogs FOR EACH ROW EXECUTE FUNCTION quality_protect_nc_classification();
NOTIFY pgrst,'reload schema';
COMMIT;
