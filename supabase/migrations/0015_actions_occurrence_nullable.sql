-- 0015_actions_occurrence_nullable.sql
-- As ações podem ser autónomas (melhoria/auditoria) sem NC associada.
-- O modelo anterior obrigava a uma ocorrência; na importação de dados reais
-- existem ações legítimas sem NC. Tornamos occurrence_id anulável.
alter table public.quality_actions alter column occurrence_id drop not null;