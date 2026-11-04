# Módulos operacionais v1.5 — 2026-10-01

## Funcionalidades

- Organizações: criar, editar e desativar; atualização imediata do seletor.
- Equipas e membros: gestão por organização; papéis organizacionais não alteram o perfil global do utilizador.
- Identidade visual: cores, fontes, pré-visualização e seleção atómica do kit predefinido.
- Frameworks e ciclos: gestão com datas e associação à mesma organização.
- Reuniões: agenda, participantes, assuntos, estados e ata obrigatória para conclusão.
- Decisões: proposta → aprovação/rejeição → implementação; fundamentação e autor/data registados.
- Templates PPT: secções, capa, tamanho do texto e paginação aplicados ao gerador; escolha na exportação.
- Conectores: cadastro e importação CSV UTF-8 de resultados KPI com pré-visualização, revisão humana e transação integral.

Todas as gravações destes módulos passam pela função `platform_module_write`, exigem perfil quality/admin e confirmação humana, verificam a versão do registo e mantêm o histórico. Eliminações diretas estão desativadas; os registos com estado ativo podem ser desativados.

A migração 0052 adiciona os campos dos templates e timestamps dos participantes. É aditiva. O controlo organizacional de associações não substitui isolamento completo entre tenants: permanecem as políticas de leitura da plataforma existente.

## Validação

- 21 verificações SQL em transação com rollback, incluindo alterações concorrentes, associação entre organizações, decisões, kit predefinido e importação atómica.
- 7 testes de domínio JavaScript (CSV, campos, períodos, TOWS e KPIs).
- Teste HTTP do gerador PPT: autenticação, seleção de template, template inválido e falhas de dados/metadados.
- 2 testes Python: secções selecionadas, paginação integral e apresentação sem dados.
- Testes de navegador com API simulada: criação nas sete páginas, bloqueio de gravação antes da revisão e invalidação da revisão após editar.
- Compilação TypeScript/Vite; mantêm-se avisos anteriores de tamanho de bundles e importações.

Comandos: `frontend: npm test && npm run build`; `backend: npm test`, `npm run test:platform-database` (PG* ou DATABASE_URL de uma base preparada com 0051) e `python tests/test_ppt_templates.py`.

## Limitações explícitas

PHC, Sage, Power BI, SharePoint e outros serviços externos podem ser inventariados como inativos. A ativação é rejeitada enquanto não existir adaptador operacional. Esta entrega não configura credenciais nem sincronização desses sistemas.
Os templates configuram o gerador nativo; não importam ficheiros PPTX de terceiros como slide masters.
A importação CSV aceita até 500 linhas e 1 MB, com cabeçalho `codigo;periodo;valor;notas`. A atualização de um resultado usa a versão apresentada na pré-visualização; em conflito, é necessário voltar a ler o ficheiro.

## Instalação verificada

Aplicados 25 ficheiros no projeto em 2026-10-01. Backup de ficheiros: `backups/platform-modules-20261001-103645`. Backup PostgreSQL antes da migração: `backups/before-0052-2026-10-01T09-36-45-982Z.dump` (715265 bytes, catálogo validado). Build publicada no frontend local. Supervisor `SamsysQualityStack` em execução.

Teste HTTP autenticado: onze tabelas acessíveis; gravação sem revisão rejeitada com 403; geração e download PPT com 200 (56388 bytes). Frontend 5178, PPT 3007 e GestSys 3010 responderam 200. A raiz do proxy 8000 devolve 404; as rotas de autenticação, REST e PPT funcionam. O teste de navegador também confirmou a pré-visualização e importação CSV.
