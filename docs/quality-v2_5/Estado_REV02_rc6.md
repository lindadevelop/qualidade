# Estado da implementação REV02

Data: 07/10/2026. Versão publicada: **0.5.0-rc.6**.
Referência: 03_DELTA_EXECUTAVEL_REV02_PLATAFORMA_ESTRATEGICA_SAMSYS_06-10-2026_FINAL.docx.
Ambiente de teste público: https://progressive-suburban-entity-twelve.trycloudflare.com/

As alterações foram aplicadas incrementalmente, com cópia de segurança. A recuperação de senha funciona no teste com entrega SMTP local; a entrega externa continua pendente de configuração no ambiente público. Não foram enviados emails reais durante os testes.

## Resultado por requisito

| ID | Estado | Alteração e local | Evidência de verificação |
|---|---|---|---|
| PE-R02-01 | Implementado | Contexto Administração geral no topo; configuração partilhada identificada; equipas e acessos continuam separados. Administração abre em Utilizadores. | Navegador: contexto transversal visível; ficha com equipas reais e perfis distintos. |
| PE-R02-02 | Implementado | Organizações → Membros orienta para a ficha única em Administração → Utilizadores, onde se gerem várias equipas, funções e datas. Mensagem específica para associação organizacional duplicada. | Navegador: conta com três equipas e dois perfis; reabertura; remoção de uma atribuição mantém as outras; eliminação da conta de teste sem uso. Integração: terminar atribuição preserva campanha anterior. |
| PE-R02-03 | Parcial no ambiente público | Definição inicial e redefinição administrativa mantidas. Novo percurso de recuperação com token de utilização única, validade de 30 minutos, confirmação de senha, hash e revogação de sessões. | Conta participante iniciou sessão. SMTP local recebeu email; ligação abriu formulário, senha foi alterada e novo login passou. Integração: confirmação, expiração, reutilização, alteração de sessão e falha de entrega. **Falta configurar o envio no ambiente público e validar receção externa.** |
| PE-R02-04 | Implementado nas campanhas REV02 | Novo na SWOT oficial encaminha para a recolha contextual da campanha. Área, âmbito e equipa alvo obrigatórios quando aplicáveis; autoria/data automáticas; filtros de área/contexto. | Navegador: registo pela conta participante; ligação Novo; filtros disponíveis. Integração: validação dos campos e preservação de área/equipa na publicação. |
| PE-R02-05 | Implementado nas campanhas REV02 | Painel nominal de participantes com contagens e pendências por bloco, incluindo Não iniciou, Em curso, Concluído e Concluído com exceção. | Integração: duas pessoas com contagens independentes; nove contributos numa equipa não completam o corporativo. Navegador: estado de exceção e pendências visíveis. |
| PE-R02-06 | Implementado nas campanhas REV02 | Bloco por equipa representada e um bloco corporativo único; propostas para outras equipas opcionais. Contextos ficam registados na campanha. | Integração: pessoa com duas equipas recebe três blocos; com uma recebe dois. Terminar atribuição afeta campanha futura, preservando a anterior. Navegador: três blocos da conta participante. |
| PE-R02-07 | Implementado nas campanhas REV02 | Coordenador autorizado pode concluir abaixo da recomendação com motivo, data e autor. Máximos continuam aplicados. Publicação não exige inventar novos contributos. | Integração: duas ideias, exceção justificada, autorização recusada a participante; publicação aprovada preserva contexto. Avançar campanha não conclui outra pessoa. Navegador: exceção seguida de publicação na SWOT oficial. Os itens oficiais continuam disponíveis à TOWS; não foi criada uma TOWS nova no teste visual desta revisão. |
| PE-R02-08 | Implementado nos componentes abrangidos | Paleta/fontes nos contextos, cartões, botões, ligações, estados e gráficos atualizados. Amarelo Samsys corrigido para #FFB50F na identidade da empresa. | Três ecrãs inspecionados: Administração, Qualidade e Estratégia. Novo login/refresh confirmou Manrope e paleta; cartões da Qualidade usam a cor secundária. Build validou gráficos de Relatórios, Revisão pela Gestão e KPI. Não foi feita uma auditoria exaustiva de acessibilidade de todos os ecrãs. |
| PE-R02-09 | Implementado nas campanhas REV02 | Importação contextual com quadrante herdado ou explícito, autor validado, rastreio de lote/importador e erros por linha. Apenas linhas inválidas permanecem para correção. | Navegador: quatro Forças importadas, uma linha inválida identificada. Integração: autor inexistente recusado; importação por pessoa sem gestão recusada; Outra equipa mantém proposta por validar. |
| PE-R02-10 | Implementado | Descrição opcional editável; ausência de descrição não gera texto operacional inútil. | Navegador: ausência de Sem descrição; descrição adicionada, guardada e visível após refresh. |
| PE-R02-11 | Implementado | Templates PowerPoint → Utilização / eliminar. Sem uso: eliminar. Com dependências/histórico: impedir eliminação e permitir desativar. Mesma ação disponível nas estruturas suportadas. | Navegador: template temporário criado e eliminado. Integração: template ligado a ficheiro gerado protegido e desativável. Seletor de novas apresentações continua limitado aos ativos. |

## Campanhas anteriores

A migração mantém as campanhas anteriores na revisão 1 e atribui a revisão 2 às novas. Assim, os IDs, originais, contagens e regras de campanhas já em utilização não são reinterpretados automaticamente. Um rascunho sem contributos pode ser atualizado para REV02 pela ação na campanha. Campanhas antigas já utilizadas devem manter o percurso anterior; para validar as novas regras, criar uma campanha REV02. O guia rc.5 é substituído pelo novo guia no que respeita aos blocos e à conclusão das campanhas REV02.

## Validação executada

- Compilação TypeScript/Vite da versão rc.6 concluída. Permanecem avisos de dimensão de bundles e de imports dinâmicos já presentes.
- 135 verificações de integração passaram numa transação revertida, incluindo 14 verificações novas REV02. Os testes não deixaram dados no ambiente público.
- 8 testes unitários do backend e 8 do frontend passaram.
- 10 verificações de navegador REV02 e 4 de gestão de utilizadores passaram no ambiente QA separado.
- 5 verificações complementares passaram: marca/contexto em três ecrãs, descrição persistida e rejeição de ligação de recuperação inválida.
- 14 verificações locais/públicas passaram após publicação: HTML publicado, endpoints dos três módulos, utilizadores e bloqueio de acesso sem autenticação.
- Guia Word com seis páginas renderizadas e inspecionadas.

## Preservação e publicação

Migração aplicada: `supabase/migrations/0063_strategy_rev02.sql`.

Cópia anterior: `C:/a/samsys-qualidade/backups/before-delta-rc6/2026-10-07T06-47-19-196Z`.

Na transação de migração foram comparados todos os campos anteriores das tabelas verificadas: 24 perfis, 66 atribuições, 3 campanhas, 6 itens oficiais, 16 contributos, 0 submissões, 3 identidades, 3 frameworks, 3 ciclos, 18 equipas e 2 templates. Todos foram preservados. Depois dessa comparação, foi alterado apenas o campo de aviso da identidade Samsys, de forma auditada; fontes e imagens não foram substituídas.

Os ficheiros compilados foram publicados no serviço existente. O serviço de autenticação foi reiniciado e a verificação pelo endereço público passou. Não foi criado commit nem feito push nesta intervenção.

## Ficheiros principais por requisito

Caminhos relativos a `C:/a/samsys-qualidade`.

| Requisito | Ficheiros |
|---|---|
| 01–02 | `frontend/src/layouts/AppLayout.vue`; `frontend/src/pages/AdminPage.vue`; `frontend/src/pages/admin/AdminOrganizationsPage.vue`; `frontend/src/services/platform.ts`. Reutilização de `UserAdministration.vue` e atribuições já existentes. |
| 03 | `backend/password-recovery.js`; `backend/auth-server.js`; `frontend/src/pages/ResetPasswordPage.vue`; `frontend/src/pages/RecoverPasswordPage.vue`; `frontend/src/router/index.ts`; migração 0063. |
| 04–07 e 09 | `backend/strategy-participation.js`; `backend/strategy-context.js`; `backend/strategy-administration.js`; `backend/swot-consolidation.js`; `frontend/src/components/SwotParticipationPanel.vue`; `frontend/src/components/SwotContextCollection.vue`; `frontend/src/pages/strategy/StrategyCampaignsPage.vue`; `frontend/src/pages/strategy/StrategySwotPage.vue`; migração 0063. |
| 08 | `frontend/src/composables/useBrandKit.ts`; `frontend/src/style.css`; `frontend/src/layouts/AppLayout.vue`; `frontend/src/pages/ReportsPage.vue`; `frontend/src/pages/ManagementReviewPage.vue`; `frontend/src/pages/LifecycleRhsPage.vue`; `frontend/src/pages/strategy/StrategyKpiPage.vue`; atualização auditada da identidade Samsys. |
| 10 | `frontend/src/pages/strategy/StrategyCampaignsPage.vue`; `frontend/src/pages/strategy/StrategySwotPage.vue`. |
| 11 | `frontend/src/components/PlatformModule.vue`; `backend/strategy-context.js`; migração 0063; reutilização da proteção de estruturas da migração 0062. |
| Testes e versão | `backend/tests/rev02-cases.cjs`; `backend/tests/strategy-context-cases.cjs`; `backend/tests/quality-v25-database.cjs`; `frontend/tests/rev02.e2e.cjs`; `frontend/package.json`; `frontend/package-lock.json`; `frontend/src/version.ts`. |

## Pendência de ambiente

O transporte de recuperação está indisponível na configuração pública atual. É necessário configurar, no servidor, `AUTH_RECOVERY_EMAIL_ENABLED=true`, `SMTP_HOST`, `SMTP_PORT`, `SMTP_SECURE`, `SMTP_FROM`, `QUALITY_PUBLIC_URL` e, quando o servidor exigir autenticação, `SMTP_USER` e `SMTP_PASSWORD`. As credenciais devem permanecer na configuração privada do servidor. Depois, reiniciar autenticação e testar a receção numa conta autorizada. A ligação pública deve corresponder ao endereço efetivamente utilizado pelos destinatários.

A aplicação já permite redefinição administrativa de senha e apresenta erro de envio indisponível, sem afirmar falsamente que o email foi enviado.

Verificação adicional no endpoint público de recuperação: devolveu HTTP 503 com indicação explícita de envio não configurado, usando endereço de teste inexistente. Nenhum email externo foi enviado. Serviços temporários de QA e SMTP local foram terminados; serviços públicos mantidos ativos.
