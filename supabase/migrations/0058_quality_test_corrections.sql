BEGIN;
ALTER TABLE quality_origins DROP CONSTRAINT IF EXISTS quality_origins_name_key;
ALTER TABLE quality_areas DROP CONSTRAINT IF EXISTS quality_areas_name_key;
CREATE UNIQUE INDEX quality_origins_company_name ON quality_origins(organization_id,name);
CREATE UNIQUE INDEX quality_areas_company_name ON quality_areas(organization_id,name);
CREATE TABLE quality_audit_scope (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 organization_id uuid NOT NULL REFERENCES organizations(id),
 audit_id uuid NOT NULL REFERENCES quality_audits(id),
 kind text NOT NULL CHECK(kind IN ('area','standard','site')),
 area_id uuid REFERENCES quality_areas(id),
 standard_id uuid REFERENCES quality_catalogs(id),
 site text,
 CHECK((kind='area' AND area_id IS NOT NULL AND standard_id IS NULL AND site IS NULL)
 OR (kind='standard' AND standard_id IS NOT NULL AND area_id IS NULL AND site IS NULL)
 OR (kind='site' AND site IS NOT NULL AND btrim(site)<>'' AND area_id IS NULL AND standard_id IS NULL))
);
CREATE UNIQUE INDEX quality_scope_area ON quality_audit_scope(audit_id,area_id) WHERE kind='area';
CREATE UNIQUE INDEX quality_scope_standard ON quality_audit_scope(audit_id,standard_id) WHERE kind='standard';
CREATE UNIQUE INDEX quality_scope_site ON quality_audit_scope(audit_id,site) WHERE kind='site';
ALTER TABLE quality_occurrences ADD COLUMN standard_scope_id uuid REFERENCES quality_audit_scope(id), ADD COLUMN site_scope_id uuid REFERENCES quality_audit_scope(id);
ALTER TABLE quality_occurrences ADD COLUMN standard_id uuid REFERENCES quality_catalogs(id);
ALTER TABLE quality_audits ADD COLUMN lead_auditor_id uuid REFERENCES profiles(id);
-- Exact matches only: free text that cannot be mapped remains intact for review.
INSERT INTO quality_audit_scope(organization_id,audit_id,kind,area_id)
 SELECT a.organization_id,a.id,'area',p.id FROM quality_audits a JOIN quality_areas p ON p.organization_id=a.organization_id AND lower(btrim(p.name))=lower(btrim(a.areas));
INSERT INTO quality_catalogs(organization_id,kind,name)
 SELECT DISTINCT organization_id,'standard',btrim(standard) FROM quality_audits WHERE nullif(btrim(standard),'') IS NOT NULL ON CONFLICT DO NOTHING;
INSERT INTO quality_audit_scope(organization_id,audit_id,kind,standard_id)
 SELECT a.organization_id,a.id,'standard',c.id FROM quality_audits a JOIN quality_catalogs c ON c.organization_id=a.organization_id AND c.kind='standard' AND c.name=btrim(a.standard);
INSERT INTO quality_audit_scope(organization_id,audit_id,kind,site)
 SELECT organization_id,id,'site',btrim(sites) FROM quality_audits WHERE nullif(btrim(sites),'') IS NOT NULL;
INSERT INTO quality_catalogs(organization_id,kind,name)
 SELECT DISTINCT organization_id,'standard',btrim(standard) FROM quality_occurrences WHERE audit_id IS NULL AND nullif(btrim(standard),'') IS NOT NULL ON CONFLICT DO NOTHING;
UPDATE quality_occurrences o SET standard_id=c.id FROM quality_catalogs c WHERE o.audit_id IS NULL AND c.organization_id=o.organization_id AND c.kind='standard' AND c.name=btrim(o.standard);
-- Preserve every legacy field; new findings resolve context by relation.
CREATE OR REPLACE FUNCTION quality_scope_integrity() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM quality_audits WHERE id=NEW.audit_id AND organization_id=NEW.organization_id) THEN RAISE EXCEPTION 'Auditoria de outra empresa.'; END IF;
 IF NEW.kind='area' AND NOT EXISTS(SELECT 1 FROM quality_areas WHERE id=NEW.area_id AND organization_id=NEW.organization_id) THEN RAISE EXCEPTION 'Área de outra empresa.'; END IF;
 IF NEW.kind='standard' AND NOT EXISTS(SELECT 1 FROM quality_catalogs WHERE id=NEW.standard_id AND organization_id=NEW.organization_id AND kind='standard') THEN RAISE EXCEPTION 'Referencial inválido.'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER scope_integrity BEFORE INSERT OR UPDATE ON quality_audit_scope FOR EACH ROW EXECUTE FUNCTION quality_scope_integrity();
CREATE TRIGGER scope_history AFTER INSERT OR UPDATE OR DELETE ON quality_audit_scope FOR EACH ROW EXECUTE FUNCTION log_audit();
ALTER TABLE quality_audit_scope ENABLE ROW LEVEL SECURITY;
CREATE POLICY scope_read ON quality_audit_scope FOR SELECT TO authenticated USING(session_valid() AND has_module('quality') AND (access_admin() OR organization_id=my_organization()));
REVOKE ALL ON quality_audit_scope FROM PUBLIC,anon,authenticated;
GRANT SELECT ON quality_audit_scope TO authenticated;
-- No physical removal of the central catalogue: deactivation preserves history.
REVOKE INSERT,UPDATE,DELETE ON quality_areas FROM PUBLIC,anon,authenticated;
CREATE TRIGGER area_no_delete BEFORE DELETE ON quality_areas FOR EACH ROW EXECUTE FUNCTION quality_immutable();
INSERT INTO quality_origins(organization_id,name)
 SELECT o.id,n.name FROM organizations o CROSS JOIN (VALUES ('Auditoria Interna'),('Auditoria Externa')) n(name)
 WHERE NOT EXISTS(SELECT 1 FROM quality_origins x WHERE x.organization_id=o.id AND lower(x.name)=lower(n.name));
NOTIFY pgrst,'reload schema';
-- Calendar limits also protect direct API writes in the three applications.
-- NOT VALID preserves legacy rows; new writes must satisfy these checks.
DO $$ DECLARE r record; pair text[]; BEGIN
 FOR r IN SELECT c.table_name,c.column_name FROM information_schema.columns c JOIN information_schema.tables t USING(table_schema,table_name)
 WHERE c.table_schema='public' AND t.table_type='BASE TABLE' AND c.data_type='date' LOOP
 EXECUTE format('ALTER TABLE %I ADD CONSTRAINT %I CHECK (%I IS NULL OR (%I >= DATE ''0001-01-01'' AND %I <= DATE ''9999-12-31'')) NOT VALID',r.table_name,'q58_year_'||r.column_name,r.column_name,r.column_name,r.column_name);
 END LOOP;
 FOREACH pair SLICE 1 IN ARRAY ARRAY[['start_date','end_date'],['start_date','due_date'],['data_inicio','data_fim'],['data_inicio','data_conclusao'],['data_entrada','data_saida']] LOOP
 FOR r IN SELECT a.table_name FROM information_schema.columns a JOIN information_schema.columns b ON a.table_schema=b.table_schema AND a.table_name=b.table_name JOIN information_schema.tables t ON t.table_schema=a.table_schema AND t.table_name=a.table_name
 WHERE a.table_schema='public' AND t.table_type='BASE TABLE' AND a.column_name=pair[1] AND b.column_name=pair[2] AND a.data_type='date' AND b.data_type='date' LOOP
 EXECUTE format('ALTER TABLE %I ADD CONSTRAINT %I CHECK (%I IS NULL OR %I IS NULL OR %I >= %I) NOT VALID',r.table_name,'q58_range_'||pair[2],pair[1],pair[2],pair[2],pair[1]);
 END LOOP;
 END LOOP;
END $$;
COMMIT;
