# PRÉ-VISUALIZAÇÃO — Registo LifeCycle RH Samsys no programa da Qualidade

**Estado:** PROPOSTA — nada foi gravado. Aguarda validação (etapa 7/8 do prompt).

## 1. Enquadramento proposto
- **Nome:** LifeCycle RH Samsys (projeto de melhoria)
- **Processo:** Recursos Humanos / Talento
- **Responsável funcional:** RH / Talento
- **Tipo:** Ocorrência tipo **OM** (não NC) com origem **Melhoria Interna** — cumpre "registar como projeto de melhoria, não criar não conformidade"
- **Objetivo:** melhorar e automatizar o ciclo de vida do colaborador, reduzir tarefas manuais e duplicação, assegurar rastreabilidade
- **Referência do projeto:** **LCY-001** (prefixo LifeCycle; a app gera NC-/OM-, usamos OM- com descrição a marcar projeto)

## 2. Lacuna de modelo (a sinalizar antes de alterar a app)
O modelo atual da aplicação tem:
| Conceito (do relatório) | No programa da qualidade |
|---|---|
| Tipo "Projeto de melhoria" | Não existe — só `NC` / `OM`. Mapear para **OM** (melhoria) |
| Prioridade P0/P1/P2 (backlog B01–B18) | Sem campo. Guardar no texto da ação/prefixo ou categoria |
| Secção / identificador de origem (ex. B03, RF-07) | Sem campo. Guardar em **tags** e/ou descrição |
| Equipa responsável | `responsible_user_id` exige utilizador existente; sem contas reais → usar "Utilizador Geral" + tag de equipa |
| Tarefas A01–A20 de admissão | Não são execuções reais → não criar; associar como checklists/descrição aos entregáveis |
| E01–E12, T01–T12, R1–R10, D01–D11, Gates, KPIs | Sem módulo próprio → registar como **ações de referência/controlo** com origem da secção |

## 3. Registo proposto (o que criar)
Raiz: **1 ocorrência OM** "LifeCycle RH Samsys" (Melhoria Interna, área RH, responsável Utilizador Geral).

Ações a criar (ligadas à OM via `occurrence_id`), com `reference` próprio `LCY-R-##` e prioridade no título:
- **18 ações de entregáveis** = backlog B01–B18 (P0/P1/P2 conforme relatório), cada uma com: título verbo, descrição+resultado, secção origem (ex. "§9 B03"), equipa, critério de aceitação, evidência, estado, e referências RF/ADM-p0 relevantes. B17 mapeado a **Enterprise/PHC** (não Dev/RH), com anotação da divergência.
- **11 ações de plano de ação imediato** (itens 1–11 do §14).
- **8 ações de tarefas de admissão A01–A20** (agrupadas por gate P0/P1, como especificação/checklist — não executadas), associadas aos entregáveis.
- **11 ações de catálogo E01–E12** (comunicações a implementar) e **13 ações de cenários T01–T12** (testes/aceitação).
- **10 ações de riscos R1–R10** (com mitigação) e **11 ações de decisões D01–D11** (pendentes).
- **7 ações de gates** (Gate 0–6, marcos) e a(s) referência(s) a indicadores/KPIs.
- Registo de origem do documento (LifeCycle RH Samsys v5) e histórico de alteração.

**Total estimado:** 1 OM + ~80 ações de referência/entregáveis.

Para evitar duplicação, RF-01–15 e ADM-P0-01–08 **não** geram ações separadas: são anexados como critérios às ações B* correspondentes (cruzamento de secções, exigido pelo prompt).

## 4. Tags (taxonomia do projeto, usando `quality_tags` existente)
- Prioridades: `P0`, `P1`, `P2`
- Secções: `backlog`, `plano-accao`, `admissao-checklist`, `comunicacoes`, `testes`, `risco`, `decisao`, `gate`, `kpi`
- Equipas: `rh-talentos`, `dev-samsys`, `enterprise-phc`, `printanyway`

## 5. Responsabilidades (sem inventar pessoas)
RH/Talento = dono funcional · Dev Samsys = programação · Enterprise/PHC = integração PHC (B17) · PrintAnyWay = documental/comunicações.
**Inconsistência B17 sinalizada:** relatório lista "Dev/RH"; as secções atribuem integração PHC à Enterprise/PHC → apresentada Enterprise/PHC como técnico proposto, sem a dar como resolvida.

## 6. Reexecução
Importação idempotente por `reference` único (LCY-…): repetir não duplica.

## 7. Validação pedida
Confirmas o plano acima para eu **gravar** (transação, backup já existe)? Ou ajustas âmbito (ex.: só entregáveis + plano imediato, sem riscos/decisões/gates)?