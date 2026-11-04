# Relatório de Importação — SAMSYS|Qualidade
**Data:** 2026-09-17 · **Ficheiros:** NC_OM.xlsx e Livro7.xlsx

## 1. Base de dados e ambiente
- Base `samsys_qualidade` (PostgreSQL portátil local, `127.0.0.1:5432`).
- Backend Stack completo operacional (PostgREST :3001, auth :3002, IA :3004, canais :3005, proxy :8000, preview :5178).
- Acesso feito com o utilizador de serviço; **nenhuma credencial revelada**.

## 2. Resultado por módulo
| Módulo | Lidos | Criados | Atualizados | Sem alteração | Pendentes |
|---|---|---|---|---|---|
| Não Conformidades (NC) | 20 | 20 | 0 (2ª exec: 20 updated) | – | ver anomalias |
| Oportunidades de Melhoria (OM) | 43 | 43 | 0 (2ª exec: 43 updated) | – | ver anomalias |
| Ações (Livro7) | 90 | 90 | 0 (2ª exec: 90 updated) | – | ver anomalias |

- **Total de dados importados:** 153 registos (reconciliado com as 153 linhas de registo de importação).
- Contagens finais: ocorrências **93** (44 NC + 49 OM, inclui 30 demo pré-existentes intactas), ações **146** (90 novas + 56 demo), áreas **54** (46 novas), origens **9** (2 novas), relações NC relacionada **11**.

## 3. Idempotência (2ª execução)
Uma 2ª execução resultou em **tudo "updated", 0 novos criados** — sem duplicados, sem alterações desnecessárias. Verificado.

## 4. Anomalias registadas (em `import_registry.anomalies`)
1. **Datas de Ações corrompidas (1900):** 60 ações com Data início/fim prevista lidas como `1900-01-20`. Sem forma de reconstruir o ano (valor numérico perdeu o ano), **deadline ficou por preencher** (como o documento manda). 90 registos sinalizados.
2. **Guard da app (validação obrigatória):** registos que no Excel constam "Fechada" mas eficácia ≠ "Eficaz" (ex.: "Não avaliada", "Parcialmente eficaz") foram colocados em **Aguardar eficácia** (não CLOSED) para respeitar `guard_close_occurrence`. ~8 registos.
3. **Responsáveis sem correspondência (não mapeados por aproximação)** — 3:
   - `Samuel Soares / Ruben Soares / Márcia Costa` (AC-2020-035) → mapeado a Ana Qualidade
   - `Jurista / Responsável` (OM-2022-EXT-004) → sem utilizador demo (jurídico)
   - `Planeamento e Suporte` (OM-2023-INT-006) → equipa, sem demo
   - Mais **46 registos** com responsável vazio ("Não indicado"/"A definir") → ficaram sem responsável (sem criar contas).
4. **Relações não resolvidas:** 7 registos OM com "NC relacionada"="Não" (sem relação real; não inventada).

## 5. Cópia de segurança e reposição
- **Backup:** `C:\a\samsys-qualidade\backups\pre_importacao_20260917_181817.dump` (formato custom pg_dump).
- **Reposição:** `pgportable\pgsql\bin\pg_restore.exe -h 127.0.0.1 -p 5432 -U postgres -d samsys_qualidade --clean "backups\pre_importacao_20260917_181817.dump"`
- Também é possível remover só os importados: `python import_clear.py`.

## 6. Ficheiros alterados e repetição
**Migrations aplicadas:** `0014_import_registry.sql`, `0015_actions_occurrence_nullable.sql`, `0016_occurrence_relations.sql`.
**Scripts (raiz do projeto):** `import_run.py` (importar; `--dry-run` simula, `--commit` grava), `import_relations.py` (2ª passagem relações), `import_verify.py` (verificação), `import_clear.py` (limpar importados).
- **Comando para repetir:** `python import_run.py --commit && python import_relations.py`
- Idempotente: repetir não cria duplicados.

## 7. Resultado das verificações
- Fichas confirmadas: NC-2020-001 (NC, 2020, CLOSED, Eficaz, datas corretas), NC-2025-003 (CLOSED), NC-2022-002 (com relação → NC-2022-004 via `quality_occurrence_relations`).
- Ações com NC associada confirmadas: AC-2020-034→NC-2020-001, AC-2025-010→NC-2025-003.
- Relações NC relacionada (11) gravadas em `quality_occurrence_relations`; 39 ações ligadas à ocorrência associada.
- App operacional; dados visíveis nos endpoints REST (validado `NC-2020-001` via REST).