# Importação do projeto Qualidade

Cópia do código a partir de C:\CodexProjetos.

Não contém credenciais locais, bases de dados/dados operacionais, imports, backups, logs, node_modules, dist, executáveis portáteis ou o gateway Codex Remote. Segredos embutidos foram substituídos por referências a variáveis de ambiente nesta cópia; o projeto original não foi alterado.

Configure backend/.env e os parâmetros PostgREST a partir dos exemplos antes de arrancar. Os scripts auxiliares Python utilizam variáveis de ambiente para credenciais.

Ficheiros adaptados para remover credenciais:
- backend/ai/agent-orchestrator.js
- backend/ai/ai-assistant-server.js
- backend/ai/ai-channels-server.js
- backend/ai/channel-token.js
- backend/ai/messaging-gateway.js
- backend/ai/_alert-worker.js
- backend/auth-server.js
- import_clear.py
- import_relations.py
- import_run.py
- import_verify.py
- lifecycle_import.py
