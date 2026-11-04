BEGIN;
CREATE TRIGGER origin_no_delete BEFORE DELETE ON quality_origins FOR EACH ROW EXECUTE FUNCTION protect_used_config();
NOTIFY pgrst,'reload schema';
COMMIT;
