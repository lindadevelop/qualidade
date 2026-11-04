-- ============================================================
-- FASE 1 · Copiloto Operacional de Qualidade (doc Prompt_Hermes_MCP_Qualidade_Life_Cycle)
-- Aditivo e idempotente — NÃO quebra o schema existente.
-- 1) tipos de ação 2) Planos de Conformidade 3) ações operacionais
-- 4) registos de trabalho/horas 5) histórico de progresso 6) dependências
-- ============================================================
BEGIN;

-- ---------- 1a) expandir estado das ações (aditivo: não renomeia os existentes) ----------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumtypid = 'public.action_status'::regtype AND enumlabel = 'BLOCKED') THEN
    ALTER TYPE public.action_status ADD VALUE IF NOT EXISTS 'BLOCKED';
  END IF;
END$$;
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumtypid = 'public.action_status'::regtype AND enumlabel = 'VALIDATING') THEN
    ALTER TYPE public.action_status ADD VALUE IF NOT EXISTS 'VALIDATING';
  END IF;
END$$;
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumtypid = 'public.action_status'::regtype AND enumlabel = 'CANCELLED') THEN
    ALTER TYPE public.action_status ADD VALUE IF NOT EXISTS 'CANCELLED';
  END IF;
END$$;

-- ---------- 1b) tipo de ação ----------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'action_type') THEN
    CREATE TYPE public.action_type AS ENUM (
      'CONTENCAO', 'CORRETIVA', 'PREVENTIVA', 'MELHORIA', 'FORMACAO',
      'ALTERACAO_DOCUMENTAL', 'ALTERACAO_PROCESSO', 'VERIFICACAO',
      'VALIDACAO_EFICACIA', 'OUTRA'
    );
  END IF;
END$$;

-- ---------- 1c) estado do Plano de Conformidade ----------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'compliance_plan_status') THEN
    CREATE TYPE public.compliance_plan_status AS ENUM (
      'RASCUNHO', 'PROPOSTO', 'ATIVO', 'BLOQUEADO', 'EM_VALIDACAO', 'CONCLUIDO', 'CANCELADO'
    );
  END IF;
END$$;

-- ---------- 2) tabela Plano de Conformidade ----------
CREATE TABLE IF NOT EXISTS public.quality_compliance_plans (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  occurrence_id         uuid NOT NULL REFERENCES public.quality_occurrences(id) ON DELETE CASCADE,
  codigo                text,
  versao                integer NOT NULL DEFAULT 1,
  titulo                text,
  descricao             text,
  status                public.compliance_plan_status NOT NULL DEFAULT 'RASCUNHO',
  progresso             numeric(5,2) NOT NULL DEFAULT 0,
  progresso_origem      text DEFAULT 'manual',     -- 'manual' | 'ponderada' | 'media'
  esforco_previsto_h    numeric(8,2),
  esforco_real_h        numeric(8,2),
  responsavel_id        uuid,
  data_inicio           date,
  data_prevista_fim     date,
  data_conclusao        timestamp with time zone,
  aprovado_por          uuid,
  aprovado_em           timestamp with time zone,
  requer_aprovacao      boolean NOT NULL DEFAULT false,
  plan_principal        boolean NOT NULL DEFAULT true,  -- plano principal vs complementar
  concluido_ai_validado  boolean NOT NULL DEFAULT false, -- 100% não basta: exige validação de eficácia
  origem                text DEFAULT 'manual',        -- 'manual' | 'ia'
  sugerido_por_ia       boolean NOT NULL DEFAULT false,
  created_by            uuid,
  created_at            timestamp with time zone NOT NULL DEFAULT now(),
  updated_at            timestamp with time zone NOT NULL DEFAULT now()
);

-- índice para consultas por ocorrência/estado
CREATE INDEX IF NOT EXISTS idx_cplans_occurrence ON public.quality_compliance_plans(occurrence_id);
CREATE INDEX IF NOT EXISTS idx_cplans_status ON public.quality_compliance_plans(status);

-- ---------- 2b) dependências do plano (complementares/versões) ----------
CREATE TABLE IF NOT EXISTS public.quality_compliance_plan_links (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id            uuid NOT NULL REFERENCES public.quality_compliance_plans(id) ON DELETE CASCADE,
  related_plan_id    uuid NOT NULL REFERENCES public.quality_compliance_plans(id) ON DELETE CASCADE,
  relacao            text DEFAULT 'complementar',   -- 'complementar' | 'versao_de' | 'substituto'
  seu_id             uuid REFERENCES public.profiles(id),
  criado_em          timestamp with time zone NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_cplan_links ON public.quality_compliance_plan_links(plan_id, related_plan_id, relacao);

-- ---------- 3) evoluir ações com campos operacionais (aditivo) ----------
ALTER TABLE public.quality_actions ADD COLUMN IF NOT EXISTS plano_id uuid REFERENCES public.quality_compliance_plans(id) ON DELETE SET NULL;
ALTER TABLE public.quality_actions ADD COLUMN IF NOT EXISTS titulo text;
ALTER TABLE public.quality_actions ADD COLUMN IF NOT EXISTS tipo public.action_type;
ALTER TABLE public.quality_actions ADD COLUMN IF NOT EXISTS resultado_esperado text;
ALTER TABLE public.quality_actions ADD COLUMN IF NOT EXISTS resultado_real text;
ALTER TABLE public.quality_actions ADD COLUMN IF NOT EXISTS prioridade text;            -- Critica/Alta/Média/Baixa
ALTER TABLE public.quality_actions ADD COLUMN IF NOT EXISTS criticidade text;
ALTER TABLE public.quality_actions ADD COLUMN IF NOT EXISTS colaboradores jsonb;        -- [uuid]
ALTER TABLE public.quality_actions ADD COLUMN IF NOT EXISTS data_inicio date;
ALTER TABLE public.quality_actions ADD COLUMN IF NOT EXISTS horas_previstas numeric(8,2);
ALTER TABLE public.quality_actions ADD COLUMN IF NOT EXISTS horas_realizadas numeric(8,2) NOT NULL DEFAULT 0;
ALTER TABLE public.quality_actions ADD COLUMN IF NOT EXISTS percent_execucao numeric(5,2) NOT NULL DEFAULT 0;
ALTER TABLE public.quality_actions ADD COLUMN IF NOT EXISTS progresso_origem text DEFAULT 'manual';
ALTER TABLE public.quality_actions ADD COLUMN IF NOT EXISTS checklist jsonb;             -- [{item, feito, por}]
ALTER TABLE public.quality_actions ADD COLUMN IF NOT EXISTS evidencias_obrigatorias boolean DEFAULT false;
ALTER TABLE public.quality_actions ADD COLUMN IF NOT EXISTS requer_aprovacao boolean DEFAULT false;
ALTER TABLE public.quality_actions ADD COLUMN IF NOT EXISTS aprovado_por uuid;
ALTER TABLE public.quality_actions ADD COLUMN IF NOT EXISTS aprovado_em timestamp with time zone;
ALTER TABLE public.quality_actions ADD COLUMN IF NOT EXISTS verificar_eficacia boolean DEFAULT false;
ALTER TABLE public.quality_actions ADD COLUMN IF NOT EXISTS eficacia_validada boolean DEFAULT false;
ALTER TABLE public.quality_actions ADD COLUMN IF NOT EXISTS eficacia_validada_por uuid;
ALTER TABLE public.quality_actions ADD COLUMN IF NOT EXISTS eficacia_validada_em timestamp with time zone;
ALTER TABLE public.quality_actions ADD COLUMN IF NOT EXISTS origem text DEFAULT 'manual';
ALTER TABLE public.quality_actions ADD COLUMN IF NOT EXISTS proposta_por_ia boolean DEFAULT false;
ALTER TABLE public.quality_actions ADD COLUMN IF NOT EXISTS bloqueio_motivo text;
ALTER TABLE public.quality_actions ADD COLUMN IF NOT EXISTS cancelled_at timestamp with time zone;
ALTER TABLE public.quality_actions ADD COLUMN IF NOT EXISTS cancelled_by uuid;
ALTER TABLE public.quality_actions ADD COLUMN IF NOT EXISTS next_step text;

CREATE INDEX IF NOT EXISTS idx_actions_plano ON public.quality_actions(plano_id);
CREATE INDEX IF NOT EXISTS idx_actions_tipo ON public.quality_actions(tipo);
CREATE INDEX IF NOT EXISTS idx_actions_deadline ON public.quality_actions(deadline);
CREATE INDEX IF NOT EXISTS idx_actions_status ON public.quality_actions(status);

-- ---------- 4) registo de trabalho e horas ----------
CREATE TABLE IF NOT EXISTS public.quality_work_logs (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  action_id          uuid NOT NULL REFERENCES public.quality_actions(id) ON DELETE CASCADE,
  logged_by          uuid NOT NULL,
  work_date          timestamp with time zone NOT NULL DEFAULT now(),
  descricao          text,
  horas              numeric(6,2) NOT NULL DEFAULT 0,   -- pode ser minutos/60
  minutos            integer NOT NULL DEFAULT 0,
  percent_antes      numeric(5,2),
  percent_depois     numeric(5,2),
  bloqueio           text,
  next_step          text,
  created_at         timestamp with time zone NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_worklogs_action ON public.quality_work_logs(action_id);
CREATE INDEX IF NOT EXISTS idx_worklogs_by ON public.quality_work_logs(logged_by);

-- ---------- 5) histórico de progresso ----------
CREATE TABLE IF NOT EXISTS public.quality_progress_history (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type  text NOT NULL,                          -- 'action' | 'plan'
  entity_id    uuid NOT NULL,
  percent_antes numeric(5,2),
  percent_depois numeric(5,2),
  origem       text DEFAULT 'manual',                  -- 'manual' | 'subtarefas' | 'ia'
  changed_by   uuid,
  created_at   timestamp with time zone NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_proghist_entity ON public.quality_progress_history(entity_type, entity_id);

-- ---------- 6) dependências entre ações ----------
CREATE TABLE IF NOT EXISTS public.quality_action_dependencies (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  action_id      uuid NOT NULL REFERENCES public.quality_actions(id) ON DELETE CASCADE,
  depends_on_id  uuid NOT NULL REFERENCES public.quality_actions(id) ON DELETE CASCADE,
  tipo           text DEFAULT 'bloqueante',            -- 'bloqueante' | 'paralela' | 'sucessora'
  created_at     timestamp with time zone NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_action_dep ON public.quality_action_dependencies(action_id, depends_on_id);

-- ---------- 7) estender anexos/comentários com plano ----------
ALTER TABLE public.quality_attachments ADD COLUMN IF NOT EXISTS plano_id uuid REFERENCES public.quality_compliance_plans(id) ON DELETE CASCADE;
ALTER TABLE public.quality_comments ADD COLUMN IF NOT EXISTS plano_id uuid REFERENCES public.quality_compliance_plans(id) ON DELETE CASCADE;
ALTER TABLE public.quality_comments ADD COLUMN IF NOT EXISTS origem text DEFAULT 'manual';  -- 'manual' | 'ia' | 'mcp'
CREATE INDEX IF NOT EXISTS idx_attachments_plano ON public.quality_attachments(plano_id);
CREATE INDEX IF NOT EXISTS idx_comments_plano ON public.quality_comments(plano_id);

-- ---------- 8) função de updated_at genérica (reutiliza o padrão existente) ----------
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'set_quality_cplans_updated_at') THEN
    CREATE TRIGGER set_quality_cplans_updated_at BEFORE UPDATE ON public.quality_compliance_plans
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
  END IF;
END$$;

-- ---------- 9) grants (espelha as tabelas quality_ existentes) ----------
GRANT SELECT, INSERT, UPDATE, DELETE ON public.quality_compliance_plans TO anon, authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.quality_compliance_plan_links TO anon, authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.quality_work_logs TO anon, authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.quality_progress_history TO anon, authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.quality_action_dependencies TO anon, authenticated, service_role;

COMMIT;

-- recarregar o catálogo do PostgREST
NOTIFY pgrst, 'reload schema';