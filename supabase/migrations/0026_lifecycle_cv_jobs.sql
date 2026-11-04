-- ============================================================================
-- 0026_lifecycle_cv_jobs.sql  |  Fila de processamento assíncrono de CVs
-- Programa de Qualidade SAMSYS · LifeCycle RH
-- Fila PERSISTENTE (BD), nunca só no frontend: sobrevive ao fecho do popup,
-- atualização da página, fecho do navegador e nova autenticação. Cada CV é um
-- job independente; o worker em background executa extração→OCR→Ollama→validação→
-- duplicados→criação da ficha e atualiza o estado em cada etapa.
-- ============================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.lifecycle_cv_jobs (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id        uuid,                                   -- isolamento por empresa (rh/kw): coluna de empresa
  user_id           uuid REFERENCES public.profiles(id),   -- quem enviou
  file_name         text NOT NULL,                          -- nome original
  file_path         text NOT NULL,                          -- caminho seguro em data/uploads/<hash>.pdf
  file_hash         text,                                   -- sha256 para deteção de reenvio
  file_size         bigint,
  file_mime         text DEFAULT 'application/pdf',
  status            text NOT NULL DEFAULT 'QUEUED',
  -- etapas: QUEUED|UPLOADING|EXTRACTING|OCR|ANALYZING|VALIDATING|DEDUPLICATING|CREATING|DONE|DONE_WARN|ERROR|CANCEL_REQUESTED|CANCELLED
  etapa             text DEFAULT 'queued',
  progress          numeric(5,2) DEFAULT 0,                 -- 0-100 real
  attempt           int DEFAULT 0,
  submitted_at      timestamptz DEFAULT now(),
  queued_at         timestamptz,
  started_at        timestamptz,
  finished_at       timestamptz,
  duration_ms       bigint,
  model_ia          text,                                   -- modelo Ollama usado
  prompt_version    text,
  caso_id           uuid,                                   -- candidatura criada/atualizada
  pessoa_id         uuid,                                   -- ficha criada/atualizada
  vaga_id           uuid,                                   -- vaga associada, quando existir
  extracted_text    text,                                   -- texto extraído (para validação/avaliar vs vaga)
  analysis_json     jsonb,                                  -- JSON estruturado do Ollama
  duplicated_of      uuid,                                  -- ficha duplicada detetada (requer validação)
  error_message     text,
  error_details     jsonb,
  cancel_requested_by uuid,
  cancel_requested_at timestamptz,
  cancelled_by      uuid,
  cancelled_at      timestamptz,
  viewed            boolean DEFAULT false,                  -- marcado como visto pelo utilizador
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_lcj_status ON public.lifecycle_cv_jobs(status);
CREATE INDEX IF NOT EXISTS idx_lcj_user ON public.lifecycle_cv_jobs(user_id);
CREATE INDEX IF NOT EXISTS idx_lcj_created ON public.lifecycle_cv_jobs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_lcj_hash ON public.lifecycle_cv_jobs(file_hash);

-- trigger updated_at
DROP TRIGGER IF EXISTS trg_lcj_updated_at ON public.lifecycle_cv_jobs;
CREATE TRIGGER trg_lcj_updated_at BEFORE UPDATE ON public.lifecycle_cv_jobs
  FOR EACH ROW EXECUTE FUNCTION public.set_lifecycle_pessoas_updated_at();

-- RLS (padrão do módulo): leitura/escrita para autenticados; worker acede via token do utilizador.
ALTER TABLE public.lifecycle_cv_jobs ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='lifecycle_cv_jobs' AND policyname='lcj_read_authenticated') THEN
    CREATE POLICY lcj_read_authenticated ON public.lifecycle_cv_jobs
      FOR SELECT USING (public.is_any_authenticated());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='lifecycle_cv_jobs' AND policyname='lcj_write_owner') THEN
    CREATE POLICY lcj_write_owner ON public.lifecycle_cv_jobs
      FOR ALL USING (public.is_any_authenticated())
      WITH CHECK ((user_id = auth.uid()) OR (public.is_quality_or_admin() OR public.is_management()));
  END IF;
END $$;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.lifecycle_cv_jobs TO anon, authenticated;

COMMIT;