# Plataforma Estratégica Samsys v1.5 — Implementação no SAMSYS|Qualidade

> Documentação de execução baseada no `00_DOCUMENTO_UNICO_EXECUTAVEL_IA_v1_5_Plataforma_Estrategica_Samsys.pdf` e no `Prompt_Hermes_Codex_Qualidade_v1_5.docx`.

## Estado atual

- Aplicação base: SAMSYS|Qualidade (Vue 3 + Vite + Supabase local/PostgREST).
- Stack local portátil: PostgreSQL, PostgREST, auth-server, api-proxy, frontend Vite preview.
- Túnel ativo: `https://biodiversity-blake-increasingly-kevin.trycloudflare.com`

## Pasta

- `coverage/` — matriz de cobertura de requisitos.
- `architecture/` — arquitetura proposta, ERD, workflows, permissões.
- `decisions/` — Decision Log.
- `pocs/` — provas de conceito (PowerPoint, Strategy Graph, offline, Brand Engine).
- `tests/` — resultados de testes e evidências.

## Regras de execução

1. Preservar túneis durante builds.
2. Não matar processos de outros projetos.
3. Criar scaffold completo primeiro; funcionalidades podem ficar marcadas como Planeadas.
4. Percurso prioritário: SWOT → TOWS → Risco/Oportunidade → Plano → KPI → Acompanhamento → Dashboard → Reunião → PPT → Revisão pela Gestão.
5. Não hardcode Samsys; criar organização demo separada.
