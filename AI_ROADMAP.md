# AI_ROADMAP.md — SAMSYS|Qualidade

A Inteligência Artificial será **sempre assistiva e nunca decisória** (§101). Nunca substitui a
decisão humana nem contorna a Row Level Security. A primeira versão da plataforma **não implementa**
funcionalidades de IA: prepara apenas a arquitetura (dados extensíveis, serviço abstrato, Edge
Functions, feature flags, permissões, auditabilidade).

---

## Estrutura já preparada (implementada na base)
- Dados extensíveis: `quality_categories`, `quality_tags`, `quality_occurrence_categories`,
  `quality_occurrence_tags`, `quality_occurrence_embeddings` (pgvector, desativado), `ai_interactions`
- `feature_flags` (`ai_similar_occurrences`, `ai_root_cause`, `ai_action_suggestions`,
  `ai_dashboard_insights`, `ai_assistant`, `ai_effectiveness_analysis`)
- Abstração `src/services/ai/AIService` (a criar quando ativar IA)
- IA sempre **via Edge Functions** (Supabase) — nunca API keys no frontend, nunca `service_role` no browser
- RLS obrigatório no fluxo: Utilizador → Auth → RLS → dados autorizados → IA

## Princípios
- IA **pode**: analisar, comparar, sugerir, resumir, detetar padrões, identificar riscos
- IA **não pode** autonomamente: criar/eliminar/encerrar NC, validar eficácia, alterar
  responsáveis/prazos, reabrir ocorrências, eliminar evidências
- Autor das alterações é **sempre o utilizador**; registar origem `AI_ASSISTED` no histórico
- Respostas IA sempre **JSON estruturado**, validado server-side
- Sanearizar dados antes do envio (minimizar dados pessoais): `AIDataSanitizer`
- Sem app "chatbot": IA contextualizada dentro da ocorrência, plano de ações, dashboards e relatórios

## Fases de implementação (futuro)
- **FaseAI-1** — Pesquisa semântica, Ocorrências semelhantes, Classificação sugerida, Resumos
- **FaseAI-2** — Deteção de recorrências, Sugestão de causas (5 Porquês/Ishikawa/causa raiz),
  Sugestão de ações, Insights do dashboard
- **FaseAI-3** — Assistente de Qualidade, Análise avançada, Risco de atraso, Análise de eficácia,
  Tendências preditivas

## Não implementar no MVP (§102)
Implementar apenas o que tem **impacto arquitetural**: modelo de dados extensível, categorias/tags,
estrutura modular, possibilidade futura de pgvector, serviço abstrato de IA, Edge Functions
preparadas, feature flags, permissões e auditabilidade. Funcionalidades concretas de IA só numa fase posterior.