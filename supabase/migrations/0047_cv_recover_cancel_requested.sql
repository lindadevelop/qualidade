-- Corrige a recuperação de jobs de CV: os jobs em CANCEL_REQUESTED que ficaram presos
-- (cancelamento pedido mas o worker/Ollama congelou e nunca evoluiu para CANCELLED)
-- passam a ser concluídos automaticamente após um período de tolerância, saindo da fila.
-- Sem isto, um "cancelar" durante ANALYZING com o Ollama morto deixava o job visível
-- indefinidamente na fila ("a processar").

CREATE OR REPLACE FUNCTION public.cv_recover_stale_jobs(p_interrupted_minutes integer DEFAULT 60)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  n int;
  n2 int;
BEGIN
  -- jobs ativos interrompidos por reinício do servidor -> ERROR (tentar novamente)
  UPDATE public.lifecycle_cv_jobs
     SET status = 'ERROR',
         etapa = 'error',
         error_message = 'Interrompido por reinicio do servidor — use "Tentar novamente".',
         error_details = jsonb_build_object('recovered', true, 'at', now()),
         finished_at = now(),
         updated_at = now()
   WHERE status IN ('QUEUED','UPLOADING','EXTRACTING','OCR','ANALYZING','VALIDATING','DEDUPLICATING','CREATING')
     AND finished_at IS NULL
     AND (COALESCE(started_at, submitted_at)) < now() - make_interval(mins => p_interrupted_minutes);
  GET DIAGNOSTICS n = ROW_COUNT;

  -- CANCEL_REQUESTED pendentes (Ollama congelado no cancelamento): concluir o cancelamento
  -- após tolerância, arquivando o job para deixar de aparecer na fila.
  UPDATE public.lifecycle_cv_jobs
     SET status = 'CANCELLED',
         etapa = 'cancelled',
         finished_at = COALESCE(finished_at, now()),
         cancelled_at = COALESCE(cancel_requested_at, now()),
         arquivado_at = now(),
         viewed = true,
         updated_at = now()
   WHERE status = 'CANCEL_REQUESTED'
     AND cancel_requested_at < now() - make_interval(mins => GREATEST(10, p_interrupted_minutes / 6));
  GET DIAGNOSTICS n2 = ROW_COUNT;

  RETURN n + n2;
END
$$;

GRANT EXECUTE ON FUNCTION public.cv_recover_stale_jobs(integer) TO anon, authenticated, service_role;