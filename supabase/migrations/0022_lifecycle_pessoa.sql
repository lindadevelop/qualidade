-- ============================================================================
-- 0022_lifecycle_pessoa.sql  |  Fase 1 — Pessoa radicada vs Candidatura
-- Programa de Qualidade SAMSYS · LifeCycle RH
-- Objetivo: distinguir a PESSOA (dados permanentes) da CANDIDATURA (processo
-- por vaga). Preserva todos os casos existentes e o fluxo atual.
-- ============================================================================

BEGIN;

-- ---------- Tabela: lifecycle_pessoas (ficha completa) ----------
CREATE TABLE IF NOT EXISTS public.lifecycle_pessoas (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Identificação (4.1)
  nome_completo           text NOT NULL,
  nome_preferido          text,
  fotografia_url          text,                 -- só fornecida e autorizada
  data_nascimento         date,
  nacionalidade           text,
  pais_residencia         text,
  distrito                text,
  concelho                text,
  localidade              text,
  codigo_postal           text,
  morada                  text,
  pronome                 text,
  numero_interno          text,
  estado_ficha            text NOT NULL DEFAULT 'ATIVA' CHECK (estado_ficha IN ('ATIVA','INATIVA','CONTRATADA','ELIMINADA','ANONIMIZADA')),

  -- Contactos e presença profissional (4.2)
  email                   text,
  email_alternativo       text,
  indicativo_telefone     text,
  telefone                text,
  telefone_alternativo    text,
  linkedin                text,
  github                  text,
  portfolio               text,
  website                 text,
  outros_links            jsonb DEFAULT '[]'::jsonb,
  canal_contacto_pref     text,
  consentimento_contactos boolean NOT NULL DEFAULT false,

  -- Situação profissional e disponibilidade (4.3)
  titulo_atual            text,
  empresa_atual           text,
  area_profissional       text,
  senioridade             text,
  anos_experiencia        numeric,
  situacao_atual          text,                 -- empregado/desempregado/estudante/freelancer/outro
  disponibilidade_inicio  text,
  prazo_pre_aviso         text,
  regime                  text,                 -- presencial/hibrido/remoto
  tipo_vinculo_pretendido text,
  disponibilidade_geo     text,
  disponibilidade_desloc  boolean,
  disponibilidade_viagem  boolean,
  disponibilidade_mudar   boolean,
  carta_conducao          boolean,
  viatura_propria         boolean,
  autorizado_trabalhar_pt boolean,

  -- Resumo profissional (4.4)
  resumo_original         text,
  resumo_gerado_ia        text,
  perfil                  text,
  areas_experiencia       jsonb DEFAULT '[]'::jsonb,
  competencias_principais jsonb DEFAULT '[]'::jsonb,
  objetivos_profissionais text,
  setores                 jsonb DEFAULT '[]'::jsonb,
  pontos_fortes           jsonb DEFAULT '[]'::jsonb,
  info_em_falta           jsonb DEFAULT '[]'::jsonb,
  perguntas_entrevista    jsonb DEFAULT '[]'::jsonb,

  -- Preferências profissionais (4.11) — declaradas, IA nunca presume
  funcoes_pretendidas     jsonb DEFAULT '[]'::jsonb,
  areas_pretendidas       jsonb DEFAULT '[]'::jsonb,
  expectativa_salarial    numeric,
  moeda                   text DEFAULT 'EUR',
  periodicidade_salarial  text,
  beneficios              jsonb DEFAULT '[]'::jsonb,
  horario                 text,
  regime_pretendido       text,
  localizacao_pretendida  text,
  contrato_pretendido     text,

  -- Controlo e auditoria
  cv_hash                 text,
  cv_ultima_url           text,
  duplicados_fundidos     jsonb DEFAULT '[]'::jsonb,
  notas_internas          text,
  created_by              uuid REFERENCES public.profiles(id),
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_lice_pessoas_email ON public.lifecycle_pessoas(email);
CREATE INDEX IF NOT EXISTS idx_lice_pessoas_nome ON public.lifecycle_pessoas(nome_completo);
CREATE INDEX IF NOT EXISTS idx_lice_pessoas_telefone ON public.lifecycle_pessoas(telefone);
CREATE INDEX IF NOT EXISTS idx_lice_pessoas_cv_hash ON public.lifecycle_pessoas(cv_hash);

-- ---------- Coluna pessoa_id na candidatura ----------
ALTER TABLE public.lifecycle_casos ADD COLUMN IF NOT EXISTS pessoa_id uuid REFERENCES public.lifecycle_pessoas(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_lifecycle_casos_pessoa ON public.lifecycle_casos(pessoa_id);

-- trigger updated_at de pessoa
CREATE OR REPLACE FUNCTION public.set_lifecycle_pessoas_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS trg_lifecycle_pessoas_updated_at ON public.lifecycle_pessoas;
CREATE TRIGGER trg_lifecycle_pessoas_updated_at BEFORE UPDATE ON public.lifecycle_pessoas
  FOR EACH ROW EXECUTE FUNCTION public.set_lifecycle_pessoas_updated_at();

-- RLS: mesmo padrão do resto do módulo (qualquer utilizador autenticado lê; gestão/qualidade escreve)
ALTER TABLE public.lifecycle_pessoas ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='lifecycle_pessoas' AND policyname='licpessoas_read_authenticated') THEN
    CREATE POLICY licpessoas_read_authenticated ON public.lifecycle_pessoas
      FOR SELECT USING (public.is_any_authenticated());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='lifecycle_pessoas' AND policyname='licpessoas_write_manage') THEN
    CREATE POLICY licpessoas_write_manage ON public.lifecycle_pessoas
      FOR ALL USING (public.is_quality_or_admin() OR public.is_management())
      WITH CHECK (public.is_quality_or_admin() OR public.is_management());
  END IF;
END $$;

-- ---------- Migração dos casos existentes -> Pessoa ----------
-- Cria uma pessoa por caso existente (email+nome), preservando os dados.
-- Se dois casos tiverem o mesmo email, o segundo reutiliza a MESMA pessoa.
DO $$
DECLARE
  c RECORD;
  pid uuid;
BEGIN
  FOR c IN
    SELECT id, nome, email, telefone, dados, cv_url, created_by, created_at
    FROM public.lifecycle_casos
    ORDER BY created_at ASC
  LOOP
    pid := NULL;
    IF c.email IS NOT NULL AND btrim(c.email) <> '' THEN
      SELECT id INTO pid FROM public.lifecycle_pessoas
        WHERE lower(coalesce(email,'')) = lower(btrim(c.email)) LIMIT 1;
    END IF;
    IF pid IS NULL AND c.nome IS NOT NULL AND btrim(c.nome) <> '' THEN
      SELECT id INTO pid FROM public.lifecycle_pessoas
        WHERE lower(nome_completo) = lower(btrim(c.nome)) LIMIT 1;
    END IF;
    IF pid IS NULL THEN
      INSERT INTO public.lifecycle_pessoas
        (nome_completo, email, telefone, cv_hash, cv_ultima_url, resumo_original,
         competencias_principais, areas_experiencia, created_by, created_at)
      VALUES
        (coalesce(btrim(c.nome),'Candidato'),
         nullif(btrim(coalesce(c.email,'')),''),
         nullif(btrim(coalesce(c.telefone,'')),''),
         c.cv_url, c.cv_url,
         coalesce(c.dados->>'resumo', c.dados->>'objetivos'),
         coalesce(c.dados->'competencias', '[]'::jsonb),
         coalesce(c.dados->'areas_experiencia','[]'::jsonb),
         c.created_by, coalesce(c.created_at, now()))
      RETURNING id INTO pid;
    END IF;
    UPDATE public.lifecycle_casos SET pessoa_id = pid WHERE id = c.id;
  END LOOP;
  RAISE NOTICE 'Pessoas criadas/migradas a partir dos casos existentes.';
END $$;

-- ---------- Tabelas de detalhe estruturado (Fases 4.5-4.10) ----------
-- Experiência profissional (4.5)
CREATE TABLE IF NOT EXISTS public.lifecycle_experiencias (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pessoa_id    uuid NOT NULL REFERENCES public.lifecycle_pessoas(id) ON DELETE CASCADE,
  empresa      text NOT NULL,
  cargo        text,
  local        text,
  data_inicio  date,
  data_fim     date,
  emprego_atual boolean NOT NULL DEFAULT false,
  duracao_meses integer,
  descricao    text,
  responsabilidades jsonb DEFAULT '[]'::jsonb,
  projetos     jsonb DEFAULT '[]'::jsonb,
  tecnologias  jsonb DEFAULT '[]'::jsonb,
  ferramentas  jsonb DEFAULT '[]'::jsonb,
  resultados   text,
  setor        text,
  tipo_vinculo text,
  origem_dado  text NOT NULL DEFAULT 'introducao_manual',  -- cv/formulario/entrevista/introducao_manual
  data_inicio_parcial text,
  data_fim_parcial    text,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_lice_exp_pessoa ON public.lifecycle_experiencias(pessoa_id);

-- Formação académica (4.6)
CREATE TABLE IF NOT EXISTS public.lifecycle_formacoes (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pessoa_id    uuid NOT NULL REFERENCES public.lifecycle_pessoas(id) ON DELETE CASCADE,
  grau         text,
  curso        text,
  area_estudo  text,
  instituicao  text,
  pais_local   text,
  data_inicio  date,
  data_conclusao date,
  data_inicio_parcial text,
  data_fim_parcial text,
  estado       text DEFAULT 'concluido',      -- concluido/em_curso/interrompido
  classificacao text,
  observacoes  text,
  equivalencia text,
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_lice_form_pessoa ON public.lifecycle_formacoes(pessoa_id);

-- Certificações (4.7)
CREATE TABLE IF NOT EXISTS public.lifecycle_certificacoes (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pessoa_id    uuid NOT NULL REFERENCES public.lifecycle_pessoas(id) ON DELETE CASCADE,
  nome         text NOT NULL,
  entidade     text,
  data_emissao date,
  validade     date,
  identificador text,
  link_validacao text,
  competencias jsonb DEFAULT '[]'::jsonb,
  estado_validade text,
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_lice_cert_pessoa ON public.lifecycle_certificacoes(pessoa_id);

-- Competências (4.8)
CREATE TABLE IF NOT EXISTS public.lifecycle_competencias (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pessoa_id    uuid NOT NULL REFERENCES public.lifecycle_pessoas(id) ON DELETE CASCADE,
  nome         text NOT NULL,
  categoria    text,       -- tecnica/ferramenta/linguagem/framework/bd/plataforma/metodologia/funcional/comportamental
  nivel_indicado text,     -- nunca inventado pela IA
  anos_experiencia numeric,
  ultima_utilizacao date,
  origem_dado  text NOT NULL DEFAULT 'introducao_manual',
  confirmado   boolean NOT NULL DEFAULT false,
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_lice_comp_pessoa ON public.lifecycle_competencias(pessoa_id);

-- Idiomas (4.9)
CREATE TABLE IF NOT EXISTS public.lifecycle_idiomas (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pessoa_id    uuid NOT NULL REFERENCES public.lifecycle_pessoas(id) ON DELETE CASCADE,
  idioma       text NOT NULL,
  nivel_global text,
  compreensao  text,
  conversacao  text,
  escrita      text,
  certificacao text,
  nivel_cefr   text,
  lingua_materna boolean NOT NULL DEFAULT false,
  origem_dado  text NOT NULL DEFAULT 'introducao_manual',
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_lice_idio_pessoa ON public.lifecycle_idiomas(pessoa_id);

-- Projetos / portefólio (4.10)
CREATE TABLE IF NOT EXISTS public.lifecycle_projetos (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pessoa_id    uuid NOT NULL REFERENCES public.lifecycle_pessoas(id) ON DELETE CASCADE,
  nome         text NOT NULL,
  descricao    text,
  papel        text,
  tecnologias  jsonb DEFAULT '[]'::jsonb,
  data         date,
  link         text,
  resultados   text,
  tipo         text DEFAULT 'profissional',   -- pessoal/academico/profissional
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_lice_proj_pessoa ON public.lifecycle_projetos(pessoa_id);

-- Referências (4.12)
CREATE TABLE IF NOT EXISTS public.lifecycle_referencias (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pessoa_id    uuid NOT NULL REFERENCES public.lifecycle_pessoas(id) ON DELETE CASCADE,
  nome         text NOT NULL,
  empresa      text,
  cargo        text,
  relacao      text,
  contacto     text,
  autorizacao  boolean NOT NULL DEFAULT false,
  estado_verificacao text DEFAULT 'por_verificar',
  notas        text,
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_lice_ref_pessoa ON public.lifecycle_referencias(pessoa_id);

-- ---------- Permissões (PostgREST / roles anon e authenticated) ----------
-- O RLS de cada tabela restringe dentro da role; aqui garantimos a exposição via API.
GRANT SELECT, INSERT, UPDATE, DELETE ON public.lifecycle_pessoas TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.lifecycle_experiencias TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.lifecycle_formacoes TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.lifecycle_certificacoes TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.lifecycle_competencias TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.lifecycle_idiomas TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.lifecycle_projetos TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.lifecycle_referencias TO anon, authenticated;

COMMIT;