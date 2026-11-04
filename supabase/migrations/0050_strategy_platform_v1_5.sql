-- ============================================================
-- Scaffold v1.5 · Plataforma Estratégica Samsys
-- Tabelas novas para gestão estratégica: organizações, SWOT,
-- TOWS, riscos/oportunidades, objetivos, KPIs, reuniões,
-- apresentações, conectores e feature flags.
-- Idempotente, aditivo, não altera tabelas existentes.
-- ============================================================
BEGIN;

-- ---------- helpers ----------
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.is_quality_or_admin()
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role IN ('quality','admin')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.is_management_or_quality_or_admin()
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role IN ('management','quality','admin')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ---------- 1. organizações e memberships ----------
CREATE TABLE IF NOT EXISTS public.organizations (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name            text NOT NULL,
  slug            text UNIQUE,
  description     text,
  tax_id          text,
  website         text,
  email           text,
  phone           text,
  address         text,
  city            text,
  country         text DEFAULT 'PT',
  logo_url        text,
  primary_color   text DEFAULT '#7367f0',
  secondary_color text DEFAULT '#00cfe8',
  active          boolean NOT NULL DEFAULT true,
  created_at      timestamp with time zone NOT NULL DEFAULT now(),
  updated_at      timestamp with time zone NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.organization_memberships (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  user_id         uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  role            text NOT NULL DEFAULT 'member', -- owner / admin / member / viewer
  department      text,
  job_title       text,
  active          boolean NOT NULL DEFAULT true,
  created_at      timestamp with time zone NOT NULL DEFAULT now(),
  updated_at      timestamp with time zone NOT NULL DEFAULT now(),
  UNIQUE (organization_id, user_id)
);

-- ---------- 2. equipas e roles ----------
CREATE TABLE IF NOT EXISTS public.teams (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  name            text NOT NULL,
  description     text,
  color           text,
  active          boolean NOT NULL DEFAULT true,
  created_at      timestamp with time zone NOT NULL DEFAULT now(),
  updated_at      timestamp with time zone NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.roles (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  name            text NOT NULL,
  description     text,
  permissions     jsonb DEFAULT '[]'::jsonb,
  active          boolean NOT NULL DEFAULT true,
  created_at      timestamp with time zone NOT NULL DEFAULT now(),
  updated_at      timestamp with time zone NOT NULL DEFAULT now()
);

-- ---------- 3. brand kits ----------
CREATE TABLE IF NOT EXISTS public.brand_kits (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id    uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  name               text NOT NULL,
  is_default         boolean NOT NULL DEFAULT false,
  primary_color      text DEFAULT '#7367f0',
  secondary_color    text DEFAULT '#00cfe8',
  background_color   text DEFAULT '#ffffff',
  text_color         text DEFAULT '#2c2c2c',
  accent_color       text DEFAULT '#28c76f',
  danger_color       text DEFAULT '#ea5455',
  warning_color      text DEFAULT '#ff9f43',
  info_color         text DEFAULT '#00cfe8',
  success_color      text DEFAULT '#28c76f',
  logo_url           text,
  font_heading       text DEFAULT 'Inter',
  font_body          text DEFAULT 'Inter',
  slide_master       jsonb,
  created_at         timestamp with time zone NOT NULL DEFAULT now(),
  updated_at         timestamp with time zone NOT NULL DEFAULT now()
);

-- ---------- 4. frameworks e cycles ----------
CREATE TABLE IF NOT EXISTS public.frameworks (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  code            text NOT NULL,
  name            text NOT NULL,
  description     text,
  type            text NOT NULL DEFAULT 'strategic', -- strategic / quality / compliance / custom
  active          boolean NOT NULL DEFAULT true,
  created_at      timestamp with time zone NOT NULL DEFAULT now(),
  updated_at      timestamp with time zone NOT NULL DEFAULT now(),
  UNIQUE (organization_id, code)
);

CREATE TABLE IF NOT EXISTS public.cycles (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  framework_id    uuid REFERENCES public.frameworks(id) ON DELETE SET NULL,
  name            text NOT NULL,
  description     text,
  start_date      date NOT NULL,
  end_date        date,
  status          text NOT NULL DEFAULT 'draft', -- draft / active / closed / archived
  active          boolean NOT NULL DEFAULT true,
  created_at      timestamp with time zone NOT NULL DEFAULT now(),
  updated_at      timestamp with time zone NOT NULL DEFAULT now()
);

-- ---------- 5. SWOT ----------
CREATE TABLE IF NOT EXISTS public.swot_campaigns (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  cycle_id        uuid REFERENCES public.cycles(id) ON DELETE SET NULL,
  name            text NOT NULL,
  description     text,
  status          text NOT NULL DEFAULT 'open', -- open / closed / archived
  starts_at       timestamp with time zone,
  ends_at         timestamp with time zone,
  created_by      uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at      timestamp with time zone NOT NULL DEFAULT now(),
  updated_at      timestamp with time zone NOT NULL DEFAULT now()
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'swot_quadrant') THEN
    CREATE TYPE public.swot_quadrant AS ENUM ('strengths','weaknesses','opportunities','threats');
  END IF;
END$$;

CREATE TABLE IF NOT EXISTS public.swot_items (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id     uuid NOT NULL REFERENCES public.swot_campaigns(id) ON DELETE CASCADE,
  quadrant        public.swot_quadrant NOT NULL,
  title           text NOT NULL,
  description     text,
  impact          text, -- high / medium / low
  probability     text, -- high / medium / low
  order_index     integer NOT NULL DEFAULT 0,
  created_by      uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at      timestamp with time zone NOT NULL DEFAULT now(),
  updated_at      timestamp with time zone NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.swot_contributions (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id     uuid NOT NULL REFERENCES public.swot_items(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  contribution text NOT NULL,
  created_at  timestamp with time zone NOT NULL DEFAULT now()
);

-- ---------- 6. TOWS crossings ----------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'tows_strategy_type') THEN
    CREATE TYPE public.tows_strategy_type AS ENUM ('so','wo','st','wt');
  END IF;
END$$;

CREATE TABLE IF NOT EXISTS public.tows_crossings (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id     uuid NOT NULL REFERENCES public.swot_campaigns(id) ON DELETE CASCADE,
  strategy_type   public.tows_strategy_type NOT NULL,
  name            text NOT NULL,
  description     text,
  priority        text, -- high / medium / low
  s_item_id       uuid REFERENCES public.swot_items(id) ON DELETE SET NULL,
  w_item_id       uuid REFERENCES public.swot_items(id) ON DELETE SET NULL,
  o_item_id       uuid REFERENCES public.swot_items(id) ON DELETE SET NULL,
  t_item_id       uuid REFERENCES public.swot_items(id) ON DELETE SET NULL,
  created_by      uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at      timestamp with time zone NOT NULL DEFAULT now(),
  updated_at      timestamp with time zone NOT NULL DEFAULT now()
);

-- ---------- 7. riscos e oportunidades ----------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'risk_opportunity_type') THEN
    CREATE TYPE public.risk_opportunity_type AS ENUM ('risk','opportunity');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'risk_opportunity_status') THEN
    CREATE TYPE public.risk_opportunity_status AS ENUM ('identified','analyzing','mitigating','monitored','closed');
  END IF;
END$$;

CREATE TABLE IF NOT EXISTS public.risk_opportunities (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  cycle_id        uuid REFERENCES public.cycles(id) ON DELETE SET NULL,
  reference       text,
  type            public.risk_opportunity_type NOT NULL,
  title           text NOT NULL,
  description     text,
  probability     integer CHECK (probability BETWEEN 1 AND 5),
  impact          integer CHECK (impact BETWEEN 1 AND 5),
  score           integer GENERATED ALWAYS AS (probability * impact) STORED,
  status          public.risk_opportunity_status NOT NULL DEFAULT 'identified',
  mitigation      text,
  responsible_id  uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  due_date        date,
  closed_at       timestamp with time zone,
  created_by      uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at      timestamp with time zone NOT NULL DEFAULT now(),
  updated_at      timestamp with time zone NOT NULL DEFAULT now(),
  UNIQUE (organization_id, reference)
);

-- ---------- 8. objetivos e ações estratégicas ----------
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'strategic_objective_status') THEN
    CREATE TYPE public.strategic_objective_status AS ENUM ('draft','approved','active','achieved','cancelled');
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.strategic_objectives (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  cycle_id        uuid REFERENCES public.cycles(id) ON DELETE SET NULL,
  parent_id       uuid REFERENCES public.strategic_objectives(id) ON DELETE SET NULL,
  code            text NOT NULL,
  name            text NOT NULL,
  description     text,
  perspective     text, -- financial / customer / internal / learning / custom
  weight          numeric(5,2) DEFAULT 1,
  status          public.strategic_objective_status NOT NULL DEFAULT 'draft',
  progress        numeric(5,2) NOT NULL DEFAULT 0,
  responsible_id  uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  start_date      date,
  due_date        date,
  achieved_at     timestamp with time zone,
  created_by      uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at      timestamp with time zone NOT NULL DEFAULT now(),
  updated_at      timestamp with time zone NOT NULL DEFAULT now(),
  UNIQUE (organization_id, code)
);

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'strategic_action_status') THEN
    CREATE TYPE public.strategic_action_status AS ENUM ('todo','in_progress','completed','cancelled');
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.strategic_actions (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  objective_id    uuid NOT NULL REFERENCES public.strategic_objectives(id) ON DELETE CASCADE,
  name            text NOT NULL,
  description     text,
  status          public.strategic_action_status NOT NULL DEFAULT 'todo',
  priority        text, -- critical / high / medium / low
  responsible_id  uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  start_date      date,
  due_date        date,
  completed_at    timestamp with time zone,
  progress        numeric(5,2) NOT NULL DEFAULT 0,
  budget          numeric(12,2),
  actual_cost     numeric(12,2),
  created_by      uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at      timestamp with time zone NOT NULL DEFAULT now(),
  updated_at      timestamp with time zone NOT NULL DEFAULT now()
);

-- ---------- 9. KPIs ----------
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'kpi_direction') THEN
    CREATE TYPE public.kpi_direction AS ENUM ('higher_is_better','lower_is_better','target');
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'kpi_frequency') THEN
    CREATE TYPE public.kpi_frequency AS ENUM ('daily','weekly','monthly','quarterly','yearly');
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.kpis (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  objective_id    uuid REFERENCES public.strategic_objectives(id) ON DELETE SET NULL,
  code            text NOT NULL,
  name            text NOT NULL,
  description     text,
  unit            text,
  direction       public.kpi_direction DEFAULT 'higher_is_better',
  frequency       public.kpi_frequency DEFAULT 'monthly',
  formula         text,
  data_source     text,
  responsible_id  uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  active          boolean NOT NULL DEFAULT true,
  created_by      uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at      timestamp with time zone NOT NULL DEFAULT now(),
  updated_at      timestamp with time zone NOT NULL DEFAULT now(),
  UNIQUE (organization_id, code)
);

CREATE TABLE IF NOT EXISTS public.kpi_targets (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  kpi_id          uuid NOT NULL REFERENCES public.kpis(id) ON DELETE CASCADE,
  period          text NOT NULL, -- YYYY, YYYY-Q1, YYYY-MM, YYYY-WNN
  target_value    numeric(15,4) NOT NULL,
  warning_value   numeric(15,4),
  created_at      timestamp with time zone NOT NULL DEFAULT now(),
  updated_at      timestamp with time zone NOT NULL DEFAULT now(),
  UNIQUE (kpi_id, period)
);

CREATE TABLE IF NOT EXISTS public.kpi_results (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  kpi_id          uuid NOT NULL REFERENCES public.kpis(id) ON DELETE CASCADE,
  period          text NOT NULL,
  value           numeric(15,4) NOT NULL,
  notes           text,
  entered_by      uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  entered_at      timestamp with time zone NOT NULL DEFAULT now(),
  created_at      timestamp with time zone NOT NULL DEFAULT now(),
  updated_at      timestamp with time zone NOT NULL DEFAULT now(),
  UNIQUE (kpi_id, period)
);

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'effectiveness_result') THEN
    CREATE TYPE public.effectiveness_result AS ENUM ('effective','not_effective','pending');
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.effectiveness_evaluations (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  objective_id    uuid REFERENCES public.strategic_objectives(id) ON DELETE SET NULL,
  action_id       uuid REFERENCES public.strategic_actions(id) ON DELETE SET NULL,
  kpi_id          uuid REFERENCES public.kpis(id) ON DELETE SET NULL,
  evaluated_at    timestamp with time zone NOT NULL DEFAULT now(),
  result          public.effectiveness_result NOT NULL DEFAULT 'pending',
  score           numeric(5,2),
  observations    text,
  evidence_links  jsonb DEFAULT '[]'::jsonb,
  evaluated_by    uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at      timestamp with time zone NOT NULL DEFAULT now(),
  updated_at      timestamp with time zone NOT NULL DEFAULT now()
);

-- ---------- 10. projetos ----------
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'project_status') THEN
    CREATE TYPE public.project_status AS ENUM ('draft','planning','active','on_hold','completed','cancelled');
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.projects (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  objective_id    uuid REFERENCES public.strategic_objectives(id) ON DELETE SET NULL,
  code            text NOT NULL,
  name            text NOT NULL,
  description     text,
  status          public.project_status NOT NULL DEFAULT 'draft',
  priority        text,
  responsible_id  uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  start_date      date,
  due_date        date,
  completed_at    timestamp with time zone,
  budget          numeric(12,2),
  actual_cost     numeric(12,2),
  progress        numeric(5,2) NOT NULL DEFAULT 0,
  created_by      uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at      timestamp with time zone NOT NULL DEFAULT now(),
  updated_at      timestamp with time zone NOT NULL DEFAULT now(),
  UNIQUE (organization_id, code)
);

-- ---------- 11. decisões e evidências ----------
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'decision_status') THEN
    CREATE TYPE public.decision_status AS ENUM ('proposed','approved','rejected','implemented');
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.decisions (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  meeting_id      uuid,
  code            text,
  title           text NOT NULL,
  description     text,
  rationale       text,
  status          public.decision_status NOT NULL DEFAULT 'proposed',
  impact_level    text, -- high / medium / low
  decided_by      uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  decided_at      timestamp with time zone,
  implemented_at  timestamp with time zone,
  created_by      uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at      timestamp with time zone NOT NULL DEFAULT now(),
  updated_at      timestamp with time zone NOT NULL DEFAULT now(),
  UNIQUE (organization_id, code)
);

CREATE TABLE IF NOT EXISTS public.evidences (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  decision_id     uuid REFERENCES public.decisions(id) ON DELETE CASCADE,
  objective_id    uuid REFERENCES public.strategic_objectives(id) ON DELETE CASCADE,
  action_id       uuid REFERENCES public.strategic_actions(id) ON DELETE CASCADE,
  kpi_id          uuid REFERENCES public.kpis(id) ON DELETE CASCADE,
  title           text NOT NULL,
  description     text,
  file_url        text,
  file_type       text,
  file_size       bigint,
  uploaded_by     uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at      timestamp with time zone NOT NULL DEFAULT now(),
  updated_at      timestamp with time zone NOT NULL DEFAULT now()
);

-- ---------- 12. reuniões ----------
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'meeting_status') THEN
    CREATE TYPE public.meeting_status AS ENUM ('scheduled','in_progress','completed','cancelled');
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.meetings (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  cycle_id        uuid REFERENCES public.cycles(id) ON DELETE SET NULL,
  title           text NOT NULL,
  description     text,
  meeting_type    text, -- board / strategic / tactical / operational
  status          public.meeting_status NOT NULL DEFAULT 'scheduled',
  scheduled_at    timestamp with time zone NOT NULL,
  duration_min    integer,
  location        text,
  online_url      text,
  minutes         text,
  created_by      uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at      timestamp with time zone NOT NULL DEFAULT now(),
  updated_at      timestamp with time zone NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.meeting_presenters (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  meeting_id  uuid NOT NULL REFERENCES public.meetings(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  topic       text,
  order_index integer NOT NULL DEFAULT 0,
  UNIQUE (meeting_id, user_id)
);

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'submission_status') THEN
    CREATE TYPE public.submission_status AS ENUM ('draft','submitted','under_review','approved','rejected');
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.submissions (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  meeting_id      uuid NOT NULL REFERENCES public.meetings(id) ON DELETE CASCADE,
  objective_id    uuid REFERENCES public.strategic_objectives(id) ON DELETE SET NULL,
  kpi_id          uuid REFERENCES public.kpis(id) ON DELETE SET NULL,
  action_id       uuid REFERENCES public.strategic_actions(id) ON DELETE SET NULL,
  project_id      uuid REFERENCES public.projects(id) ON DELETE SET NULL,
  title           text NOT NULL,
  content         text,
  status          public.submission_status NOT NULL DEFAULT 'draft',
  submitted_by    uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  submitted_at    timestamp with time zone,
  reviewed_by     uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  reviewed_at     timestamp with time zone,
  created_at      timestamp with time zone NOT NULL DEFAULT now(),
  updated_at      timestamp with time zone NOT NULL DEFAULT now()
);

-- add meeting_id FK after meetings exist (self-contained)
ALTER TABLE public.decisions ADD COLUMN IF NOT EXISTS meeting_id uuid REFERENCES public.meetings(id) ON DELETE SET NULL;

-- ---------- 13. apresentações ----------
CREATE TABLE IF NOT EXISTS public.ppt_templates (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  name            text NOT NULL,
  description     text,
  file_path       text,
  thumbnail_url   text,
  is_default      boolean NOT NULL DEFAULT false,
  active          boolean NOT NULL DEFAULT true,
  created_by      uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at      timestamp with time zone NOT NULL DEFAULT now(),
  updated_at      timestamp with time zone NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ppt_layouts (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id     uuid NOT NULL REFERENCES public.ppt_templates(id) ON DELETE CASCADE,
  name            text NOT NULL,
  slide_type      text NOT NULL, -- title / section / content / chart / table / closing
  layout_json     jsonb NOT NULL DEFAULT '{}'::jsonb,
  order_index     integer NOT NULL DEFAULT 0,
  active          boolean NOT NULL DEFAULT true,
  created_at      timestamp with time zone NOT NULL DEFAULT now(),
  updated_at      timestamp with time zone NOT NULL DEFAULT now()
);

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'generated_file_status') THEN
    CREATE TYPE public.generated_file_status AS ENUM ('queued','processing','ready','error');
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.generated_files (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  template_id     uuid REFERENCES public.ppt_templates(id) ON DELETE SET NULL,
  meeting_id      uuid REFERENCES public.meetings(id) ON DELETE SET NULL,
  name            text NOT NULL,
  file_type       text NOT NULL DEFAULT 'pptx',
  file_path       text,
  file_size       bigint,
  status          public.generated_file_status NOT NULL DEFAULT 'queued',
  error_message   text,
  generated_by    uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  generated_at    timestamp with time zone,
  created_at      timestamp with time zone NOT NULL DEFAULT now(),
  updated_at      timestamp with time zone NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.archive_locations (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  name            text NOT NULL,
  description     text,
  location_type   text NOT NULL DEFAULT 'folder', -- folder / bucket / url
  location_path   text,
  active          boolean NOT NULL DEFAULT true,
  created_at      timestamp with time zone NOT NULL DEFAULT now(),
  updated_at      timestamp with time zone NOT NULL DEFAULT now()
);

-- ---------- 14. conectores e app versions ----------
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'connector_status') THEN
    CREATE TYPE public.connector_status AS ENUM ('active','inactive','error');
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.connectors (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  name            text NOT NULL,
  description     text,
  provider        text NOT NULL, -- samsys / phc / sage / powerbi / sharepoint / custom
  config_schema   jsonb DEFAULT '{}'::jsonb,
  active          boolean NOT NULL DEFAULT true,
  created_at      timestamp with time zone NOT NULL DEFAULT now(),
  updated_at      timestamp with time zone NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.connector_instances (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  connector_id    uuid NOT NULL REFERENCES public.connectors(id) ON DELETE CASCADE,
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  name            text NOT NULL,
  credentials     jsonb DEFAULT '{}'::jsonb,
  settings        jsonb DEFAULT '{}'::jsonb,
  status          public.connector_status NOT NULL DEFAULT 'inactive',
  last_sync_at    timestamp with time zone,
  last_error      text,
  created_by      uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at      timestamp with time zone NOT NULL DEFAULT now(),
  updated_at      timestamp with time zone NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.app_versions (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  platform        text NOT NULL, -- web / ios / android / desktop
  version         text NOT NULL,
  release_notes   text,
  min_required    boolean NOT NULL DEFAULT false,
  active          boolean NOT NULL DEFAULT true,
  released_at     timestamp with time zone,
  created_at      timestamp with time zone NOT NULL DEFAULT now(),
  updated_at      timestamp with time zone NOT NULL DEFAULT now(),
  UNIQUE (platform, version)
);

-- ---------- 15. feature flags ----------
CREATE TABLE IF NOT EXISTS public.feature_flags (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  key         text UNIQUE NOT NULL,
  enabled     boolean NOT NULL DEFAULT false,
  created_at  timestamp with time zone NOT NULL DEFAULT now(),
  updated_at  timestamp with time zone NOT NULL DEFAULT now()
);
ALTER TABLE public.feature_flags ADD COLUMN IF NOT EXISTS description text;

-- ---------- triggers set_updated_at ----------
DO $$
DECLARE
  t text;
  tables text[] := ARRAY[
    'organizations','organization_memberships','teams','roles','brand_kits',
    'frameworks','cycles','swot_campaigns','swot_items','tows_crossings',
    'risk_opportunities','strategic_objectives','strategic_actions','kpis',
    'kpi_targets','kpi_results','effectiveness_evaluations','projects',
    'decisions','evidences','meetings','meeting_presenters','submissions',
    'ppt_templates','ppt_layouts','generated_files','archive_locations',
    'connectors','connector_instances','app_versions','feature_flags',
    'swot_contributions'
  ];
BEGIN
  FOREACH t IN ARRAY tables
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS trg_%I_set_updated_at ON public.%I', t, t);
    EXECUTE format('CREATE TRIGGER trg_%I_set_updated_at BEFORE UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.set_updated_at()', t, t);
  END LOOP;
END$$;

-- ---------- índices ----------
CREATE INDEX IF NOT EXISTS idx_org_memberships_org ON public.organization_memberships(organization_id);
CREATE INDEX IF NOT EXISTS idx_org_memberships_user ON public.organization_memberships(user_id);
CREATE INDEX IF NOT EXISTS idx_teams_org ON public.teams(organization_id);
CREATE INDEX IF NOT EXISTS idx_roles_org ON public.roles(organization_id);
CREATE INDEX IF NOT EXISTS idx_brand_kits_org ON public.brand_kits(organization_id);
CREATE INDEX IF NOT EXISTS idx_frameworks_org ON public.frameworks(organization_id);
CREATE INDEX IF NOT EXISTS idx_cycles_org ON public.cycles(organization_id);
CREATE INDEX IF NOT EXISTS idx_swot_campaigns_org ON public.swot_campaigns(organization_id);
CREATE INDEX IF NOT EXISTS idx_swot_items_campaign ON public.swot_items(campaign_id);
CREATE INDEX IF NOT EXISTS idx_tows_crossings_campaign ON public.tows_crossings(campaign_id);
CREATE INDEX IF NOT EXISTS idx_risk_opportunities_org ON public.risk_opportunities(organization_id);
CREATE INDEX IF NOT EXISTS idx_strategic_objectives_org ON public.strategic_objectives(organization_id);
CREATE INDEX IF NOT EXISTS idx_strategic_actions_objective ON public.strategic_actions(objective_id);
CREATE INDEX IF NOT EXISTS idx_kpis_org ON public.kpis(organization_id);
CREATE INDEX IF NOT EXISTS idx_kpi_targets_kpi ON public.kpi_targets(kpi_id);
CREATE INDEX IF NOT EXISTS idx_kpi_results_kpi ON public.kpi_results(kpi_id);
CREATE INDEX IF NOT EXISTS idx_effectiveness_evaluations_org ON public.effectiveness_evaluations(organization_id);
CREATE INDEX IF NOT EXISTS idx_projects_org ON public.projects(organization_id);
CREATE INDEX IF NOT EXISTS idx_decisions_org ON public.decisions(organization_id);
CREATE INDEX IF NOT EXISTS idx_evidences_org ON public.evidences(organization_id);
CREATE INDEX IF NOT EXISTS idx_meetings_org ON public.meetings(organization_id);
CREATE INDEX IF NOT EXISTS idx_generated_files_org ON public.generated_files(organization_id);
CREATE INDEX IF NOT EXISTS idx_connectors_org ON public.connectors(organization_id);
CREATE INDEX IF NOT EXISTS idx_connector_instances_org ON public.connector_instances(organization_id);

-- ---------- RLS ----------
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.brand_kits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.frameworks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cycles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.swot_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.swot_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.swot_contributions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tows_crossings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.risk_opportunities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.strategic_objectives ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.strategic_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kpis ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kpi_targets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kpi_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.effectiveness_evaluations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.decisions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.evidences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meetings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meeting_presenters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ppt_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ppt_layouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.generated_files ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.archive_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.connectors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.connector_instances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feature_flags ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE
  t text;
  tables text[] := ARRAY[
    'organizations','organization_memberships','teams','roles','brand_kits',
    'frameworks','cycles','swot_campaigns','swot_items','swot_contributions',
    'tows_crossings','risk_opportunities','strategic_objectives','strategic_actions',
    'kpis','kpi_targets','kpi_results','effectiveness_evaluations','projects',
    'decisions','evidences','meetings','meeting_presenters','submissions',
    'ppt_templates','ppt_layouts','generated_files','archive_locations',
    'connectors','connector_instances'
  ];
BEGIN
  FOREACH t IN ARRAY tables
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS "%1$s_read" ON public.%1$s', t);
    EXECUTE format('DROP POLICY IF EXISTS "%1$s_write" ON public.%1$s', t);
    EXECUTE format('CREATE POLICY "%1$s_read" ON public.%1$s FOR SELECT TO authenticated USING (true)', t);
    EXECUTE format('CREATE POLICY "%1$s_write" ON public.%1$s FOR ALL TO authenticated USING (public.is_quality_or_admin()) WITH CHECK (public.is_quality_or_admin())', t);
  END LOOP;
END$$;

-- app_versions e feature_flags só admin/quality
DROP POLICY IF EXISTS "app_versions_read" ON public.app_versions;
DROP POLICY IF EXISTS "app_versions_write" ON public.app_versions;
CREATE POLICY "app_versions_read" ON public.app_versions FOR SELECT TO authenticated USING (true);
CREATE POLICY "app_versions_write" ON public.app_versions FOR ALL TO authenticated USING (public.is_quality_or_admin()) WITH CHECK (public.is_quality_or_admin());

DROP POLICY IF EXISTS "feature_flags_read" ON public.feature_flags;
DROP POLICY IF EXISTS "feature_flags_write" ON public.feature_flags;
CREATE POLICY "feature_flags_read" ON public.feature_flags FOR SELECT TO authenticated USING (true);
CREATE POLICY "feature_flags_write" ON public.feature_flags FOR ALL TO authenticated USING (public.is_quality_or_admin()) WITH CHECK (public.is_quality_or_admin());

-- ---------- grants PostgREST ----------
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated;

COMMIT;
