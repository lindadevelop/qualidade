# IMPLEMENTATION_REPORT_V2_5

## 1. Build/versão

Release candidata **0.5.0-rc.1**, validada em 01/10/2026. Projeto existente Vue 3/Vite + Node + PostgreSQL/PostgREST mantido. Base Git `36141b6`, com alterações locais; não foi criado commit nem efetuado push nesta implementação.

Especificação v2.5 integral e pedido colado analisados antes do código. O diagnóstico original está em `docs/quality-v2_5/gap-analysis-inicial.md`. Prioridade aplicada: secção 0, secções 129–134, baseline, detalhe, roadmap.

Ambiente de testes atualizado: https://progressive-suburban-entity-twelve.trycloudflare.com/. O túnel foi preservado. A disponibilidade no funil destina-se a teste/UAT; **não representa aprovação de produção**. Quality Gate de produção: **BLOCKED**, enquanto faltar UAT e validação operacional aplicável.

SHA-256 do `index.html` candidato: `32df1dfafb7dd105cd2afe86724256c7d569f81d9c3f1968088b7e42dd25e2af`.

## 2. Gap Analysis

PASS significa implementação e verificações descritas neste relatório; não significa certificação ou aprovação de negócio. PARTIAL identifica configuração/decisão ainda pendente. A terceira coluna resume o trabalho aplicado a partir do diagnóstico inicial.

| Área | Antes | Alteração | Estado |
|---|---|---|---|
| Base de dados | Entidades NC/OM, ações e planos existentes | Migrations aditivas; preservar legado | PASS |
| Auditorias | Ausente | Interna/externa, campos condicionais e documentos | PASS |
| Constatações | Ausente | Relação única com ocorrência, texto original protegido | PASS |
| NC / OM | CRUD existente | Origem por relação, OM sem causa/eficácia obrigatória por defeito | PASS |
| Tratamento | Plano técnico e UI autónoma | Integrar na ocorrência, manter tabelas | PASS |
| Análise / causa raiz | Apenas análise livre | Separar conclusão e confirmação humana | PASS |
| Correção / ação corretiva | Tipos técnicos parciais | Cinco tipos e decisão justificada | PASS |
| Ações | CRUD, estados, responsáveis | Tipo, critérios, prazo original, confirmação e RBAC por campos | PASS |
| Evidências | UI Supabase Storage incompatível com servidor local; downloads sem autorização | Upload/download autenticado por entidade/empresa | PASS |
| Aprovação | Planos com decisões gravadas separadamente | Operação atómica, decisões imutáveis, devolver/ressubmeter | PASS |
| Eficácia | Campos substituídos em ocorrência | Histórico por ciclo, critério/evidências/autor | PASS |
| Encerramento | Valida eficácia, mas não causa e ações | Validação completa no servidor e motivos na UI | PASS |
| Reabertura | Sem motivo obrigatório | Motivo, ciclo e preservação das avaliações | PASS |
| Anulação | Eliminação física existente | Anulação justificada; excluir indicadores | PASS |
| Estado interno | Trigger incompleto ao criar ação durante eficácia | Corrigir transições, não encerrar por concluir ação | PASS |
| Estado externo / resposta auditor | Ausente | Histórico independente e texto recebido preservado | PASS |
| Tomada de conhecimento | Ausente | Autor/data/hora, reiniciar na reatribuição | PASS |
| Prazos | Sobrescrita sem motivo | Histórico e aprovação configurável | PASS |
| O meu trabalho | Ausente | Tarefas acionáveis do utilizador | PASS |
| Próximo passo / completude | Ausente | Regras partilhadas servidor/UI | PASS |
| Dashboard | Indicadores existentes | Seis indicadores acionáveis, anulação excluída | PASS |
| Pesquisa global | Campo sem comportamento | Auditorias/NC/OM/ações com filtros | PASS |
| Notificações | Tabela e sino existentes; eventos incompletos | Eventos transacionais e centro com links | PASS |
| Email / fila / retry / deduplicação | Sem outbox nuclear | Fila persistente, retries configuráveis, reenvio | PARTIAL |
| RBAC / permissões | Perfis e tenant; atualizações próprias demasiado amplas | Backend por operação/campos e sessão atual | PASS |
| Audit Log | Trigger existente, cobertura parcial | Histórico imutável com empresa da entidade | PASS |
| Exportação | NC Excel/PDF, limite fixo de linhas | Export controlado do conjunto funcional | PASS |
| Sem Internet | URL Cloudflare incorporado nos clientes | Base relativa à origem; recursos locais | PASS |
| Organização / tenant | Isolamento de tabelas implementado em 0053 | Aplicar aos novos objetos e anexos | PASS |
| Entitlements | Módulos por perfil, flags centralizadas parcialmente | Preservar, sem motor comercial | PASS |
| Testes | Estratégia, utilizadores, limpeza; sem baseline QMS | Unitários, integração, negativos e E2E | PASS |
| Segurança | Sessões versionadas; storage sem autorização | Corrigir acesso aos novos anexos e formalizações | PASS |
| Backup / restore | Backups manuais antes de migrações | Validar restauração e documentar operação | PASS |
| Limpeza definitiva | Implementada a pedido anterior | Conflito com anulação/retenção da v2.5; decisão solicitada | PARTIAL |
| UAT / aprovação de produção | Não realizada para v2.5 | Entregar candidato e roteiro; aprovação pelo negócio | BLOCKED |
| Billing, trials, licenciamento comercial, workflows visuais, graph, previsão | Não necessários ao núcleo | Não implementar | ROADMAP |

## 3. Implementado

- Auditorias internas/externas com formulário condicional, documentação, conclusões e constatações. Uma constatação NC/OM é a própria ocorrência relacionada, sem duplicação. Outras classificações têm registo próprio. Texto original protegido.
- Tratamento integrado na ocorrência: análise livre, causa raiz com confirmação humana, decisão corretiva justificada, cinco tipos de ação, responsável, conhecimento, prazos original/atual e critérios de conclusão/eficácia. Planos anteriores permanecem consultáveis.
- Ações atribuídas, comentários, evidências e conclusão. Melhorias autónomas também permitem comentários. Cancelamento fundamentado preserva os registos e impede reativação implícita.
- Aprovar/devolver/rejeitar e ressubmeter com decisões anteriores preservadas. Pedido de prazo com motivo, aprovação/rejeição e notificação ao responsável.
- Validação de causa, ações, evidências, aprovação e eficácia antes de encerrar. Última ação não encerra a ocorrência. Eficácia positiva encerra; negativa mantém histórico e abre novo ciclo. Reabertura exige motivo.
- Estado externo e respostas ao auditor separados do estado interno, incluindo evidências, texto recebido e verificação futura.
- O meu trabalho, próximo passo, completude, seis indicadores clicáveis e pesquisa por referência/texto, ano, tipo/estado, origem, auditoria, área, responsável e entidade auditora. Anulados ficam disponíveis para consulta e saem dos indicadores operacionais.
- Notificações transacionais, outbox persistente, deduplicação, retries configuráveis (5/30/120 minutos), reenvio manual auditado e aviso à Qualidade após cinco dias úteis de atraso. SMTP executado fora da transação funcional. Contagem inicial de dias úteis considera segunda a sexta; não existe calendário de feriados configurado.
- Comandos autenticados por operação/campos, empresa e sessão atual, concorrência por versão e histórico imutável. Downloads de evidência exigem autorização. Acesso a CVs antigos associado à empresa através de 19 referências existentes.
- API baseada na origem atual e fontes locais para operação em intranet. IA e Internet não são necessárias ao fluxo nuclear.
- Exportação JSON dos dados funcionais autorizados, incluindo histórico e configurações; documentos descarregados individualmente. A vista da fila limita-se aos 200 emails mais recentes e às 100 notificações pessoais mais recentes; exportação desta vista mantém esses limites.
- Backup automático diário da base e ficheiros, verificação do formato do dump, manifesto e registo da última execução. Sem eliminação automática de backups.

## 4. Ficheiros alterados

Principais ficheiros desta baseline (as alterações anteriores de Estratégia, identidade visual e utilizadores foram preservadas):

- `supabase/migrations/0055_quality_baseline_v2_5.sql` e `0056_quality_autonomous_comments.sql`.
- `backend/quality-baseline.js`, `quality-outbox.js`, `quality-backup.js`, `quality-email.env.example` e integração em `auth-server.js`.
- `backend/file-access.js`, `storage-server.js`, `cv-processor-server.js` e proteção da limpeza em `data-maintenance.js`.
- `frontend/src/pages/QualityWorkspacePage.vue`, `components/QualityCommandForm.vue`, `services/quality.ts`, `lib/api-base.ts`, router e layout.
- Clientes HTTP existentes adaptados à origem atual; lista de ocorrências/indicadores excluem anulados. `LifecycleRhsPage.vue` descarrega CV com sessão.
- `frontend/src/components/DataMaintenance.vue`, versão/pacotes, `frontend/vite.config.ts`, `.gitignore` e `scripts/start-stack.ps1`.
- `backend/tests/quality-v25.test.cjs`, `quality-v25-database.cjs`; testes antigos de Estratégia/Plataforma ajustados à hierarquia atual de administradores.
- `frontend/tests/quality-v25.e2e.cjs` e documentação em `docs/quality-v2_5/`.

## 5. Base de dados

Migrations **0055 e 0056 aplicadas**. 0055 cria auditorias, catálogos, constatações adicionais, avaliações de eficácia, decisões de aprovação, alterações de prazo, respostas externas, configurações e outbox. Acrescenta às ocorrências/ações campos de origem, causa, atribuição, conhecimento, critérios, decisão, versão, ciclo e anulação. Anexos admitem associação à auditoria, avaliação e resposta externa. 0056 permite comentários em ações autónomas, exigindo sempre ocorrência ou ação.

Índices incluem empresa/ano de auditoria, ocorrência/auditoria, ocorrência/ciclo de eficácia, pedidos pendentes e outbox pronta para envio. Unicidade de evento/destinatário/canal assegura deduplicação. Constraints validam tipos/decisões e datas. RLS protege leitura por sessão/módulo/empresa; escritas formais passam pelos comandos autenticados. Triggers protegem original, histórico, versões e encerramento. Views operacionais com `security_invoker` mantêm o isolamento e excluem anulados.

Não foram apagados dados, evidências ou histórico. Antes/depois da 0055 compararam-se os campos previamente existentes de dez tabelas: 24 perfis, 2016 entradas de audit log, 18 casos e 17 pessoas LifeCycle, um objetivo e uma ação estratégica. As tabelas nucleares de Qualidade verificadas já estavam vazias antes da migração. Os hashes dos campos existentes permaneceram iguais.

Backups prévios:

- `backups/before-v25/2026-10-01T19-41-41-362Z/`: dump verificado, ficheiros, distribuição frontend anterior e snapshot do código candidato.
- `backups/before-v25-comments/2026-10-01T19-47-25-650Z/`: antes da 0056.
- Backup automático confirmado em `backups/automatic/2026-10-01T19-43-43-255Z/`.

Rollback: as migrations executam em transação, com rollback integral se falharem antes do commit. Depois de existirem dados v2.5, não executar DROP nem reverter permissões isoladamente. Preferir correção aditiva. Para recuperação, restaurar dump e ficheiros numa base/diretório separados, verificar integridade e só depois efetuar troca controlada. Repor apenas a UI anterior seria incompatível com as novas regras de escrita. Nunca sobrescrever dados posteriores sem decisão expressa sobre recuperação. Procedimento em `OPERACAO_E_UAT.md`.

## 6. Testes

| Teste | Resultado |
|---|---|
| Build Vue/TypeScript/Vite candidato | PASS |
| Verificação sintática dos serviços Node alterados | PASS |
| `git diff --check` | PASS |
| Unitários backend: 8 testes, incluindo PPT e regras QMS | PASS |
| Unitários frontend: 7 testes de CSV/validação/estratégia | PASS |
| Integração nuclear em transação com rollback: 50 verificações | PASS |
| Regressão Estratégia em transação: 16 verificações | PASS |
| Regressão Plataforma em transação: 21 verificações | PASS |
| Hierarquia superadmin/empresa/permissões: 21 verificações | PASS |
| E2E Edge com autenticação e API reais e dados sintéticos: auditoria→NC→causa→ação→evidência→eficácia→reabertura→resposta externa→pesquisa, e comentário de ação autónoma | PASS |
| Mesmo E2E bloqueando todos os pedidos fora da origem local; erros JavaScript | PASS — sem dependências externas nem erros observados |
| Restore de base sintética: hashes de 9 tabelas e 2 ficheiros comparados, cerca de 2,3 s | PASS |
| Smoke do funil e localhost: distribuição correta, APIs Qualidade/Estratégia/LifeCycle e negação sem sessão | PASS — 10 verificações |
| SMTP indisponível, retries, destinatário inválido, recuperação e deduplicação com transporte simulado | PASS |
| Entrega SMTP real a caixa de correio | BLOCKED — falta configuração/validação operacional |
| Lint dedicado | BLOCKED — projeto não possui configuração/runner; TypeScript, sintaxe e whitespace verificados |
| Carga/volume de produção, RTO/RPO contratual, cópia externa e retenção aprovada | BLOCKED — por validar em operação |
| UAT com Qualidade e responsável de negócio | BLOCKED — por executar/aprovar |

Resultados individuais dos 50 testes: `docs/quality-v2_5/integration-results.json`. Evidências de restore, deployment e smoke estão no mesmo diretório. Os testes transacionais não deixaram dados de teste na base operacional. E2E usou `samsys_quality_v25_qa_final`, não a base do funil.

Avisos de build existentes: chunks de gráficos grandes e importação estática/dinâmica de LifeCycle. Não são erros de compilação. A medição com base sintética não prova desempenho com volume real.

## 7. Defeitos encontrados

| Defeito / impacto | Correção |
|---|---|
| Encerramento sem causa ou ações completas | Gates no servidor e trigger; lista explícita do que falta |
| Sobrescrita de eficácia e decisões | Registos por ciclo e histórico imutável |
| Concluir última ação confundia conclusão com encerramento | Transição para eficácia, com validação humana posterior |
| Data PostgreSQL deslocada pelo fuso horário | DATE tratada como data de calendário |
| Atualização ampla por responsável permitia alterar atribuições | Allowlist de campos e autorização por comando |
| Originais e histórico alteráveis | Proteções contra atualização/eliminação |
| Downloads públicos / hash conhecido permitia acesso a CV | Sessão atual, módulo, empresa e manifesto de propriedade |
| URL externa incorporada impedia intranet sem Internet | API na origem atual e recursos locais |
| Anulações contavam nos indicadores e ações anuladas podiam ser reativadas implicitamente | Views/filtros operacionais e bloqueio do comando |
| Pedido de prazo sem rejeição acessível na UI | Aprovar/rejeitar com motivo e histórico |
| Ação autónoma não podia receber comentário | Migration 0056, comando e UI, testados |
| Campos de eficácia na criação de ação não persistiam | Persistência dos campos opcionais e edição no formulário |

## 8. Pontos pendentes

1. SMTP real: indicar servidor, porta, remetente, segurança e credenciais no ambiente/ficheiro local protegido. Não colocar palavras-passe em chat ou Git. O envio está desativado por defeito; a fila permanece persistente.
2. UAT e Quality Gate de produção. O candidato está disponível para demonstração e teste, não aprovado como release de produção.
3. Validação operacional de carga, retenção, armazenamento externo de backups, alertas e ensaio de recuperação na infraestrutura definitiva. A cópia automática atual é local à máquina e não protege contra perda desse disco.
4. Credenciais/segredos de desenvolvimento preexistentes e configuração de TLS devem ser revistos e rodados antes de exposição de produção. Não foram publicados neste relatório nem alteradas palavras-passe de utilizadores.
5. O workspace nuclear carrega o conjunto da empresa sem paginação; antes de volumes elevados, medir tempos e memória e aplicar paginação conforme resultados. A exportação da fila/notificações tem os limites descritos acima.

## 9. Pontos de decisão

- **Retenção vs limpeza definitiva da Qualidade:** o pedido anterior de apagar dados conflita com a v2.5. Na baseline prevalece anulação, e a limpeza definitiva de Qualidade está bloqueada. LifeCycle/Estratégia mantêm a limpeza anteriormente autorizada. Uma eventual exceção exclusiva de testes exige decisão do Product Owner; nenhuma limpeza foi executada nesta entrega.
- Qualidade/Product Owner devem aprovar o UAT e a passagem a produção.
- Operações/negócio devem definir retenção de backups e objetivos de recuperação. Até essa definição não existe eliminação automática.

## 10. Segurança e dados

Sessão ativa e respetiva versão verificadas em cada comando. Administrador de empresa limitado à sua empresa; superadministrador exclusivo existente preservado. Responsável não decide eficácia nem reatribui ações. Aprovação pertence ao aprovador designado. Atualizações concorrentes devolvem conflito e pedem recarregamento.

Downloads autenticados não expõem URL pública reutilizável. Ficheiros novos têm identificador gerado pelo servidor, limite de 10 MB, formatos permitidos e PDF verificado por assinatura. Sem substituição da evidência original. Se uma transação de upload falhar depois da escrita física, pode ficar um ficheiro órfão sem referência acessível; não é removido automaticamente para evitar perda de evidência.

Falha SMTP não bloqueia operações. Entrega interrompida em estado incerto exige verificação/reenvio manual; não se promete entrega exatamente uma vez pela infraestrutura SMTP. Logs e decisões formais permanecem. Não foram efetuados testes de intrusão externos nem certificação de segurança.

## 11. Roadmap não implementado

Editor visual de workflows, form builder completo, billing/trials/campanhas, portal comercial, Quality Graph, previsão, Quality Health avançado, Continuous Quality Platform, anti-tampering sofisticado e decisões autónomas por IA. IA existente continua assistiva; ausência de IA não impede o SGQ.

## 12. Próximos passos recomendados

1. Executar o roteiro UAT em `docs/quality-v2_5/OPERACAO_E_UAT.md` com responsáveis reais e registar aprovação/observações.
2. Configurar SMTP, testar uma atribuição controlada e a recuperação de indisponibilidade, e só depois ativar envio.
3. Validar infraestrutura, segredos/TLS, volume real, retenção, cópia de backup externa e recuperação.
4. Corrigir eventuais resultados do UAT e registar a decisão do Quality Gate antes de promover a produção.
