-- ============================================================================
-- 0027_cv_recover_stale_jobs.sql  |  Fila CV: recuperação de jobs interrompidos
-- Programa de Qualidade SAMSYS · LifeCycle RH
-- Jobs que ficaram num estado ativo (QUEUED/EXTRACTING/…/CREATING) sem finished_at
-- por mais de N minutos eram quase sempre de um servidor que reiniciou no meio do
-- processamento (o worker local não guarda token para retomar sozinho). Esta função
-- security-definer marca-os como ERROR com mensagem clara ('Tentar novamente'), em
-- vez de os deixar presos para sempre em ANALYZING. O utilizador repõe com o botão
-- 'Tentar novamente' (retry usa o token fresco do request, que o boot não tem).
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.cv_recover_stale_jobs(p_interrupted_minutes int DEFAULT 60)
RETURNS int LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  n int;
BEGIN
  UPDATE public.lifecycle_cv_jobs
     SET status = 'ERROR',
         etapa = 'error',
         error_message = 'Interrompido por reinício do servidor — use “Tentar novamente”.',
         error_details = jsonb_build_object('recovered', true, 'at', now()),
         finished_at = now(),
         updated_at = now()
   WHERE status IN ('QUEUED','UPLOADING','EXTRACTING','OCR','ANALYZING','VALIDATING','DEDUPLICATING','CREATING')
     AND finished_at IS NULL
     AND (COALESCE(started_at, submitted_at)) < now() - make_interval(mins => p_interrupted_minutes);
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;
END $$;

GRANT EXECUTE ON FUNCTION public.cv_recover_stale_jobs(int) TO anon, authenticated;

COMMIT;