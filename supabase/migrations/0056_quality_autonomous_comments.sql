BEGIN;
-- An autonomous improvement action also needs an auditable discussion.
ALTER TABLE quality_comments ALTER COLUMN occurrence_id DROP NOT NULL;
ALTER TABLE quality_comments ADD CONSTRAINT quality_comment_parent_required
 CHECK (occurrence_id IS NOT NULL OR action_id IS NOT NULL);
NOTIFY pgrst,'reload schema';
COMMIT;
