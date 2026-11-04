# SAMSYS|Qualidade — Implementation Plan

Plano faseado (FASE 1–6). Cada fase termina com build limpo + lint (+ testes quando aplicável)
e um resumo: o que foi desenvolvido, ficheiros criados/alterados, migrations adicionadas,
funcionalidades concluídas, problemas, próximos passos.

Nota de execução (§71): antes de alterar código existente, analisar estrutura, preservar código
funcional, não duplicar componentes, migrations incrementais, não eliminar dados sem aprovação.

---

## FASE 1 — Análise e arquitetura  ✅ (este documento)
- [x] Ler pedido completo.
- [x] `ARCHITECTURE.md` — stack, camadas, segurança, performance, pastas, IA futura, fases.
- [x] `DATABASE.md` — schema completo, RLS, regras de negócio, índices, views/RPC, seed.
- [x] `IMPLEMENTATION_PLAN.md` — este documento.
- [x] `AI_ROADMAP.md` — roadmap IA (FaseAI1–3) (ver baixo).

## FASE 2 — Fundações: projeto, layout, auth, schema
- Criar projeto Vite + Vue3 + TS + Bootstrap 5 + Pinia + Vue Router + ApexCharts + Tabler Icons.
- Layout Vuexy: sidebar vertical recolhível, navbar superior, breadcrumb, dropdown utilizador,
  notificações, modo Light/Dark/System, responsivo (drawer mobile).
- Autenticação Supabase: login, logout, recuperação/alterar password, perfil, sessão persistente,
  guardas de rota, permissões por role, sessão expirada. Sem registo público.
- Migrations: todas as tabelas do DATABASE.md + RLS + triggers + índices + referência concorrente.
- `seed.sql` demo (10 utilizadores, 30 ocorrências, ~70 ações). Primeiro admin documentado.
- `.env.example` (`VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`). README completo.

**Entregáveis**: backend funcional com auth + RLS; layout base responsivo.

## FASE 3 — Núcleo: dashboard, NC/OM, ficha, plano de ações
- Dashboard principal (cards KPI + gráficos + drill-down) — inspirado Vuexy CRM.
- Página NC/OM: tabela profissional, filtros (ano/tipo/origem/área/responsável/estado), tabs,
  pesquisa (ID/descrição), badges (NC rosa/vermelho, OM azul/roxo).
- Ficha de ocorrência completa: tipo, origem, área, responsável, data, estado, criado por/em.
  Tabs: Visão Geral, Plano de Ações, Evidências, Eficácia, Comentários, Histórico.
- Plano de ações com progress (ex.: "3 de 5 ações concluídas · 60%").
- **Regras de negócio no PostgreSQL** (§17), verificadas.

## FASE 4 — Eficácia, anexos, histórico, notificações
- Validação de eficácia (só Qualidade): Eficaz/Não eficaz, observações, evidências, validado por/em;
  botão "Validar eficácia e encerrar". Se Não eficaz → cria nova ação, volta IN_PROGRESS.
- Evidências em Storage privado + URLs assinados (PDF/Word/Excel/JPG/PNG, limite configurável).
- Audit log via triggers (quem/quando/o quê/antes/depois) na ficha (tab Histórico).
- Notificações internas + Supabase Realtime (reb `badge`, dropdown, marcar como lida).
- Timeline (ActivityTimeline Vuexy): NC criada, ação atribuída, evidência, concluída, eficácia, encerrada.

## FASE 5 — Relatórios, exportação, importação, administração
- Página Relatórios da Qualidade: filtros (data inicial/final, ano, tipo, origem, área, responsável, estado);
  relatórios: Ocorrências, Plano de Ações, Ações em atraso, Aguardam eficácia, Encerradas,
  indicadores por área, por responsável. Exportação Excel (SheetJS) e PDF (cabeçalho com filtros,
  SAMSYS · Gestão da Qualidade · período · gerado em/por). **Respeitar filtros na exportação.**
- Revisão pela Gestão: gráficos (evolução, origem, área, estado, responsáveis, tendência);
  Auditoria Interna antes de Externa na análise anual.
- Importação de Histórico: wizard 5 passos (upload .xlsx/.csv → mapeamento → pré-visualização →
  validação → importação). Nunca reescrever automaticamente descrições. Deteção de possíveis
  duplicados (sem eliminar).
- Administração: CRUD Origens, CRUD Áreas/Processos, CRUD Utilizadores, Configurações
  (ex.: dias de aviso antes do prazo = 5).

## FASE 6 — Testes, otimização, polish
- Testes de regras de negócio (§68):
  - T1 Ocorrência com ação aberta não pode fechar.
  - T2 Todas ações concluídas → AWAITING_EFFECTIVENESS.
  - T3 Sem eficácia validada não pode fechar.
  - T4 Eficácia aprovada → CLOSED.
  - T5 ActionOwner não consegue validar eficácia.
  - T6 Management não consegue editar.
  - T7 ActionOwner não consegue alterar ações de outro responsável.
- UX: cards/tabs/drawers/modals/accordions, autocomplete, feedback visual
  ("Alterações guardadas com sucesso"), confirmações (encerrar/reabrir/eliminar anexo),
  empty states ("Ainda não existem ações... [+ Criar ação]"), skeleton loaders, tratamento
  centralizado de erros.
- Performance: índices, evitar N+1, views/RPC para métricas.
- Dark mode persistente; global search na navbar (referência NC/OM, ação, descrição, utilizador).
- Polimento visual final para o critério: "não parecer um Excel" mas uma plataforma empresarial.

---

# AI_ROADMAP.md
Futuro — a IA é sempre **assistiva e nunca decisória** (§101). Por Fases:
- **FaseAI-1** — Pesquisa semântica, Ocorrências semelhantes, Classificação sugerida, Resumos.
- **FaseAI-2** — Deteção de recorrências, Sugestão de causas, Sugestão de ações, Insights do dashboard.
- **FaseAI-3** — Assistente de Qualidade, Análise avançada, Risco de atraso, Análise de eficácia,
  Tendências preditivas.

**Não implementar funcionalidades de IA no MVP** (§102): implementar apenas estrutura arquitetural
(dados extensíveis, serviço abstrato, Edge Functions preparadas, feature flags, permissões,
auditabilidade). Consultar `ARCHITECTURE.md` §10 e `DATABASE.md` §14.

---

# Critério final de sucesso (§69)
Resultado com sensação visual equivalente ao CRM Dashboard Vuexy: dashboard profissional, alta
densidade de informação, leitura imediata, sem poluição visual, interface empresarial consistente
em todas as páginas — não um "Excel numa página web".