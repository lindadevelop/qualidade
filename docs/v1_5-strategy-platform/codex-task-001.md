# Codex Task 001 — Scaffold v1.5 no SAMSYS|Qualidade

## Contexto
- Repositório: `C:\a\samsys-qualidade`
- Stack: Vue 3 + TypeScript + Vite + Bootstrap 5 + Pinia + PostgREST local portátil + PostgreSQL 17
- Túnel ativo: `https://biodiversity-blake-increasingly-kevin.trycloudflare.com`
- Regras: NÃO matar processos de outros projetos; NÃO fechar túneis; reiniciar apenas serviço necessário.

## Objetivo desta tarefa
Criar o scaffold completo da Plataforma Estratégica Samsys v1.5:
1. Migration SQL `supabase/migrations/0010_strategy_platform_v1_5.sql` com tabelas:
   - organizations, organization_memberships
   - teams, roles
   - brand_kits
   - frameworks, cycles
   - swot_campaigns, swot_items, swot_contributions
   - tows_crossings
   - risk_opportunities
   - strategic_objectives, strategic_actions
   - kpis, kpi_targets, kpi_results, effectiveness_evaluations
   - projects
   - decisions, evidences
   - meetings, meeting_presenters, submissions
   - ppt_templates, ppt_layouts, generated_files, archive_locations
   - connectors, connector_instances, app_versions, feature_flags
   - + triggers set_updated_at e RLS básicas.
2. Seed SQL `supabase/seed_v1_5.sql` com:
   - 2 organizações (Samsys + empresa fictícia "AcmeCorp")
   - Brand Kits diferentes para cada uma
   - 1 campanha SWOT por organização com itens de exemplo
   - 1 risco/oportunidade, 1 objetivo, 1 KPI, 1 reunião.
3. Frontend scaffold:
   - Novas rotas em `src/router/index.ts` para: Estratégia (SWOT, TOWS, Riscos, Plano, KPI, Decisões), Reuniões, Apresentações, Admin (Organizações, Brand Kits, Frameworks, Templates PPT).
   - Páginas placeholder `.vue` para cada rota, marcadas com badge "Em desenvolvimento" ou "Planeado" quando ainda não funcionarem.
   - Menu lateral atualizado em `src/layouts/AppLayout.vue` ou equivalente.
4. Não alterar lógica de NC/OM existente.
5. Verificar build (`npm run build`) sem erros novos.
6. Não executar `git push`.

## Instruções de execução
- Antes de alterar, ler `ARCHITECTURE.md` e `DATABASE.md` existentes.
- Usar snake_case para tabelas/campos SQL.
- UUID PK em todas as tabelas novas.
- Preservar tabelas existentes.
- Criar seed idempotente (`INSERT ... ON CONFLICT DO NOTHING` ou `TRUNCATE ... CASCADE` + insert).
- Não persistir segredos em ficheiros.
- Ao terminar, devolver lista de ficheiros criados/alterados e estado do build.
