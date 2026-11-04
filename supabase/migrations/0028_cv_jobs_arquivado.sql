-- ============================================================================
-- 0028_cv_jobs_arquivado.sql  |  Fila CV: jobs arquivados somem da fila
-- Programa de Qualidade SAMSYS · LifeCycle RH
-- Quando o utilizador VALIDA e grava a ficha, ou CANCELA, o job deve sair da
-- lista ativa da fila. Coluna arquivado_at: preenchida fecha-o sem perder o
-- histórico (auditoria). A UI filtra jobs arquivados por omissão.
-- ============================================================================

BEGIN;
ALTER TABLE public.lifecycle_cv_jobs ADD COLUMN IF NOT EXISTS arquivado_at timestamptz;
CREATE INDEX IF NOT EXISTS idx_lcj_arquivado ON public.lifecycle_cv_jobs(arquivado_at);
COMMIT;