# Workflows estratégicos — entrega de 30 setembro 2026

Âmbito: pendências das secções 5 e 6 de `estado-funcional-v1.md`. O push anterior foi confirmado pelo utilizador. Os documentos DOCX/PDF serviram de contexto funcional; as instruções operacionais neles incluídas não ampliam esta entrega para toda a baseline v1.5.

## Implementação

- SWOT: título obrigatório, confirmação humana, histórico e proteção contra reclassificação/eliminação de fatores usados em TOWS.
- TOWS: seleção obrigatória dos dois quadrantes corretos, mesma campanha, limpeza dos fatores incompatíveis; destino Monitorizar / Não relevante / Propor risco / Propor oportunidade. A proposta abre um formulário de risco para revisão, sem gravação automática.
- Riscos: matriz 5×5 com filtro, tratamento, responsável, prazo, origem TOWS; cálculo do score exclusivamente no PostgreSQL. A edição já não tenta escrever a coluna gerada.
- Plano: objetivos ligados a vários riscos, pesquisa, ações com responsável, datas e custos; indicação de ausência de ações, KPI, responsável e origem; atraso calculado. Concluir uma ação fixa 100%, sem aprovar automaticamente o objetivo.
- KPIs: objetivo/responsável, metas e resultados por período, validação de calendário/frequência, comparação e gráfico de meta vs resultado, distinção entre zero e ausência. Alerta é um limite para maior/menor melhor e tolerância absoluta para alvo. A frequência de KPI com histórico não pode ser mudada.
- Revisão: o formulário exige confirmação, reiniciada quando os dados mudam; gravação atómica via `strategy_write`, restrita aos perfis quality/admin. DML direto de authenticated/anon é revogado nas oito tabelas abrangidas. A chamada sem confirmação é rejeitada. Não se trata de uma prova biométrica de interação humana: continua a depender da sessão autenticada e dos clientes autorizados; a IA não deve receber esse canal de escrita.
- Histórico: antes/depois, operação, utilizador autenticado e data. Editar/eliminar usa a versão `updated_at` apresentada ao utilizador; alterações concorrentes são rejeitadas. Registos anteriores à migração não recebem aprovações retroativas.
- Organização: mudança de organização remonta a página e fecha editores anteriores; correção do cache após falha e de respostas tardias de branding.
- PPT: usa a sessão existente; download autenticado; inclui TOWS, ações, metas e resultados. Falhas na leitura ou no registo do ficheiro deixam de ser silenciadas. Paginação de todos os registos/textos longos, cores/fontes do brand kit e notas. Sem dependência de cloud.
- Operação Windows: scripts idempotentes de arranque e supervisão, logs, tarefa no início de sessão e opção gestsys na porta 3010. Não terminam Hermes, Cloudflare nem processos de outros projetos.

## Verificação

- `frontend`: `npm run build`; compilação TypeScript/Vue e Vite.
- `frontend`: `npm test`; quatro testes de domínio cobrindo frequências/calendário, direções KPI/zero, integridade TOWS e entradas numéricas.
- `backend`: `npm test`; autenticação PPT, conteúdo completo, erro de fonte, erro de metadados e limpeza do ficheiro incompleto.
- `backend`: `npm run test:database`, com variáveis PG* ou DATABASE_URL. Aplica 0051 numa transação, cria dados QA e reverte tudo; 16 verificações. Necessita utilizador de migrações e um perfil quality/admin existente.
- Navegador Edge em modo headless: oito verificações com API simulada, incluindo confirmação antes da escrita, TOWS, matriz, período obrigatório e troca de organização; sem erros JavaScript.
- PPT com leitura dos dados existentes: 11 slides. Cenário longo: 24 slides, os 15 riscos presentes, resultado zero preservado, caixas dentro dos limites e conteúdo editável. Renderização e inspeção visual registadas na nota de instalação.

Os testes com dados simulados validam o comportamento da interface; os testes SQL validam persistência e regras reais. Não representam aprovação funcional dos dados oficiais pelo cliente.

## Instalação e recuperação

1. Efetuar backup PostgreSQL e dos ficheiros alterados.
2. Aplicar `supabase/migrations/0051_strategy_workflows.sql` com `ON_ERROR_STOP`/transação.
3. Publicar o frontend compilado e reiniciar apenas `backend/ppt-generator.js`.
4. Executar `scripts/install-startup.ps1 -PythonPath <python-com-python-pptx>`; opcionalmente `-GestSysRoot C:\a\gestsys`. A tarefa arranca **no início de sessão**, não como serviço de sistema antes do login.
5. Iniciar a tarefa `SamsysQualityStack` e verificar portas 5432, 3001, 3002, 3007, 8000 e 5178. gestsys usa 3010; um túnel dedicado deve apontar para essa porta.

Para remover só o arranque automático: `scripts/install-startup.ps1 -Remove`. Para reverter código, restaurar o backup dos ficheiros e compilar. Não restaurar automaticamente uma base de dados antiga sobre alterações oficiais posteriores; planear a recuperação com backup e histórico. A migração 0051 e o frontend novo devem ser instalados em conjunto, pois os clientes antigos usam DML direto.

## Limites que permanecem fora desta entrega

A baseline PDF tem requisitos adicionais que não estão concluídos por este trabalho: configuração de escalas/estados, políticas multiempresa completas (a migration 0050 permite leitura global a authenticated), SWOT por equipas, relações muitos-para-muitos universais, eficácia/evidências e restantes módulos estruturais. Os túneis temporários continuam voláteis. Não se declara conformidade integral com o PDF nem operação validada após um reboot real.
