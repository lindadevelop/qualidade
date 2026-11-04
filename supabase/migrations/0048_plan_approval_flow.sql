-- Fluxo de aprovação do Plano de Conformidade.
-- ADD COLUMN IF NOT EXISTS (idempotente): aprovador designado + registo da decisão.
ALTER TABLE public.quality_compliance_plans
  ADD COLUMN IF NOT EXISTS aprovador_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS aprovado_em_por timestamp with time zone,  -- (mantido p/ compat; decisão fica em aprovado_por/aprovado_em)
  ADD COLUMN IF NOT EXISTS rejeitado_por uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS rejeitado_em timestamp with time zone,
  ADD COLUMN IF NOT EXISTS motivo_rejeicao text;

COMMENT ON COLUMN public.quality_compliance_plans.aprovador_id IS 'Utilizador designado para aprovar o plano (quem deve aprovar).';
COMMENT ON COLUMN public.quality_compliance_plans.rejeitado_por IS 'Quem rejeitou o plano (decisão).';
COMMENT ON COLUMN public.quality_compliance_plans.motivo_rejeicao IS 'Justificação da rejeição pelo aprovador.';

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.quality_compliance_plans TO anon, authenticated;
GRANT SELECT, UPDATE ON public.quality_compliance_plans TO authenticated;

NOTIFY pgrst, 'reload schema';