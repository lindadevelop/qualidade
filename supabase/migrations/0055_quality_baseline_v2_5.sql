BEGIN;
CREATE TABLE quality_audits (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid NOT NULL REFERENCES organizations(id),
 reference text NOT NULL, kind text NOT NULL CHECK(kind IN ('INTERNAL','EXTERNAL')), title text NOT NULL,
 year integer NOT NULL, start_date date, end_date date, lead_auditor text, team text, standard text, scope text,
 areas text, sites text, auditor_entity text, external_kind text, accreditation text, certificate text,
 contract_reference text, representative text, headcount integer, conclusions text, recommendation text,
 status text NOT NULL DEFAULT 'OPEN', version integer NOT NULL DEFAULT 1,
 created_by uuid REFERENCES profiles(id), created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(organization_id,reference), CHECK(end_date IS NULL OR start_date IS NULL OR end_date>=start_date)
);
CREATE TABLE quality_catalogs (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),organization_id uuid NOT NULL REFERENCES organizations(id),
 kind text NOT NULL CHECK(kind IN ('finding','standard')),name text NOT NULL,active boolean NOT NULL DEFAULT true,
 UNIQUE(organization_id,kind,name)
);
ALTER TABLE quality_occurrences
 ADD COLUMN audit_id uuid REFERENCES quality_audits(id),
 ADD COLUMN original_text text, ADD COLUMN internal_context text,
 ADD COLUMN external_reference text, ADD COLUMN classification text, ADD COLUMN standard text, ADD COLUMN clause text, ADD COLUMN site text,
 ADD COLUMN root_cause text, ADD COLUMN root_cause_confirmed_by uuid REFERENCES profiles(id), ADD COLUMN root_cause_confirmed_at timestamptz,
 ADD COLUMN corrective_required boolean, ADD COLUMN corrective_reason text,
 ADD COLUMN effectiveness_required boolean, ADD COLUMN effectiveness_criterion text, ADD COLUMN effectiveness_due date,
 ADD COLUMN approval_required boolean NOT NULL DEFAULT false, ADD COLUMN approver_id uuid REFERENCES profiles(id),
 ADD COLUMN approval_status text NOT NULL DEFAULT 'DRAFT',
 ADD COLUMN assigned_at timestamptz, ADD COLUMN acknowledged_by uuid REFERENCES profiles(id), ADD COLUMN acknowledged_at timestamptz,
 ADD COLUMN cancelled_at timestamptz, ADD COLUMN cancelled_by uuid REFERENCES profiles(id), ADD COLUMN cancellation_reason text,
 ADD COLUMN cycle integer NOT NULL DEFAULT 1, ADD COLUMN version integer NOT NULL DEFAULT 1,
 ADD COLUMN recurrent boolean NOT NULL DEFAULT false, ADD COLUMN related_occurrence_id uuid REFERENCES quality_occurrences(id),
 ADD COLUMN reopen_reason text, ADD COLUMN external_status text NOT NULL DEFAULT 'Por responder';
-- Preserve existing decisions: infer applicability only, never invent a root cause or action classification.
UPDATE quality_occurrences SET effectiveness_required=(type='NC');
ALTER TABLE quality_actions
 ADD COLUMN action_kind text CHECK(action_kind IN ('CORRECTION','CORRECTIVE','IMPROVEMENT','RISK','OPPORTUNITY')),
 ADD COLUMN original_deadline date, ADD COLUMN assigned_at timestamptz,
 ADD COLUMN acknowledged_by uuid REFERENCES profiles(id), ADD COLUMN acknowledged_at timestamptz,
 ADD COLUMN completion_criterion text, ADD COLUMN effectiveness_criterion text, ADD COLUMN effectiveness_due date,
 ADD COLUMN mandatory boolean NOT NULL DEFAULT true, ADD COLUMN version integer NOT NULL DEFAULT 1,
 ADD COLUMN cancellation_reason text;
UPDATE quality_actions SET original_deadline=deadline;
CREATE TABLE quality_findings (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),organization_id uuid NOT NULL REFERENCES organizations(id),
 audit_id uuid NOT NULL REFERENCES quality_audits(id),classification text NOT NULL,original_text text NOT NULL,
 internal_context text,created_by uuid REFERENCES profiles(id),created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE quality_effectiveness_reviews (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),organization_id uuid NOT NULL REFERENCES organizations(id),
 occurrence_id uuid NOT NULL REFERENCES quality_occurrences(id),cycle integer NOT NULL,result text NOT NULL CHECK(result IN ('EFFECTIVE','NOT_EFFECTIVE')),
 criterion text NOT NULL,evidence_ids uuid[] NOT NULL DEFAULT '{}',conclusion text NOT NULL,
 evaluator_id uuid NOT NULL REFERENCES profiles(id),evaluated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE quality_approval_decisions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),organization_id uuid NOT NULL REFERENCES organizations(id),
 occurrence_id uuid NOT NULL REFERENCES quality_occurrences(id),cycle integer NOT NULL,
 decision text NOT NULL CHECK(decision IN ('SUBMITTED','APPROVED','RETURNED','REJECTED')),
 comment text,actor_id uuid NOT NULL REFERENCES profiles(id),created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE quality_deadline_changes (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),organization_id uuid NOT NULL REFERENCES organizations(id),
 action_id uuid NOT NULL REFERENCES quality_actions(id),old_deadline date,new_deadline date NOT NULL,reason text NOT NULL,
 requested_by uuid NOT NULL REFERENCES profiles(id),requested_at timestamptz NOT NULL DEFAULT now(),
 status text NOT NULL CHECK(status IN ('PENDING','APPROVED','REJECTED')),decided_by uuid REFERENCES profiles(id),decided_at timestamptz,decision_comment text
);
CREATE TABLE quality_external_responses (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),organization_id uuid NOT NULL REFERENCES organizations(id),
 occurrence_id uuid NOT NULL REFERENCES quality_occurrences(id),cause_sent text,correction text,corrective_action text,
 implementation_due date,evidence_ids uuid[] NOT NULL DEFAULT '{}',sent_at timestamptz,status text NOT NULL,
 auditor_original_text text,auditor_name text,responded_at timestamptz,acceptance text,additional_requests text,future_verification text,
 created_by uuid NOT NULL REFERENCES profiles(id),created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE quality_attachments ADD COLUMN audit_id uuid REFERENCES quality_audits(id),ADD COLUMN review_id uuid REFERENCES quality_effectiveness_reviews(id),ADD COLUMN external_response_id uuid REFERENCES quality_external_responses(id);
CREATE TABLE quality_settings (
 organization_id uuid PRIMARY KEY REFERENCES organizations(id),deadline_approval boolean NOT NULL DEFAULT false,
 reminder_days integer[] NOT NULL DEFAULT '{7,3,1}',retry_minutes integer[] NOT NULL DEFAULT '{5,30,120}',
 finding_classifications text[] NOT NULL DEFAULT '{NC Menor,NC Maior,Observação}',version integer NOT NULL DEFAULT 1
);
CREATE TABLE quality_outbox (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),organization_id uuid NOT NULL REFERENCES organizations(id),
 event_key text NOT NULL,entity_type text NOT NULL,entity_id uuid NOT NULL,recipient_id uuid NOT NULL REFERENCES profiles(id),
 channel text NOT NULL DEFAULT 'email',template text NOT NULL,subject text NOT NULL,message text NOT NULL,link text NOT NULL,
 status text NOT NULL DEFAULT 'PENDING' CHECK(status IN ('PENDING','SENDING','SENT','FAILED')),
 attempts integer NOT NULL DEFAULT 0,next_attempt_at timestamptz NOT NULL DEFAULT now(),sent_at timestamptz,
 last_error text,locked_at timestamptz,created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(event_key,recipient_id,channel)
);
CREATE INDEX quality_outbox_due ON quality_outbox(next_attempt_at) WHERE status='PENDING';
CREATE INDEX quality_audits_org ON quality_audits(organization_id,year);
CREATE INDEX quality_occurrences_audit ON quality_occurrences(audit_id);
CREATE INDEX quality_reviews_occurrence ON quality_effectiveness_reviews(occurrence_id,cycle);
CREATE INDEX quality_deadline_pending ON quality_deadline_changes(organization_id,status);
ALTER TABLE notifications ADD COLUMN event_key text,ADD COLUMN organization_id uuid REFERENCES organizations(id),ADD COLUMN link text;
UPDATE notifications n SET organization_id=p.organization_id FROM profiles p WHERE p.id=n.user_id AND n.organization_id IS NULL;
CREATE POLICY v25_notification_boundary ON notifications AS RESTRICTIVE FOR ALL TO authenticated USING(session_valid() AND has_module('quality') AND (access_admin() OR organization_id=my_organization())) WITH CHECK(session_valid() AND has_module('quality') AND (access_admin() OR organization_id=my_organization()));
REVOKE INSERT,UPDATE,DELETE ON notifications FROM PUBLIC,anon,authenticated;
GRANT UPDATE(read) ON notifications TO authenticated;
CREATE UNIQUE INDEX notifications_event_recipient ON notifications(event_key,user_id) WHERE event_key IS NOT NULL;

CREATE OR REPLACE FUNCTION quality_version() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN NEW.version:=OLD.version+1;NEW.updated_at:=clock_timestamp(); RETURN NEW; END $$;
CREATE TRIGGER quality_audits_version BEFORE UPDATE ON quality_audits FOR EACH ROW EXECUTE FUNCTION quality_version();
CREATE TRIGGER quality_occurrences_version BEFORE UPDATE ON quality_occurrences FOR EACH ROW EXECUTE FUNCTION quality_version();
CREATE TRIGGER quality_actions_version BEFORE UPDATE ON quality_actions FOR EACH ROW EXECUTE FUNCTION quality_version();
CREATE OR REPLACE FUNCTION quality_immutable() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'Registo imutável: o histórico e a evidência devem ser preservados.'; END $$;
CREATE OR REPLACE FUNCTION quality_original_text() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
 IF OLD.original_text IS NOT NULL AND NEW.original_text IS DISTINCT FROM OLD.original_text THEN RAISE EXCEPTION 'O texto original do auditor não pode ser substituído.'; END IF;RETURN NEW;END $$;
CREATE TRIGGER quality_original_text BEFORE UPDATE ON quality_occurrences FOR EACH ROW EXECUTE FUNCTION quality_original_text();
CREATE OR REPLACE FUNCTION log_audit() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE oldj jsonb;newj jsonb;org uuid;
BEGIN
 IF TG_OP<>'INSERT' THEN oldj:=to_jsonb(OLD); END IF;
 IF TG_OP<>'DELETE' THEN newj:=to_jsonb(NEW); END IF;
 org:=coalesce((newj->>'organization_id')::uuid,(oldj->>'organization_id')::uuid,current_company_context());
 INSERT INTO audit_log(entity_type,entity_id,action,old_data,new_data,user_id,organization_id)
 VALUES(TG_TABLE_NAME,coalesce((newj->>'id')::uuid,(oldj->>'id')::uuid),lower(TG_OP),oldj,newj,auth.uid(),org);
 RETURN coalesce(NEW,OLD);
END $$;
DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['quality_audits','quality_findings','quality_effectiveness_reviews','quality_approval_decisions','quality_deadline_changes','quality_external_responses','quality_attachments','quality_comments'] LOOP
 EXECUTE format('CREATE TRIGGER v25_audit AFTER INSERT OR UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION log_audit()',t);
 END LOOP;
 FOREACH t IN ARRAY ARRAY['audit_log','quality_effectiveness_reviews','quality_approval_decisions','quality_external_responses','quality_plan_approval_events','quality_findings','quality_attachments'] LOOP
 EXECUTE format('CREATE TRIGGER v25_immutable BEFORE UPDATE OR DELETE ON %I FOR EACH ROW EXECUTE FUNCTION quality_immutable()',t);
 END LOOP;
 FOREACH t IN ARRAY ARRAY['quality_audits','quality_findings','quality_effectiveness_reviews','quality_approval_decisions','quality_deadline_changes','quality_external_responses','quality_catalogs','quality_settings','quality_outbox'] LOOP
 EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY',t);
 EXECUTE format('CREATE POLICY v25_read ON %I FOR SELECT TO authenticated USING (session_valid() AND has_module(''quality'') AND (access_admin() OR organization_id=my_organization()))',t);
 EXECUTE format('REVOKE ALL ON %I FROM PUBLIC,anon,authenticated',t);
 IF t<>'quality_outbox' THEN EXECUTE format('GRANT SELECT ON %I TO authenticated',t); END IF;
 END LOOP;
END $$;
-- All formal writes now go through the authenticated command handler. Keep read compatibility.
REVOKE INSERT,UPDATE,DELETE ON quality_occurrences,quality_actions,quality_attachments,quality_comments,quality_compliance_plans,quality_plan_approval_events,quality_work_logs,audit_log FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION guard_close_occurrence() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
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
CREATE OR REPLACE FUNCTION update_occurrence_status_from_actions() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE target uuid; total integer;pending integer;required boolean;current_state occurrence_status;
BEGIN
 target:=coalesce(NEW.occurrence_id,OLD.occurrence_id);IF target IS NULL THEN RETURN coalesce(NEW,OLD);END IF;
 SELECT status,effectiveness_required INTO current_state,required FROM quality_occurrences WHERE id=target AND cancelled_at IS NULL FOR UPDATE;
 IF NOT FOUND OR current_state='CLOSED' THEN RETURN coalesce(NEW,OLD);END IF;
 SELECT count(*),count(*) FILTER(WHERE status<>'COMPLETED') INTO total,pending FROM quality_actions WHERE occurrence_id=target AND status<>'CANCELLED' AND mandatory;
 UPDATE quality_occurrences SET status=CASE WHEN total>0 AND pending=0 AND required THEN 'AWAITING_EFFECTIVENESS'::occurrence_status ELSE 'IN_PROGRESS'::occurrence_status END WHERE id=target;
 RETURN coalesce(NEW,OLD);
END $$;
-- Baseline retention: operational cancellation replaces physical removal.
DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['quality_occurrences','quality_actions','quality_audits','quality_compliance_plans'] LOOP
 EXECUTE format('CREATE TRIGGER v25_no_delete BEFORE DELETE ON %I FOR EACH ROW EXECUTE FUNCTION quality_immutable()',t);
 END LOOP;
END $$;
REVOKE TRUNCATE ON quality_occurrences,quality_actions,quality_audits,quality_attachments,audit_log FROM PUBLIC,anon,authenticated;
CREATE VIEW quality_active_occurrences WITH(security_invoker=true) AS SELECT * FROM quality_occurrences WHERE cancelled_at IS NULL;
CREATE VIEW quality_active_actions WITH(security_invoker=true) AS SELECT a.* FROM quality_actions a WHERE a.status<>'CANCELLED' AND NOT EXISTS(SELECT 1 FROM quality_occurrences o WHERE o.id=a.occurrence_id AND o.cancelled_at IS NOT NULL);
GRANT SELECT ON quality_active_occurrences,quality_active_actions TO authenticated;
DO $$ DECLARE f record; BEGIN
 FOR f IN SELECT p.oid FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname IN ('get_dashboard_metrics','get_occurrence_evolution','get_occurrences_by_status','get_occurrences_by_origin','get_occurrences_by_area','get_actions_by_responsible','get_urgent_actions') LOOP
 EXECUTE replace(replace(pg_get_functiondef(f.oid),'public.quality_occurrences','public.quality_active_occurrences'),'public.quality_actions','public.quality_active_actions');
 END LOOP;
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;
