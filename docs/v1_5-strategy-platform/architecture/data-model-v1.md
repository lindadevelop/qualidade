# Modelo de Dados v1.5 — Extensão do SAMSYS|Qualidade

## Princípio

Reutilizar estruturas existentes quando compatíveis; adicionar novas tabelas para a Plataforma Estratégica sem quebrar o módulo de NC/OM.

## Entidades existentes (mantidas)

- `profiles`, `quality_areas`, `quality_origins`, `quality_occurrences`, `quality_actions`, `quality_attachments`, `quality_comments`, `audit_log`

## Novas entidades v1.5

### Organização / Tenant
- `organizations` (id, name, slug, brand_kit_id, installation_mode, plan_id, active, created_at)
- `organization_memberships` (user_id, organization_id, team_id, role_id, active)

### Equipas
- `teams` (id, organization_id, name, parent_team_id, leader_id, active)

### Perfis/Permissões
- `roles` (id, organization_id, name, permissions jsonb)

### Brand Engine
- `brand_kits` (id, organization_id, name, logo_url, colors jsonb, typography jsonb, images jsonb, mode, version, active)

### Frameworks
- `frameworks` (id, organization_id, name, key, config jsonb, active)
- `cycles` (id, organization_id, framework_id, name, start_date, end_date, active)

### SWOT
- `swot_campaigns` (id, organization_id, cycle_id, name, min_items, max_items, state, opened_at, closed_at)
- `swot_items` (id, campaign_id, quadrant, text, scope, owner_team_id, impacted_team_ids, author_id, state, created_at)
- `swot_contributions` (id, swot_item_id, analyzed_team_id, author_id, decision, note, created_at)

### TOWS
- `tows_crossings` (id, campaign_id, item_a_id, item_b_id, strategy_type, proposal, state, created_at)

### Riscos/Oportunidades
- `risk_opportunities` (id, organization_id, type, description, origin_swot_item_id, origin_tows_id, scope, owner_id, impacted_team_ids, impact, probability, priority, treatment, residual, state, created_at)

### Plano Estratégico
- `strategic_objectives` (id, organization_id, cycle_id, risk_opportunity_ids, title, description, owner_id, deadline, state, created_at)
- `strategic_actions` (id, objective_ids, description, responsible_id, deadline, state, priority, created_at)

### KPI/Resultados
- `kpis` (id, organization_id, name, definition, formula, unit, direction, frequency, owner_id, source, tolerance, created_at)
- `kpi_targets` (id, kpi_id, period, target_value, baseline, tolerance, created_at)
- `kpi_results` (id, kpi_id, target_id, period, value, validation_state, evidence_id, created_at)
- `effectiveness_evaluations` (id, objective_id, result, basis, evaluator_id, evaluated_at)

### Projetos
- `projects` (id, organization_id, title, description, objective_ids, risk_opportunity_ids, state, review_relevance, created_at)

### Decisões/Evidências
- `decisions` (id, organization_id, meeting_id, subject, analyzed_data, decision_text, responsible_id, deadline, follow_up, state, created_at)
- `evidences` (id, organization_id, file_path, reference, type, source_object_type, source_object_id, version, integrity_hash, created_at)

### Reuniões / PPT
- `meetings` (id, organization_id, type, title, date, state, presenters, total_time, submission_deadline, archive_location_id, created_at)
- `meeting_presenters` (id, meeting_id, team_id, user_id, assigned_time, order, state)
- `submissions` (id, meeting_id, presenter_id, version, state, slides jsonb, estimated_time, created_at)
- `ppt_templates` (id, organization_id, team_id, cycle_id, name, file_path, layouts jsonb, version, state)
- `ppt_layouts` (id, template_id, layout_key, family, data_origin, fields jsonb, default_time, review_relevance)
- `generated_files` (id, organization_id, meeting_id, file_path, hash, version, created_by, created_at)
- `archive_locations` (id, organization_id, name, storage_type, config jsonb, created_at)

### Integrações / Versões
- `connectors` (id, name, version, capabilities jsonb, state, created_at)
- `connector_instances` (id, organization_id, connector_id, config jsonb, health, created_at)
- `app_versions` (id, version, channel, migrations jsonb, compatibilities jsonb, created_at)
- `feature_flags` (id, key, scope, state, created_at)

### Auditoria
- Reutilizar `audit_log`; adicionar tipos de entidade novos.

## Cardinalidades-chave

- SWOT item ↔ Risco/Oportunidade: N:N
- Risco/Oportunidade ↔ Objetivo: N:N
- Objetivo ↔ Ação: N:N
- Objetivo/Projeto ↔ KPI: N:N
- Reunião ↔ Objetivo/Risco/Decisão: N:N
- Slide ↔ Objeto estratégico: 0:N
