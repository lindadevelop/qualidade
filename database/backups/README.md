# Cópia integral da base local

Backup: `qualidade-2026-11-04-cd75b9b4.dump.aes`.

Esta é a cópia **integral**, não anonimizada, da base PostgreSQL `samsys_qualidade`, exportada em 4 de novembro de 2026. Contém a estrutura e os dados das 103 tabelas: 3.104 registos, incluindo as 24 contas e as credenciais, hashes, sessões e outros valores que existiam na própria base. Nenhuma tabela foi excluída. O arquivo PostgreSQL preserva igualmente as definições e ACLs incluídas por pg_dump.

Como o repositório estava público no momento da exportação, o arquivo foi cifrado com AES-256-GCM. A chave aleatória de 256 bits está apenas no computador do proprietário, num diretório privado fora do repositório. **O ficheiro da chave não é enviado para o GitHub.** Não o adicione a commits, issues, mensagens ou logs. Sem essa chave não é possível recuperar os dados deste arquivo, mesmo depois de o repositório passar a privado.

O JSON ao lado do arquivo contém os dados técnicos e o SHA-256 do ficheiro cifrado, não a chave nem dados das contas. O formato é documentado pelo script de desencriptação em `scripts/decrypt-database-backup.mjs`: cabeçalho de versão, nonce de 96 bits, ciphertext e tag GCM de 128 bits. O cabeçalho é autenticado como AAD.

## Recuperar o arquivo PostgreSQL

Requisitos: Node.js (testado com v22.23.1), o arquivo `.dump.aes` e o `private-key.json` correspondente que está fora do GitHub. Execute a partir da pasta do repositório, substituindo os caminhos privados:

```powershell
node scripts/decrypt-database-backup.mjs database/backups/qualidade-2026-11-04-cd75b9b4.dump.aes C:/caminho-privado/private-key.json C:/caminho-privado/qualidade-restauro.dump
```

O script verifica a integridade GCM e recusa sobrescrever um ficheiro de saída existente. Uma chave errada ou um arquivo alterado não produz um ficheiro final de restauro. O resultado `.dump` contém dados e credenciais reais em formato PostgreSQL: guarde-o em local privado e não o publique.

## Restaurar numa base nova

Use os executáveis PostgreSQL compatíveis com o arquivo e uma **base nova e vazia**. Não restaure sobre a base de origem. Confirme os nomes, host e porta antes de executar:

```powershell
createdb -h 127.0.0.1 -U postgres qualidade_restauro
pg_restore -h 127.0.0.1 -U postgres --dbname qualidade_restauro --no-owner --no-privileges --exit-on-error --single-transaction C:/caminho-privado/qualidade-restauro.dump
```

Os parâmetros `--no-owner --no-privileges` são opções deste exemplo para um novo ambiente; não removem as contas da aplicação nem os dados. As roles PostgreSQL usadas por políticas RLS e as extensões necessárias devem estar disponíveis no destino. Ajuste owners/grants após o restauro conforme o ambiente.

Não aplique primeiro `database/schema.sql` nem as migrations iniciais: o arquivo integral já contém a estrutura. A configuração da ligação PostgreSQL no novo servidor é independente. Um pg_dump de uma base não inclui passwords de roles globais do cluster, outros bancos, os ficheiros `.env`/`.conf` da aplicação ou anexos guardados no disco fora do PostgreSQL; o backup inclui todas as credenciais que se encontram **nas tabelas desta base**.

## Verificações realizadas

- Exportação consistente por `pg_dump --format=custom`, sem filtros de tabelas ou dados.
- Catálogo lido com `pg_restore --list`, incluindo 103 entradas TABLE DATA.
- Dados completos do arquivo percorridos com `pg_restore --data-only`, sem imprimir valores; contados 3.104 registos e 24 contas auth.users.
- Desencriptação local de teste concluída; SHA-256 do arquivo recuperado igual ao original.
- Teste de adulteração da tag: desencriptação recusada, sem ficheiro final de restauro.
- O restauro completo numa base de destino ainda não foi executado; as verificações acima não substituem esse ensaio.
- A base local e os serviços em execução não foram alterados.
