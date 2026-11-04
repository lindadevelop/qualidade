# Operação e validação — v2.5 / 0.5.0-rc.1

## Ambiente

O candidato está no funil existente: https://progressive-suburban-entity-twelve.trycloudflare.com/.
Recarregar com Ctrl+F5 e confirmar `v0.5.0-rc.1` no menu. Selecionar a empresa correta antes de criar registos.
O mesmo build funciona numa origem interna que encaminhe `/auth`, `/rest`, `/storage`, `/cv`, `/ai`, `/channels`, `/mcp` e `/ppt` para os serviços locais. O funil exige Internet; o acesso interno não exige Internet para o SGQ nuclear. Não há modo de edição sem ligação ao servidor.

Não usar a base operacional para ensaios destrutivos. Os testes automáticos de integração usam rollback e o E2E exige uma empresa e conta sintéticas numa base separada.

## Roteiro UAT

Registar por cenário: utilizador, empresa, data, resultado, evidência e observação. A aprovação deve ser dada por Qualidade/Product Owner.

| Cenário | Resultado esperado |
|---|---|
| Auditoria interna e externa | Campos adaptados ao tipo; detalhe adicional acessível sem sobrecarregar formulário |
| Constatação NC/OM | Visível na auditoria e na lista geral, com a mesma referência e texto original |
| NC independente | Origem e área corretas; responsável recebe notificação |
| Reatribuição | Novo responsável confirma conhecimento; confirmação anterior fica no histórico |
| Tratamento | Análise e causa raiz separadas; dispensa de ação corretiva exige motivo |
| Cinco tipos de ação | Tipos distintos; oportunidade de melhoria exige OM; melhoria autónoma admite comentário |
| Prazo | Original preservado; pedido guarda motivo; aprovar/rejeitar produz decisão visível |
| Aprovação | Devolver/rejeitar exige comentário; ressubmissão preserva decisões anteriores |
| Evidência | Upload com descrição, download autorizado e acesso negado a outra empresa |
| Conclusão | Sem evidência obrigatória não conclui; última ação encaminha para eficácia |
| Eficácia negativa | Regressa a tratamento e mantém avaliação anterior |
| Eficácia positiva | Encerra com avaliador, data, critério, conclusão e evidências |
| Reabertura | Motivo obrigatório; avaliações antigas preservadas |
| Estado externo | Fechar externamente não encerra internamente |
| Anulação | Preserva histórico/evidências; desaparece dos indicadores, consultável como anulada |
| O meu trabalho | Apenas intervenções atribuídas/aprovações/eficácia/prazos aplicáveis |
| Dashboard e pesquisa | Seis cartões abrem listas corretas; filtros encontram auditorias, ocorrências e ações |
| Permissões | Responsável não reatribui nem avalia eficácia; empresa não consulta outra empresa |
| Sem Internet externa | Usar URL interna e repetir fluxo; indisponibilidade de IA/email não impede operação |
| Exportação | JSON contém dados autorizados; documentos podem ser descarregados individualmente |

## SMTP

Configurar variáveis no ambiente do serviço ou em `backend/.env`, que não deve entrar no Git. O servidor de autenticação lê esse ficheiro ao arrancar. Usar `backend/quality-email.env.example` como referência, sem substituir outras variáveis existentes.

1. Definir `SMTP_HOST`, `SMTP_PORT`, `SMTP_SECURE`, `SMTP_FROM`, `SMTP_USER`, `SMTP_PASSWORD` e `QUALITY_PUBLIC_URL` com URL acessível aos destinatários.
2. Manter `QUALITY_EMAIL_ENABLED=false` até haver destinatário de teste e janela acordada para validação.
3. Rever mensagens pendentes na Qualidade. A ativação poderá enviar a fila pendente; não ativar inadvertidamente num clone de produção.
4. Ativar explicitamente, reiniciar apenas o serviço de autenticação e confirmar entrega de evento controlado.
5. Simular indisponibilidade em ambiente de teste: operação gravada, erro na fila, retries, recuperação e ausência de reenvio de mensagem já enviada.
6. Mensagem com entrega incerta após interrupção não é reenviada automaticamente. Confirmar com o servidor SMTP antes do reenvio manual.

O worker verifica a fila e os lembretes a cada minuto. Retries iniciais: 5, 30 e 120 minutos; configuráveis por empresa. A Qualidade recebe um aviso deduplicado após cinco dias úteis de atraso, contando segunda a sexta e sem calendário de feriados nesta versão.

## Backups e recuperação

O serviço de autenticação verifica a cada hora se passaram 24 horas desde o último backup; executa também a verificação no arranque. `QUALITY_BACKUP_DIR` permite mudar o destino. `QUALITY_BACKUP_ENABLED=false` desativa explicitamente. Por defeito: `backups/automatic`.

Cada backup contém `database.dump`, ficheiros disponíveis de `uploads`, `quality-evidence` e `file-access`, e `manifest.json`. `last-success.json` identifica a última execução concluída. Falhas ficam em `backend/data/runtime-logs/auth.err.log`; não bloqueiam o uso do SGQ. Monitorização/alertas externos e cópia para outro disco devem ser configurados por Operações.

Recuperação segura:

1. Parar escritas apenas durante a troca final, preservando uma cópia atual. Nunca restaurar diretamente sobre a base usada pelos utilizadores durante um ensaio.
2. Criar uma base de recuperação separada e restaurar com `pg_restore --exit-on-error --dbname=<base_de_recuperacao> <database.dump>`, fornecendo credenciais por mecanismo local protegido.
3. Copiar os ficheiros para diretório separado; comparar hashes e referências de anexos. Preservar a árvore de empresa/identificador das evidências.
4. Verificar autenticação/permissões, auditoria, ocorrências, ações, avaliações e documentos. Manter SMTP desativado no clone.
5. Só após verificação e decisão de recuperação efetuar a troca de base/diretório e reiniciar os serviços necessários. A distribuição frontend deve ser compatível com a versão da base.

Não existe rollback automático que elimine tabelas/colunas da v2.5. Depois de novos dados, preferir correção aditiva. Repor UI antiga sem compatibilidade com os comandos v2.5 não é uma recuperação válida. Não remover evidências ou histórico para fazer um rollback.

Backups atuais são locais e não equivalem a proteção contra falha/perda do disco. Retenção, RTO/RPO e cópia externa carecem de validação operacional. Não há limpeza automática.

## Testes reproduzíveis

Na raiz do projeto:

```powershell
npm test --prefix backend
npm test --prefix frontend
npm run check --prefix backend
npm run build --prefix frontend -- --outDir dist-v25
git diff --check
```

Integração: fornecer `DATABASE_URL` para uma base PostgreSQL compatível, de preferência um clone de teste. `npm run test:quality-database --prefix backend` aplica migrations em transação quando necessário, cria dados sintéticos e faz rollback integral. Ficheiros sintéticos podem permanecer sem referência no diretório de testes; não são evidências da empresa.

E2E: preparar empresa/conta sintética com perfil Qualidade, área `Processo QA`, origem `Auditoria QA` e nome `Qualidade QA`. Definir `QUALITY_E2E_URL`, `QUALITY_E2E_EMAIL`, `QUALITY_E2E_PASSWORD`, `QUALITY_E2E_OUTPUT` e, se necessário, `PLAYWRIGHT_MODULE`. Executar `node frontend/tests/quality-v25.e2e.cjs` com Playwright e Edge disponíveis. O teste cria registos persistentes apenas nessa base de teste e bloqueia pedidos para outras origens.

O supervisor em `scripts/start-stack.ps1` inclui autenticação, proxy, storage, CV, PPT e frontend. Alterações ao script passam a valer na próxima execução do supervisor. O túnel é independente e não deve ser encerrado durante builds.

## Quality Gate

Disponível para teste não significa aprovado para produção. Antes da promoção: UAT aprovado, SMTP validado quando aplicável, segredos/TLS revistos, recuperação operacional demonstrada e ausência de defeitos críticos/altos de segurança ou integridade. Registar a decisão, responsável, data e versão.
