-- ============================================================
-- Seed v1.5 · Plataforma Estratégica Samsys
-- Idempotente: limpa apenas tabelas do módulo estratégico
-- e recria dados demo para Samsys + AcmeCorp.
-- ============================================================
BEGIN;

TRUNCATE TABLE public.swot_contributions CASCADE;
TRUNCATE TABLE public.tows_crossings CASCADE;
TRUNCATE TABLE public.swot_items CASCADE;
TRUNCATE TABLE public.swot_campaigns CASCADE;
TRUNCATE TABLE public.risk_opportunities CASCADE;
TRUNCATE TABLE public.strategic_actions CASCADE;
TRUNCATE TABLE public.strategic_objectives CASCADE;
TRUNCATE TABLE public.kpi_results CASCADE;
TRUNCATE TABLE public.kpi_targets CASCADE;
TRUNCATE TABLE public.kpis CASCADE;
TRUNCATE TABLE public.effectiveness_evaluations CASCADE;
TRUNCATE TABLE public.projects CASCADE;
TRUNCATE TABLE public.evidences CASCADE;
TRUNCATE TABLE public.decisions CASCADE;
TRUNCATE TABLE public.submissions CASCADE;
TRUNCATE TABLE public.meeting_presenters CASCADE;
TRUNCATE TABLE public.meetings CASCADE;
TRUNCATE TABLE public.ppt_layouts CASCADE;
TRUNCATE TABLE public.ppt_templates CASCADE;
TRUNCATE TABLE public.generated_files CASCADE;
TRUNCATE TABLE public.archive_locations CASCADE;
TRUNCATE TABLE public.connector_instances CASCADE;
TRUNCATE TABLE public.connectors CASCADE;
TRUNCATE TABLE public.cycles CASCADE;
TRUNCATE TABLE public.frameworks CASCADE;
TRUNCATE TABLE public.brand_kits CASCADE;
TRUNCATE TABLE public.roles CASCADE;
TRUNCATE TABLE public.teams CASCADE;
TRUNCATE TABLE public.organization_memberships CASCADE;
TRUNCATE TABLE public.organizations CASCADE;
TRUNCATE TABLE public.app_versions CASCADE;
TRUNCATE TABLE public.feature_flags CASCADE;

-- helpers
DO $$
DECLARE
  org_samsys uuid;
  org_acme uuid;
  cycle_samsys uuid;
  campaign_samsys uuid;
  campaign_acme uuid;
  kpi_samsys uuid;
  meeting_samsys uuid;
  obj_samsys uuid;
  ro_samsys uuid;
  framework_samsys uuid;
  admin_user uuid;
BEGIN
  -- primeiro admin/quality existente
  SELECT id INTO admin_user FROM public.profiles WHERE role IN ('quality','admin') ORDER BY created_at LIMIT 1;

  -- organizações
  INSERT INTO public.organizations (id, name, slug, description, tax_id, website, email, phone, city, country, primary_color, secondary_color, active)
  VALUES (gen_random_uuid(), 'Samsys', 'samsys', 'Samsys - Tecnologia e Inovação', '123456789', 'https://samsys.pt', 'geral@samsys.pt', '+351 000 000 000', 'Lisboa', 'PT', '#7367f0', '#00cfe8', true)
  RETURNING id INTO org_samsys;

  INSERT INTO public.organizations (id, name, slug, description, tax_id, website, email, phone, city, country, primary_color, secondary_color, active)
  VALUES (gen_random_uuid(), 'AcmeCorp', 'acme-corp', 'AcmeCorp - Empresa fictícia de demonstração', '987654321', 'https://acme-corp.example', 'demo@acme-corp.example', '+351 111 111 111', 'Porto', 'PT', '#ea5455', '#ff9f43', true)
  RETURNING id INTO org_acme;

  -- memberships e apresentador apenas se houver admin
  IF admin_user IS NOT NULL THEN
    INSERT INTO public.organization_memberships (organization_id, user_id, role, department, job_title, active)
    VALUES (org_samsys, admin_user, 'owner', 'Qualidade', 'Diretor de Qualidade', true)
    ON CONFLICT (organization_id, user_id) DO NOTHING;
  END IF;

  -- brand kits
  INSERT INTO public.brand_kits (organization_id, name, is_default, primary_color, secondary_color, background_color, text_color, accent_color, font_heading, font_body)
  VALUES (org_samsys, 'Samsys Default', true, '#7367f0', '#00cfe8', '#ffffff', '#2c2c2c', '#28c76f', 'Inter', 'Inter');
  INSERT INTO public.brand_kits (organization_id, name, is_default, primary_color, secondary_color, background_color, text_color, accent_color, font_heading, font_body)
  VALUES (org_acme, 'AcmeCorp Default', true, '#ea5455', '#ff9f43', '#fff8f0', '#3a0000', '#28c76f', 'Inter', 'Inter');

  -- teams e roles
  INSERT INTO public.teams (organization_id, name, description, color, active)
  VALUES (org_samsys, 'Estratégia', 'Equipa de planeamento estratégico', '#7367f0', true),
         (org_samsys, 'Qualidade', 'Equipa de gestão da qualidade', '#28c76f', true);
  INSERT INTO public.roles (organization_id, name, description, permissions, active)
  VALUES (org_samsys, 'Owner', 'Acesso total à plataforma estratégica', '["*"]'::jsonb, true),
         (org_samsys, 'Viewer', 'Apenas leitura', '["read"]'::jsonb, true);

  -- frameworks e cycles
  INSERT INTO public.frameworks (id, organization_id, code, name, description, type, active)
  VALUES (gen_random_uuid(), org_samsys, 'PE2026', 'Plano Estratégico 2026', 'Plano estratégico anual Samsys', 'strategic', true)
  RETURNING id INTO framework_samsys;

  INSERT INTO public.cycles (id, organization_id, framework_id, name, description, start_date, end_date, status, active)
  VALUES (gen_random_uuid(), org_samsys, framework_samsys, '2026', 'Ciclo estratégico 2026', '2026-01-01', '2026-12-31', 'active', true)
  RETURNING id INTO cycle_samsys;

  -- campanhas SWOT
  INSERT INTO public.swot_campaigns (id, organization_id, cycle_id, name, description, status, starts_at, ends_at, created_by)
  VALUES (gen_random_uuid(), org_samsys, cycle_samsys, 'SWOT 2026 - Samsys', 'Análise SWOT para o ciclo 2026', 'open', now(), now() + interval '30 days', admin_user)
  RETURNING id INTO campaign_samsys;

  INSERT INTO public.swot_campaigns (id, organization_id, cycle_id, name, description, status, starts_at, ends_at, created_by)
  VALUES (gen_random_uuid(), org_acme, NULL, 'SWOT Demo - AcmeCorp', 'Campanha de demonstração AcmeCorp', 'open', now(), now() + interval '30 days', admin_user)
  RETURNING id INTO campaign_acme;

  -- itens SWOT Samsys
  INSERT INTO public.swot_items (campaign_id, quadrant, title, description, impact, probability, order_index, created_by)
  VALUES
    (campaign_samsys, 'strengths', 'Equipa experiente', 'Equipa com vasta experiência em implementações PHC/Sage', 'high', 'high', 1, admin_user),
    (campaign_samsys, 'weaknesses', 'Processos manuais', 'Parte da gestão da qualidade ainda é manual', 'medium', 'high', 2, admin_user),
    (campaign_samsys, 'opportunities', 'Expansão IA', 'Integrar IA assistiva nos processos de qualidade', 'high', 'medium', 3, admin_user),
    (campaign_samsys, 'threats', 'Concorrência apertada', 'Mais concorrência no mercado de consultoria', 'high', 'high', 4, admin_user);

  -- itens SWOT AcmeCorp
  INSERT INTO public.swot_items (campaign_id, quadrant, title, description, impact, probability, order_index, created_by)
  VALUES
    (campaign_acme, 'strengths', 'Marca reconhecida', 'Presença forte no mercado nacional', 'medium', 'high', 1, admin_user),
    (campaign_acme, 'threats', 'Custos crescentes', 'Aumento dos custos de matérias-primas', 'high', 'medium', 2, admin_user);

  -- risco/oportunidade Samsys
  INSERT INTO public.risk_opportunities (id, organization_id, cycle_id, reference, type, title, description, probability, impact, status, mitigation, responsible_id, due_date, created_by)
  VALUES (gen_random_uuid(), org_samsys, cycle_samsys, 'R-2026-001', 'risk', 'Atraso em certificações', 'Risco de atraso na renovação de certificações de qualidade', 3, 4, 'mitigating', 'Criar plano de ação com marcos trimestrais', admin_user, '2026-06-30', admin_user)
  RETURNING id INTO ro_samsys;

  -- objetivo estratégico Samsys
  INSERT INTO public.strategic_objectives (id, organization_id, cycle_id, code, name, description, perspective, weight, status, progress, responsible_id, start_date, due_date, created_by)
  VALUES (gen_random_uuid(), org_samsys, cycle_samsys, 'OE-2026-01', 'Melhorar eficácia operacional', 'Reduzir o tempo de resposta a NC/OM em 20%', 'internal', 1, 'active', 35, admin_user, '2026-01-01', '2026-12-31', admin_user)
  RETURNING id INTO obj_samsys;

  -- ação estratégica
  INSERT INTO public.strategic_actions (objective_id, name, description, status, priority, responsible_id, start_date, due_date, progress, created_by)
  VALUES (obj_samsys, 'Implementar dashboard em tempo real', 'Dashboard com KPIs operacionais atualizados automaticamente', 'in_progress', 'high', admin_user, '2026-02-01', '2026-05-31', 40, admin_user);

  -- KPI Samsys
  INSERT INTO public.kpis (id, organization_id, objective_id, code, name, description, unit, direction, frequency, formula, data_source, responsible_id, active, created_by)
  VALUES (gen_random_uuid(), org_samsys, obj_samsys, 'KPI-2026-01', 'Tempo médio de resposta a NC', 'Média de dias entre abertura e primeira ação', 'dias', 'lower_is_better', 'monthly', 'AVG(first_action_date - occurrence_date)', 'quality_occurrences', admin_user, true, admin_user)
  RETURNING id INTO kpi_samsys;

  INSERT INTO public.kpi_targets (kpi_id, period, target_value, warning_value)
  VALUES (kpi_samsys, '2026', 5.0, 7.0);

  INSERT INTO public.kpi_results (kpi_id, period, value, notes, entered_by)
  VALUES (kpi_samsys, '2026-01', 6.5, 'Resultado de janeiro', admin_user);

  -- reunião
  INSERT INTO public.meetings (id, organization_id, cycle_id, title, description, meeting_type, status, scheduled_at, duration_min, location, created_by)
  VALUES (gen_random_uuid(), org_samsys, cycle_samsys, 'Revisão Estratégica Q1', 'Revisão do plano estratégico do primeiro trimestre', 'strategic', 'scheduled', '2026-04-15 14:00:00+01', 120, 'Sala de Reuniões A', admin_user)
  RETURNING id INTO meeting_samsys;

  IF admin_user IS NOT NULL THEN
    INSERT INTO public.meeting_presenters (meeting_id, user_id, topic, order_index)
    VALUES (meeting_samsys, admin_user, 'Balanço do trimestre e KPIs', 1);
  END IF;

  -- decisão
  INSERT INTO public.decisions (organization_id, meeting_id, code, title, description, rationale, status, impact_level, created_by)
  VALUES (org_samsys, meeting_samsys, 'D-2026-001', 'Aprovar investimento em IA assistiva', 'Aprovação do orçamento para integração de IA nos processos de qualidade', 'Retorno esperado superior a 20% em eficiência', 'proposed', 'high', admin_user);

  -- template PPT
  INSERT INTO public.ppt_templates (id, organization_id, name, description, is_default, active, created_by)
  VALUES (gen_random_uuid(), org_samsys, 'Samsys Strategy Template', 'Template corporativo para apresentações estratégicas', true, true, admin_user);

  -- app versions e feature flags
  INSERT INTO public.app_versions (platform, version, release_notes, min_required, active, released_at)
  VALUES ('web', '1.5.0', 'Plataforma Estratégica v1.5', false, true, now()),
         ('ios', '1.0.0', 'Versão inicial iOS', false, true, now())
  ON CONFLICT (platform, version) DO NOTHING;

  INSERT INTO public.feature_flags (key, enabled, description)
  VALUES ('strategy_platform_enabled', true, 'Ativar módulo da Plataforma Estratégica v1.5'),
         ('ai_assistant_enabled', true, 'Ativar assistente IA'),
         ('lifecycle_module_enabled', true, 'Ativar módulo LifeCycle RH')
  ON CONFLICT (key) DO UPDATE SET enabled = EXCLUDED.enabled, description = EXCLUDED.description;

  RAISE NOTICE 'Seed v1.5 carregado: samsys=% acme=%', org_samsys, org_acme;
END$$;

COMMIT;
