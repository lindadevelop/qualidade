# IMPLEMENTATION_REPORT_V2_5

## 1. Build/versão
Análise iniciada em 2026-10-01 sobre o projeto existente (Vue 3/Vite, Node, PostgreSQL/PostgREST). Baseline frontend 0.4.0 com alterações locais anteriores preservadas. Especificação integral lida: secções 0–134; prioridade 0, 129–134, baseline, detalhes, roadmap.

## 2. Gap Analysis — diagnóstico antes de alterações
| Área | Antes | Alteração prevista | Estado |
|---|---|---|---|
| Base de dados | Entidades NC/OM, ações e planos existentes | Migrations aditivas; preservar legado | ADAPTAR |
| Auditorias | Ausente | Interna/externa, campos condicionais e documentos | IMPLEMENTAR |
| Constatações | Ausente | Relação única com ocorrência, texto original protegido | IMPLEMENTAR |
| NC / OM | CRUD existente | Origem por relação, OM sem causa/eficácia obrigatória por defeito | ADAPTAR |
| Tratamento | Plano técnico e UI autónoma | Integrar na ocorrência, manter tabelas | ADAPTAR |
| Análise / causa raiz | Apenas análise livre | Separar conclusão e confirmação humana | IMPLEMENTAR |
| Correção / ação corretiva | Tipos técnicos parciais | Cinco tipos e decisão justificada | ADAPTAR |
| Ações | CRUD, estados, responsáveis | Tipo, critérios, prazo original, confirmação e RBAC por campos | ADAPTAR |
| Evidências | UI Supabase Storage incompatível com servidor local; downloads sem autorização | Upload/download autenticado por entidade/empresa | IMPLEMENTAR |
| Aprovação | Planos com decisões gravadas separadamente | Operação atómica, decisões imutáveis, devolver/ressubmeter | ADAPTAR |
| Eficácia | Campos substituídos em ocorrência | Histórico por ciclo, critério/evidências/autor | ADAPTAR |
| Encerramento | Valida eficácia, mas não causa e ações | Validação completa no servidor e motivos na UI | ADAPTAR |
| Reabertura | Sem motivo obrigatório | Motivo, ciclo e preservação das avaliações | ADAPTAR |
| Anulação | Eliminação física existente | Anulação justificada; excluir indicadores | IMPLEMENTAR |
| Estado interno | Trigger incompleto ao criar ação durante eficácia | Corrigir transições, não encerrar por concluir ação | ADAPTAR |
| Estado externo / resposta auditor | Ausente | Histórico independente e texto recebido preservado | IMPLEMENTAR |
| Tomada de conhecimento | Ausente | Autor/data/hora, reiniciar na reatribuição | IMPLEMENTAR |
| Prazos | Sobrescrita sem motivo | Histórico e aprovação configurável | IMPLEMENTAR |
| O meu trabalho | Ausente | Tarefas acionáveis do utilizador | IMPLEMENTAR |
| Próximo passo / completude | Ausente | Regras partilhadas servidor/UI | IMPLEMENTAR |
| Dashboard | Indicadores existentes | Seis indicadores acionáveis, anulação excluída | ADAPTAR |
| Pesquisa global | Campo sem comportamento | Auditorias/NC/OM/ações com filtros | IMPLEMENTAR |
| Notificações | Tabela e sino existentes; eventos incompletos | Eventos transacionais e centro com links | ADAPTAR |
| Email / fila / retry / deduplicação | Sem outbox nuclear | Fila persistente, retries configuráveis, reenvio | IMPLEMENTAR |
| RBAC / permissões | Perfis e tenant; atualizações próprias demasiado amplas | Backend por operação/campos e sessão atual | ADAPTAR |
| Audit Log | Trigger existente, cobertura parcial | Histórico imutável com empresa da entidade | ADAPTAR |
| Exportação | NC Excel/PDF, limite fixo de linhas | Export controlado do conjunto funcional | ADAPTAR |
| Sem Internet | URL Cloudflare incorporado nos clientes | Base relativa à origem; recursos locais | ADAPTAR |
| Organização / tenant | Isolamento de tabelas implementado em 0053 | Aplicar aos novos objetos e anexos | CONFORME / ADAPTAR |
| Entitlements | Módulos por perfil, flags centralizadas parcialmente | Preservar, sem motor comercial | CONFORME / ADAPTAR |
| Testes | Estratégia, utilizadores, limpeza; sem baseline QMS | Unitários, integração, negativos e E2E | IMPLEMENTAR |
| Segurança | Sessões versionadas; storage sem autorização | Corrigir acesso aos novos anexos e formalizações | ADAPTAR |
| Backup / restore | Backups manuais antes de migrações | Validar restauração e documentar operação | ADAPTAR |
| Limpeza definitiva | Implementada a pedido anterior | Conflito com anulação/retenção da v2.5; decisão solicitada | PONTO DE DECISÃO |
| UAT / aprovação de produção | Não realizada para v2.5 | Entregar candidato e roteiro; aprovação pelo negócio | PONTO DE DECISÃO |
| Billing, trials, licenciamento comercial, workflows visuais, graph, previsão | Não necessários ao núcleo | Não implementar | ROADMAP |

## 3. Implementado
Diagnóstico concluído; implementação em curso. Não declarar baseline concluída antes da validação.

## 4. Ficheiros alterados
A preencher durante a implementação.

## 5. Base de dados
Apenas migrations versionadas e aditivas. Sem eliminação de dados reais.

## 6. Testes
| Teste | Resultado |
|---|---|
| Baseline v2.5 | NOT RUN |

## 7. Defeitos encontrados
Encerramento sem causa/ações completas; falta de imutabilidade de ciclos; armazenamento incompatível com UI; pesquisa global inativa; dependência de URL Internet.

## 8. Pontos pendentes
Implementação e validação dos gaps acima.

## 9. Pontos de decisão
Limpeza definitiva de Qualidade versus retenção obrigatória. UAT pelo responsável de negócio antes de produção.

## 10. Segurança e dados
Preservar empresas, utilizadores, anexos, planos legados e histórico. Validar operações com utilizador e organização atuais; nenhuma autorização baseada apenas na UI.

## 11. Roadmap não implementado
Secções 56–82 comerciais não essenciais e 112–128 futuras conforme prioridade das secções 0 e 129–134: billing, trial, portal comercial, licenciamento avançado, graph, previsões, editor visual e form builder.

## 12. Próximos passos recomendados
Executar modelo/regras, fluxo nuclear, UX operacional, outbox e suite de regressão; só depois UAT e Quality Gate.
