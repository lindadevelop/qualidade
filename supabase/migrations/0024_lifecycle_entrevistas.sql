-- ============================================================================
-- 0024_lifecycle_entrevistas.sql  |  Fase 5 — Entrevistas e pool de talento
-- Programa de Qualidade SAMSYS · LifeCycle RH
-- Registo de entrevistas com agendamento, entrevistadores, avaliação e notas,
-- ligado à candidatura. Suporta histórico de alterações (audit via entradas).
-- ============================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.lifecycle_entrevistas (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  caso_id           uuid NOT NULL REFERENCES public.lifecycle_casos(id) ON DELETE CASCADE,
  tipo              text NOT NULL DEFAULT 'entrevista',   -- entrevista/tecnico/hr/final
  data_hora         timestamptz,
  duracao_min       integer,
  local_ou_ligacao  text,
  entrevistadores   jsonb DEFAULT '[]'::jsonb,   -- [uuid do profile / nome]
  guiao             text,
  criterios         jsonb DEFAULT '[]'::jsonb,   -- [{criterio, classificacao 0-10, notas}]
  classificacao_geral numeric(4,2),
  notas_privadas    text,                          -- nunca enviadas ao Ollama por defeito
  parecer           text,                          -- favoravel/neutro/desfavoravel
  proximos_passos   text,
  criado_por        uuid REFERENCES public.profiles(id),
  criado_em         timestamptz NOT NULL DEFAULT now(),
  atualizado_em     timestamptz NOT NULL DEFAULT now(),
  UNIQUE (id)
);
CREATE INDEX IF NOT EXISTS idx_lice_ent_caso ON public.lifecycle_entrevistas(caso_id);
CREATE INDEX IF NOT EXISTS idx_lice_ent_data ON public.lifecycle_entrevistas(data_hora);

-- trigger updated_at
DROP TRIGGER IF EXISTS trg_lice_ent_updated_at ON public.lifecycle_entrevistas;
CREATE TRIGGER trg_lice_ent_updated_at BEFORE UPDATE ON public.lifecycle_entrevistas
  FOR EACH ROW EXECUTE FUNCTION public.set_lifecycle_pessoas_updated_at();

-- RLS (padrão do módulo)
ALTER TABLE public.lifecycle_entrevistas ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='lifecycle_entrevistas' AND policyname='liceent_read_authenticated') THEN
    CREATE POLICY liceent_read_authenticated ON public.lifecycle_entrevistas
      FOR SELECT USING (public.is_any_authenticated());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='lifecycle_entrevistas' AND policyname='liceent_write_manage') THEN
    CREATE POLICY liceent_write_manage ON public.lifecycle_entrevistas
      FOR ALL USING (public.is_quality_or_admin() OR public.is_management())
      WITH CHECK (public.is_quality_or_admin() OR public.is_management());
  END IF;
END $$;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.lifecycle_entrevistas TO anon, authenticated;

COMMIT;