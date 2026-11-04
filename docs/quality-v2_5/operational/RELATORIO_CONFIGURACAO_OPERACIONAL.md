# RELATÓRIO DE IMPLEMENTAÇÃO

## Build/versão

**0.5.0-rc.2**, projeto existente `C:/a/samsys-qualidade`, base Git `36141b6` com alterações locais preservadas. Sem commit/push nesta tarefa. Implementação e validação em 02/10/2026.

Disponível para testes no funil existente: https://progressive-suburban-entity-twelve.trycloudflare.com/qualidade/configuracao. Atualizar com Ctrl+F5. O túnel não foi encerrado.

SHA-256 de `frontend/dist/index.html`: `cf0e8b61ec280c2fd31886840658ab7fe4c667a7c3751273ec31eafcfc94f5be`.

## Ficheiros alterados

- `C:/a/samsys-qualidade/.gitignore`
- `C:/a/samsys-qualidade/backend/package.json`
- `C:/a/samsys-qualidade/backend/quality-baseline.js`
- `C:/a/samsys-qualidade/backend/quality-operational.js`
- `C:/a/samsys-qualidade/backend/quality-outbox.js`
- `C:/a/samsys-qualidade/backend/tests/quality-v25-database.cjs`
- `C:/a/samsys-qualidade/backend/tests/quality-operational-cases.cjs`
- `C:/a/samsys-qualidade/frontend/package.json`
- `C:/a/samsys-qualidade/frontend/package-lock.json`
- `C:/a/samsys-qualidade/frontend/src/version.ts`
- `C:/a/samsys-qualidade/frontend/src/components/QualityOperationalSettings.vue`
- `C:/a/samsys-qualidade/frontend/src/components/QualityCommandForm.vue`
- `C:/a/samsys-qualidade/frontend/src/pages/QualityWorkspacePage.vue`
- `C:/a/samsys-qualidade/frontend/tests/quality-operational.e2e.cjs`
- `C:/a/samsys-qualidade/supabase/migrations/0057_quality_operational_settings.sql`

Documentação e evidências desta alteração: `C:/a/samsys-qualidade/docs/quality-v2_5/operational/`. Os ficheiros modificados por tarefas anteriores, incluindo AssistSys, não foram alterados por esta tarefa fora da lista acima. AssistSys foi apenas inspecionado antes da correção do pedido.

## Base de dados

- Migration criada: **Sim**.
- Nome: `0057_quality_operational_settings.sql`.
- Estado: testada em transação com rollback e em base sintética; aplicada na base do funil em 2026-10-02T11:44:49.408Z.
- Estruturas existentes reutilizadas: `quality_settings`, `quality_catalogs`, `quality_occurrences`, `audit_log` e `quality_outbox`.
- Novos campos de configuração: `overdue_reminder_days`, `quality_escalation_days`, `leader_escalation_days` e `escalation_leader_id`. Não existia uma relação de líder aplicável à Qualidade; foi acrescentada uma escolha opcional por empresa, sem novo módulo de gestão de equipas.
- Catálogo existente passa a admitir `nc_classification` e `is_system`; reutiliza `active` para o estado. `used_count` é calculado a partir das NC, sem coluna duplicada.
- NC Menor e NC Maior são criadas como base protegida para empresas existentes e novas. Proteções impedem remover/desativar/renomear a base e renomear classificações já utilizadas.
- Arrays antigos de constatações e textos históricos são preservados. Valores adicionais são copiados para o catálogo de NC; Observação só é copiada se já tiver sido efetivamente usada numa NC, não por constar do antigo default. Uma organização pode adicioná-la conscientemente.
- Os defaults são alterados sem UPDATE dos lembretes/retries existentes. Na base atual não existiam linhas personalizadas em `quality_settings`; a preservação de `90,60,30` e de retries personalizados foi demonstrada com dados sintéticos prévios à migration.

Backup prévio: `C:/a/samsys-qualidade/backups/before-operational/2026-10-02T11-44-47-780Z`. Inclui dump verificado, ficheiros e frontend anterior. A comparação antes/depois confirmou a preservação do catálogo anterior, das ocorrências e dos **2017 registos de audit log**; os campos antigos de configurações não foram substituídos.

Reversibilidade: a migration usa uma transação, com rollback completo em caso de falha. Depois de criar novas configurações/classificações, não executar um down que elimine esses dados; preferir correção aditiva. Em recuperação técnica, restaurar o backup numa base separada e validar antes da troca. Não foi executada qualquer operação destrutiva.

## Alterações realizadas

1. A Configuração Operacional é editada diretamente na página existente, com **Cancelar | Guardar**, sem modal adicional e sem checkbox de confirmação. O backend também não exige `human_confirmed` para `settings_save`; os comandos formais de NC/OM mantêm a confirmação existente.
2. Defaults mantidos em **7,3,1 dias** e **5,30,120 minutos**. Intervalos validados, persistentes e auditados. Guardar não altera o catálogo antigo de constatações nem configurações não relacionadas.
3. Aprovação de prazo permanece uma opção booleana. Com aprovação desligada, a mudança exige motivo e preserva prazo original; ligada, aguarda decisão autorizada. Sem workflow novo.
4. Base de classificações visível e protegida; adicionais visíveis antes de adicionar, com edição inline, ativação e desativação. Não existe eliminação física na interface. Nomes de classificações usadas ficam bloqueados; o estado pode ser alterado.
5. Criação de NC apresenta apenas classificações ativas da empresa; o servidor volta a validar a escolha. A ficha histórica mostra a classificação mesmo depois de desativada.
6. `Mais detalhes` só é renderizado quando existem campos adicionais visíveis. A alteração ao formulário partilhado limita-se a esta regra funcional, sem redesign nem remoção das confirmações de operações críticas.
7. Avisos posteriores ao prazo configuráveis: responsável nos dias **1 e 3**, Qualidade ao **5.º dia útil**, líder ao **10.º dia útil** quando selecionado. Os escalonamentos também respeitam valores personalizados, comprovados com 6/12 dias. Sem líder configurado, não há destinatário arbitrário.
8. Estado visual **Em atraso** calculado sem alterar a máquina de estados da ação. Avisos de prazo curto apenas são gerados para datas ainda possíveis.
9. Retry/deduplicação preservados. Depois de esgotar tentativas, a UI mostra **Falha no envio** e mantém **Reenviar**. O worker continua separado das operações funcionais.
10. Audit log regista configuração anterior/nova, utilizador e data, incluindo criação, edição e mudança de estado de classificações. Guardar configurações e catálogo é atómico; conflito de versão evita sobrescrita concorrente.

API reutilizada: `GET /auth/v1/quality/workspace` acrescenta informação de proteção/utilização das classificações; `POST /auth/v1/quality/command` usa `settings_save` e valida classificações em `occurrence_create`. Não foram criados endpoints paralelos.

## Testes

**71 verificações de integração PASS**: 50 do fluxo existente, 20 de configuração e uma de compatibilidade da migration. Executadas numa transação com rollback, sem dados sintéticos persistidos na base do funil.

| Teste | Resultado | Observação |
|---|---|---|
| Default 7,3,1 | PASS | Default SQL e configuração nova no navegador |
| Retry 5,30,120 | PASS | Default, alteração/persistência, esgotamento e reenvio |
| Aprovação Sim/Não | PASS | Ambos os fluxos, motivo, original, pendência e decisão |
| NC Menor/Maior protegidas | PASS | Visíveis, ativas e bloqueadas no backend/base |
| Adicionar classificação | PASS | Gravação e disponibilidade em nova NC |
| Desativar classificação | PASS | Excluída do seletor e rejeitada em novos registos pela API |
| Histórico preservado | PASS | Nome visível depois da desativação; renomeação utilizada bloqueada |
| Observação não criada automaticamente | PASS | Base nova sem Observação; adição manual permitida |
| Mais detalhes removido | PASS | Ausente quando não há campos adicionais |
| Confirmação antes de guardar removida | PASS | UI e API guardam sem confirmação adicional |
| Audit log | PASS | Autor e valores anterior/novo; histórico mantido |
| Regressão NC/prazos | PASS | Fluxo nuclear, evidências, eficácia, reabertura e aprovação |
| Avisos 1/3 dias, 5/10 úteis | PASS | Destinatários corretos e deduplicação |
| Escalonamentos personalizados | PASS | Configuração 6/12 respeitada; aviso não emitido prematuramente |
| Configurações anteriores | PASS | Fixture 90,60,30 e retries personalizados mantidos após migration |
| Prazo curto | PASS | Só é emitido o lembrete ainda possível |
| Permissões/concorrência | PASS | Não gestor, líder de outra empresa e versão antiga rejeitados |
| Build | PASS | Vue/TypeScript e Vite, candidato separado antes de publicar |
| Verificações estáticas | PASS | Sintaxe Node e `git diff --check` |
| Unitários backend/frontend | PASS | 8 e 7 testes respetivamente |
| Navegador desktop/mobile | PASS | API/autenticação reais, persistência após refresh, sem erros JavaScript |
| E2E nuclear com Internet externa bloqueada | PASS | Auditoria→NC→ação→evidência→eficácia→reabertura e pesquisa |
| Funil após atualização | PASS | 10 verificações, incluindo API com classificações base e acesso não autenticado negado |
| Entrega SMTP real | BLOCKED | Dependência anterior: servidor/remetente/credenciais por configurar; transporte simulado validou fila/retry. Ação necessária: configurar e testar entrega operacional. Não impede guardar configurações nem executar o SGQ. |

Evidências guardadas junto do relatório: `integration-results.json`, `e2e-results.json`, `deployment.json`, `smoke-results.json`, `operational-desktop.png` e `operational-mobile.png`.

Comandos de regressão: `npm test --prefix backend`, `npm test --prefix frontend`, `npm run check --prefix backend`, `npm run build --prefix frontend -- --outDir dist-operational`, `git diff --check`. A integração usa `backend/tests/quality-v25-database.cjs` com `DATABASE_URL` configurada de forma protegida. O E2E usa `frontend/tests/quality-operational.e2e.cjs` com conta sintética, Playwright/Edge e variáveis de teste já documentadas para a baseline.

## Compatibilidade

Preservados: configurações personalizadas; nomes e relações históricas; catálogos de normas/constatações; audit logs; prazos originais; aprovação existente; fila, retries e deduplicação; autenticação/permissões; workflow nuclear e restantes módulos. Os dados de teste de navegador ficaram exclusivamente na base `samsys_quality_operational_qa`.

Uma classificação utilizada nunca é removida ou renomeada. Omitir um item ao guardar não o elimina. Classificações adicionais podem ser desativadas e reativadas. A base é protegida também fora da interface.

## Problemas encontrados

Corrigidos: classificação de NC como texto livre sem catálogo ativo/protegido; mistura da base com classificações adicionais; Observação no antigo default; accordion vazio; confirmação redundante; ausência do lembrete de 3 dias e do escalonamento configurável ao líder.

Não existem FAIL nos testes críticos desta alteração.

**Encontrado — fora do âmbito desta alteração:** configuração e entrega SMTP real pendentes da infraestrutura anterior; avisos existentes de bundle grande/importação LifeCycle no build; inexistência de runner de lint dedicado. Não foram feitas refatorações para estes assuntos.

A contagem de dias úteis mantém segunda a sexta, sem calendário de feriados. O líder só é informado quando explicitamente configurado, ativo e autorizado para a empresa/Qualidade. A publicação mantém o estatuto de candidato para testes da baseline; não substitui a aprovação de produção.

## Decisões necessárias

Nenhuma decisão bloqueia esta alteração funcional. A organização pode selecionar o líder na configuração se desejar os respetivos avisos. A ativação de SMTP e a aprovação global de produção continuam a depender dos responsáveis operacionais/negócio, conforme a baseline anterior.
