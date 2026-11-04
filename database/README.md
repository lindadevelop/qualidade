# Estrutura da base de dados local

Snapshot PostgreSQL de samsys_qualidade, exportado em 2026-11-04.

- 103 tabelas e 61 funções; inclui índices, constraints, triggers e políticas presentes na exportação.
- Apenas estrutura: **não inclui os 3.104 registos existentes, nem as 24 contas de utilizador**.
- Não inclui passwords, hashes de passwords de contas, sessões, credenciais de ligação, anexos ou ficheiros guardados no disco.
- Exportação produzida com pg_dump --schema-only --no-owner --no-privileges. A base de origem não foi alterada.
- A revisão estática não encontrou instruções de dados COPY/INSERT, emails literais ou padrões conhecidos de tokens/chaves. Isso não é uma auditoria independente.

## Restauro da estrutura

Use uma base NOVA e vazia, nunca a base de produção. Instale uma versão PostgreSQL compatível com o pg_dump indicado no cabeçalho de schema.sql. As extensões e roles usadas pelas políticas, como anon/authenticated, devem existir no ambiente de destino; os seus passwords não são exportados.

Exemplo (defina host, utilizador e autenticação de forma segura no seu ambiente):

```powershell
createdb -h 127.0.0.1 -U postgres qualidade_restauro
psql -X -h 127.0.0.1 -U postgres -d qualidade_restauro --single-transaction --set ON_ERROR_STOP=1 --file database/schema.sql
```

O comando de restauro é um procedimento de referência; este snapshot ainda não foi ensaiado numa base de destino. Os dados reais continuam apenas na base local.

Este snapshot é uma alternativa ao arranque pelas migrations existentes em supabase/migrations. Não aplique migrations iniciais sobre este schema já criado sem rever o estado/versionamento. Os dados/seeds anonimizados ou uma cópia para repositório privado dependem da escolha explícita do proprietário.
