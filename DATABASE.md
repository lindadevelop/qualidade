# SAMSYS|Qualidade — Database

Modelo de dados PostgreSQL no Supabase Cloud. **Todo o schema é criado por migrations** — nada
manual pelo painel. RLS obrigatório. Regras de negócio e auditoria implementadas em SQL.

UUID PK em todas as tabelas; colunas `id uuid`, `created_at`, `updated_at` por predefinição.
Foreign keys + constraints + indexes. Timestamps geridos com triggers `set_updated_at`.

---

## 1. `profiles`  (espelha `auth.users`)
| col | tipo | notas |
|-----|------|-------|
| id | uuid PK | = auth.users.id |
| full_name | text | |
| email | text | |
| avatar_url | text | |
| role | text | `quality` \| `action_owner` \| `management` \| `admin` |
| department | text | |
| job_title | text | |
| active | boolean | |
| created_at / updated_at | timestamptz | |
> created via trigger `on_auth_user_created` (handle_new_user) a partir de auth.users.

## 2. `quality_areas`
`id, name, description, active, sort_order, created_at, updated_at`
> Ex.: Desenvolvimento, Sistemas, Comercial, Financeiro, PHC, Sage, Logística, Administração.
> **Nunca hardcoded** — configurável.

## 3. `quality_origins`
`id, name, description, active, sort_order, created_at, updated_at`
> Ex.: Auditoria Interna, Auditoria Externa, Reclamação, Processo Interno, Revisão pela Gestão,
> Melhoria Interna, Outra. Configurável.

## 4. `quality_occurrences`  (NC/OM)
| col | tipo | notas |
|-----|------|-------|
| id | uuid PK | |
| reference | varchar | `NC-2026-0001` / `OM-2026-0001` — gerado no servidor, contador concorrente, **sem duplicados** |
| type | text | `NC` \| `OM` |
| year | int | gerado de occurrence_date |
| origin_id | uuid FK quality_origins | |
| occurrence_date | date | |
| area_id | uuid FK quality_areas | |
| description | text | texto original, nunca alterado automaticamente |
| responsible_user_id | uuid FK profiles | |
| cause_analysis | text | (visão geral) |
| status | text | `OPEN` \| `IN_PROGRESS` \| `AWAITING_EFFECTIVENESS` \| `CLOSED` |
| effectiveness_status | text | null \| `EFFECTIVE` \| `NOT_EFFECTIVE` |
| effectiveness_notes | text | |
| effectiveness_evidence | jsonb | referências a anexos |
| effectiveness_validated_by | uuid FK profiles | |
| effectiveness_validated_at | timestamptz | |
| closed_at | timestamptz | |
| reopened_at / reopened_by | timestamptz / uuid | |
| created_by | uuid FK profiles | |
| created_at / updated_at | timestamptz | |

### Referência legível (gerada na BD)
Função/RPC para gerar `NC-{year}-{seq}` / `OM-{year}-{seq}` de forma atómica e concorrente
(sequence por ano/tipo + trigo `before insert`), garantindo unicidade sob concorrência.

## 5. `quality_actions`
| col | tipo | notas |
|-----|------|-------|
| id | uuid PK | |
| reference | varchar | (semelhante às ocorrências) |
| occurrence_id | uuid FK quality_occurrences — **obrigatório** | cada ação tem uma ocorrência |
| description | text | |
| responsible_user_id | uuid FK profiles | |
| deadline | date | calculado dinamicamente (nunca texto estático: atrasada há X dias, hoje, 1/2/3... dias) |
| status | text | `TODO` \| `IN_PROGRESS` \| `COMPLETED` |
| completed_at | timestamptz | |
| created_by / created_at / updated_at | | |

> Uma ocorrência pode ter múltiplas ações.

## 6. Evidências — `quality_attachments` + Supabase Storage
| col | tipo | notas |
|-----|------|-------|
| id | uuid PK | |
| occurrence_id | uuid nullable FK | |
| action_id | uuid nullable FK | |
| file_name | text | |
| file_path | text | caminho no bucket |
| file_type | text | |
| file_size | bigint | |
| description | text | |
| uploaded_by / created_at | | |

- **Bucket privado `quality-evidence`** (RPC de política). Aceitar PDF, Word, Excel, JPG, PNG, info.
- Limite de tamanho configurável. Usar **URLs assinados/temporários**.
- Nunca tornar documentos internos públicos.

## 7. Comentários — `quality_comments` (timeline)
`id, occurrence_id, action_id nullable, comment, created_by, created_at, updated_at`

## 8. `audit_log`  (histórico/auditoria — crítico)
| col | tipo | notas |
|-----|------|-------|
| id | uuid PK | |
| entity_type | text | occurrence \| action \| attachment \| comment |
| entity_id | uuid | |
| action | text | create \| update \| change_responsible \| change_status \| complete \| attach \| add_comment \| validate_effectiveness \| close \| reopen |
| old_data | jsonb | |
| new_data | jsonb | |
| changed_fields | jsonb | |
| user_id | uuid | |
| created_at | timestamptz | |

Preferencialmente via **triggers PostgreSQL** para alterações críticas (mudança de responsável,
estado, conclusão, eficácia, encerramento, reabertura). Regista quem/quando/o quê/valor anterior/valor novo.

## 9. `notifications`
`id, user_id, type, title, message, entity_type, entity_id, read, created_at`
Tipos: ação atribuída | ação próxima do prazo | ação em atraso | todas as ações concluídas |
eficácia por validar | ocorrência reaberta. Usar **Supabase Realtime** para entrega sem refresh.

## 10. Regras de negócio (SQL, não frontend) — §17
1. Ocorrência começa `OPEN`.
2. Se tiver ações ativas → `IN_PROGRESS`.
3. Quando TODAS as ações concluídas → `AWAITING_EFFECTIVENESS`.
4. Não permitir encerrar sem validação de eficácia.
5. Eficácia validada positivamente → `CLOSED` + `closed_at`.
6. Ação concluída ≠ ocorrência encerrada.
7. Ocorrência encerrada só reaberta por utilizador autorizado.
8. Reabertura registada no audit_log.

## 11. Row Level Security (RLS) — §47
- **Admin / Qualidade**: consulta e edita tudo.
- **ActionOwner**: consulta dados autorizados (ocorrências/ações a que está associado) e atualiza
  as PRÓPRIAS ações; não pode encerrar NC/OM, validar eficácia nem alterar configurações.
- **Management**: read-only.
- Policies criadas nas migrations, com `security definer` apenas onde necessário (ex.: notificações).

## 12. Performance — índices (§49)
`status, type, year, origin_id, area_id, responsible_user_id, occurrence_date, deadline,
occurrence_id, created_at` — índices em `quality_occurrences` e `quality_actions`.

## 13. Dashboard SQL views / RPC (§50)
Nunca carregar milhares de registos para o browser. Criar views/RPC que devolvem métricas, ex.:
```
{ open_nc, open_om, overdue_actions, awaiting_effectiveness }
```
e funções para: evolução por mês/trimestre/ano; distribuição por estado; por origem; por área;
ações por responsável; ações mais urgentes.

## 14. Sequelize/preparação IA (§72–104) — estruturas extensíveis, sem implementar MVP
- `quality_categories` (+parent_id) e `quality_occurrence_categories` — categorizar ocorrências,
  opcional no MVP (ex.: Processo, Documentação, Comunicação, Formação, Software, Infraestrutura,
  Segurança, Cliente, Fornecedor, ErroHumano).
- `quality_tags` e `quality_occurrence_tags` — tags opcionais.
- `quality_occurrence_embeddings` (id, occurrence_id, content, embedding vector, model) —
  pgvector, **não ativo no MVP**.
- `ai_interactions` (user_id, occurrence_id, feature, provider, model, input_reference, result jsonb,
  accepted) — registar/medir sugestões de IA.
- `feature_flags` (ai_similar_occurrences, ai_root_cause, ai_action_suggestions, ai_dashboard_insights,
  ai_assistant, ai_effectiveness_analysis) — ativar gradualmente.
- IA nunca contorna RLS; autor da alteração é sempre o utilizador; origemo da sugestão
  `AI_ASSISTED`; auto→human approval.
- `AI_DATA_SANITIZER` futuro para minimizar envio de dados pessoais.

## 15. Seed demo (§63)
`supabase/seed.sql`: 10 utilizadores, 30 ocorrências (NC+OM), várias origens/áreas,
~70 ações, ações concluídas, em atraso, eficácia pendente, ocorrências encerradas.

## 16. Primeiro utilizador (§64)
Documentado no README: como criar o 1º Administrador/Qualidade (via RPC `is_admin`/utilizador
inicial pelo dashboard) sem guardar passwords no git.

## 17. Sql migrations — como aplicar
`supabase/migrations/` com nomes sequenciais (`0001_...sql`, `0002_...`), idempotentes.
Gerar tipos: `supabase gen types typescript` (salvo para `src/types/database.ts`).