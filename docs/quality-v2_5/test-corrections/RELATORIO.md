# Relatório das correções identificadas nos testes

**SAMSYS Qualidade · Versão 0.5.0-rc.3 · 2 de outubro de 2026**

As correções do documento «SAMSYS Correções Testes Desenvolvimento», versão interna 2.2, foram implementadas e disponibilizadas no endereço de testes. Os testes executados passaram. A aceitação pela equipa utilizadora deve ser feita com os seus cenários reais.

[Abrir a aplicação para testar](https://progressive-suburban-entity-twelve.trycloudflare.com/). Atualizar com **Ctrl+F5** e confirmar a versão **0.5.0-rc.3** no menu.

## O que mudou e onde verificar

| Onde | Alteração | Como verificar |
|---|---|---|
| Qualidade → Configuração operacional | Removido o botão genérico Atualizar. Guardar apresenta os dados gravados automaticamente. | Alterar um valor, guardar e verificar que permanece depois de voltar à página. |
| Configuração operacional → Normas e referenciais | Acrescentadas as ações Editar e Ativar/Desativar. Editar mantém o mesmo registo e as suas relações. | Corrigir uma designação e consultar a auditoria que usa esse referencial. |
| Normas e referenciais | A mudança de ano de versão normativa não é aceite como simples renomeação. | Tentar mudar ISO 9001:2015 para ISO 9001:2026. Criar a nova versão através de Adicionar referencial, preservando a anterior. |
| Campos de data da Qualidade, Lifecycle e Estratégia | Campo comum com formato dd/mm/aaaa, calendário em português e validação de datas impossíveis ou incompletas. | Introduzir 31/02/2026 e um ano de cinco dígitos. Não devem ser aceites. Escolher uma data no calendário e verificar o formato. |
| Formulários com início e fim | Validação dos intervalos de datas, incluindo proteção na base de dados. | Tentar guardar uma data de fim anterior ao início. |
| Auditorias → Nova auditoria ou Editar auditoria | Áreas/processos provenientes do catálogo central, seleção de referenciais existentes, sites associados ao âmbito e auditor responsável proveniente dos utilizadores elegíveis. | Definir uma ou várias opções e guardar. Voltar a abrir para confirmar. |
| Auditoria externa | Rótulo alterado para N.º do certificado. | Abrir Mais detalhes no formulário e consultar o detalhe da auditoria. |
| Auditoria → Adicionar constatação NC/OM | Um único campo Tipo com NC Maior, NC Menor e Oportunidade de Melhoria, além de classificações adicionais ativas. | Escolher NC Maior e confirmar que não aparece um segundo campo de classificação. |
| Constatação criada numa auditoria | Origem automática e contexto obtido pela relação com a auditoria. Quando existe uma única opção, não é pedida novamente. | Criar uma constatação numa auditoria com uma área, um referencial e um site. |
| Constatação criada numa auditoria com várias opções | As escolhas ficam limitadas ao âmbito dessa auditoria. | Confirmar que não é possível escolher uma área, referencial ou site de outra auditoria. |
| Constatação numa auditoria sem áreas ativas | Mensagem clara para editar a auditoria e definir o âmbito. | Tentar adicionar uma constatação antes de associar uma área. |
| Formulário da constatação | Data da constatação; Mais detalhes com referência externa, cláusula/requisito e contexto interno. Guardar sem checkbox adicional. | Guardar uma constatação e confirmar que o texto original e o comentário interno permanecem separados. |
| Nova ocorrência fora de auditoria | Mantida a escolha da origem e dos restantes dados necessários. | Abrir Nova ocorrência e confirmar a existência de Origem. |
| Campos de atribuição de pessoas | Utilizadores obtidos do cadastro central, filtrados por empresa, estado, módulo e função. Aprovação e responsabilidade operacional têm critérios distintos. | Confirmar que inativos, pessoas de outra empresa e perfis sem acesso adequado não recebem novas atribuições. |
| Histórico | Utilizadores entretanto inativos continuam identificados nos registos anteriores. | Desativar um utilizador de teste e consultar um registo que lhe estava atribuído. |
| Administração → Áreas/Processos | Ações explícitas Editar e Ativar/Desativar. A edição conserva o identificador e as relações. | Alterar a designação, desativar e reativar uma área de teste. |
| Áreas/Processos e referenciais inativos | Excluídos de novas escolhas, conservando o histórico. Eliminação física de áreas bloqueada. | Consultar uma auditoria ou ocorrência anterior depois da desativação. |

## Resultados da validação

| Verificação executada | Resultado |
|---|---|
| 85 verificações de integração com a base de dados, incluindo migração e reversão dos dados de teste | PASS |
| 8 testes unitários do servidor | PASS |
| 8 testes unitários da interface, incluindo datas e anos bissextos | PASS |
| Compilação da aplicação e verificação TypeScript | PASS |
| Verificação de sintaxe do servidor e das alterações | PASS |
| Navegador: referenciais, auditoria, calendário, constatação, persistência e áreas | PASS |
| Formulário de constatação em computador e telemóvel, sem transbordamento horizontal nem erros JavaScript | PASS |
| Regressão da configuração: guardar, classificações adicionais, desativação e histórico | PASS |
| Regressão completa: auditoria → constatação → causa → ação → evidência → eficácia → reabertura → resposta externa → pesquisa | PASS |
| Ação autónoma e comentário | PASS |
| 10 verificações após publicação, no acesso local e no endereço externo, incluindo recusa de acesso sem sessão | PASS |

Não existem testes críticos em FAIL na bateria executada. Os testes funcionais usaram dados sintéticos numa base separada; as verificações no endereço publicado foram de leitura.

## Dados e comportamentos preservados

Foi realizada uma cópia de segurança antes da migração. A comparação antes/depois confirmou a preservação dos registos e campos anteriores de **1 auditoria, 54 áreas/processos, 5 entradas de catálogo, 24 perfis e 2021 entradas do histórico**. Não existiam ocorrências, ações ou anexos nessa base no momento da comparação.

As relações novas complementam o modelo existente. Não foram eliminados registos nem substituídos os textos antigos de âmbito. Os referenciais usados nas novas ocorrências diretas também são associados ao catálogo por identificador.

Os nomes de áreas e origens passam a ser únicos por empresa, permitindo que empresas diferentes usem designações iguais. As permissões são verificadas no servidor e a gestão de áreas deixa de depender de escritas diretas pela interface.

## Notas para os testes da equipa

- Em auditorias antigas, o texto livre das áreas só é convertido automaticamente quando existe correspondência exata com o catálogo. Quando não existir, editar a auditoria e selecionar as áreas corretas antes de registar novas constatações. O texto anterior permanece preservado.
- Uma nova versão normativa deve ser criada como novo referencial. A aplicação deteta a alteração do ano de versão na designação; não interpreta o conteúdo de documentos normativos.
- A política adotada para áreas é desativar, sem eliminação física, incluindo áreas sem utilização. A eliminação era opcional na especificação.
- O envio real de emails mantém a limitação anterior: depende da configuração do serviço de email. Não foi usado como evidência de validação destas correções.
- A compilação mantém avisos de tamanho de alguns ficheiros da aplicação; não impediram a compilação ou os testes.
- Não foi feito commit nem push nesta intervenção.

## Registo da aceitação

**Empresa:** ____________________  **Responsável:** ____________________

**Data:** ____________________  **Versão confirmada:** ____________________

**Resultado:** [ ] Aceite para utilização  [ ] Requer ajustes  [ ] Verificação incompleta

**Ecrã e situação observada:**

____________________________________________________________________

____________________________________________________________________

## Referência técnica da entrega

Migração aplicada: `0058_quality_test_corrections.sql`.

Componentes principais alterados: `QualityWorkspacePage.vue`, `QualityCommandForm.vue`, `QualityOperationalSettings.vue` através da lista de pessoas fornecida, `AdminPage.vue`, `PlatformModule.vue`, `PtDateInput.vue`, `domain/dates.ts`, `utils/format.ts`, `quality-baseline.js`, `quality-context.js` e `quality-operational.js`.

Os campos e apresentações de datas foram também atualizados em CandidateWizard, CandidateCvView, LifecycleRhsPage, OccurrenceNewPage, OccurrenceDetailPage, ReportsPage, AiAssistantPage, StrategyPlanPage e StrategyRisksPage. Os testes de configuração e regressão existentes foram adaptados aos novos campos, além dos novos testes específicos.

Versão atualizada em `frontend/package.json`, `frontend/package-lock.json` e `frontend/src/version.ts`.

Cópia de segurança: `C:/a/samsys-qualidade/backups/before-test-corrections/2026-10-02T16-52-40-023Z`.

Recuperação: preservar a base atual e restaurar a cópia de segurança numa base separada para validação. Não remover as novas relações depois de existirem novos registos; preferir uma correção adicional. A migração foi testada em transação com rollback e aplicada de forma transacional.
