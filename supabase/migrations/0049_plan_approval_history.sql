-- Histórico de aprovação do Plano de Conformidade.
-- Guarda cada decisão (aprovado/rejeitado/desaprovado) como registo imutável, para
-- rastreio completo "quem decidiu, quando e porquê". O frontend escreve aqui via REST.
CREATE TABLE IF NOT EXISTS public.quality_plan_approval_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id uuid NOT NULL REFERENCES public.quality_compliance_plans(id) ON DELETE CASCADE,
  acao text NOT NULL CHECK (acao IN ('APROVADO','REJEITADO','DESAPROVADO','MARCADO_MANUAL')),
  decidido_por uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  decidido_em timestamp with time zone NOT NULL DEFAULT now(),
  motivo text,
  papel text,
  plan_status text,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_plan_approval_events_plan ON public.quality_plan_approval_events(plan_id);

ALTER TABLE public.quality_plan_approval_events ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS plan_approval_events_select ON public.quality_plan_approval_events;
CREATE POLICY plan_approval_events_select ON public.quality_plan_approval_events
  FOR SELECT USING (true);
DROP POLICY IF EXISTS plan_approval_events_insert ON public.quality_plan_approval_events;
CREATE POLICY plan_approval_events_insert ON public.quality_plan_approval_events
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.quality_plan_approval_events TO authenticated;
GRANT SELECT ON TABLE public.quality_plan_approval_events TO anon;

NOTIFY pgrst, 'reload schema';