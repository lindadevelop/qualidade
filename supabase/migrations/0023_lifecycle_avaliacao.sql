-- ============================================================================
-- 0023_lifecycle_avaliacao.sql  |  Fase 4 — Comparação explicável com a vaga
-- Programa de Qualidade SAMSYS · LifeCycle RH
-- Requisitos da vaga (obrigatórios/preferenciais) + registo de avaliações com
-- pontuação por categoria, evidência e decisão humana separada da IA.
-- ============================================================================

BEGIN;

-- ---------- Requisitos da vaga ----------
ALTER TABLE public.lifecycle_vagas ADD COLUMN IF NOT EXISTS requisitos jsonb DEFAULT '{"obrigatorios": [], "preferenciais": []}'::jsonb;

-- ---------- Tabela: lifecycle_avaliacoes ----------
CREATE TABLE IF NOT EXISTS public.lifecycle_avaliacoes (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  caso_id               uuid NOT NULL REFERENCES public.lifecycle_casos(id) ON DELETE CASCADE,
  vaga_id               uuid REFERENCES public.lifecycle_vagas(id) ON DELETE SET NULL,
  pessoa_id             uuid REFERENCES public.lifecycle_pessoas(id) ON DELETE CASCADE,

  -- pontuação (0-100) e por categoria
  score_global          numeric(5,2),
  score_requisitos      numeric(5,2),   -- obrigatórios
  score_preferenciais   numeric(5,2),
  score_competencias    numeric(5,2),
  score_experiencia     numeric(5,2),
  score_formacao        numeric(5,2),
  score_idiomas         numeric(5,2),
  score_disponibilidade numeric(5,2),

  -- evidência explicável (JSON com justificação por requisito)
  razao                 jsonb DEFAULT '[]'::jsonb,   -- [{requisito, tipo, encontrado, evidencia, origem}]
  competencias_encontradas jsonb DEFAULT '[]'::jsonb,
  competencias_em_falta    jsonb DEFAULT '[]'::jsonb,
  alertas                jsonb DEFAULT '[]'::jsonb,
  perguntas_entrevista   jsonb DEFAULT '[]'::jsonb,

  -- IA vs humano (nunca misturáveis)
  recomendacao_ia        text,          -- favoravel/neutra/desfavoravel (só IA)
  decisao_humana         text,          -- selecionar/recusar/adicional_avaliacao (só humano)
  decisao_humana_em     timestamptz,
  decisao_humana_por    uuid REFERENCES public.profiles(id),
  notas_humanas         text,

  -- controlo
  modelo_ia             text,
  prompt_version        text,
  created_by            uuid REFERENCES public.profiles(id),
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  UNIQUE (caso_id, vaga_id)
);
CREATE INDEX IF NOT EXISTS idx_lice_av_caso ON public.lifecycle_avaliacoes(caso_id);
CREATE INDEX IF NOT EXISTS idx_lice_av_pessoa ON public.lifecycle_avaliacoes(pessoa_id);

-- trigger updated_at
DROP TRIGGER IF EXISTS trg_lice_av_updated_at ON public.lifecycle_avaliacoes;
CREATE TRIGGER trg_lice_av_updated_at BEFORE UPDATE ON public.lifecycle_avaliacoes
  FOR EACH ROW EXECUTE FUNCTION public.set_lifecycle_pessoas_updated_at();

-- RLS (mesmo padrão do módulo)
ALTER TABLE public.lifecycle_avaliacoes ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='lifecycle_avaliacoes' AND policyname='liceav_read_authenticated') THEN
    CREATE POLICY liceav_read_authenticated ON public.lifecycle_avaliacoes
      FOR SELECT USING (public.is_any_authenticated());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='lifecycle_avaliacoes' AND policyname='liceav_write_manage') THEN
    CREATE POLICY liceav_write_manage ON public.lifecycle_avaliacoes
      FOR ALL USING (public.is_quality_or_admin() OR public.is_management())
      WITH CHECK (public.is_quality_or_admin() OR public.is_management());
  END IF;
END $$;

-- ---------- Permissões PostgREST ----------
GRANT SELECT, INSERT, UPDATE, DELETE ON public.lifecycle_avaliacoes TO anon, authenticated;

COMMIT;