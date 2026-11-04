-- check_rls_status: equivalente ao que o Supabase executa (ativa RLS por request)
CREATE OR REPLACE FUNCTION public.check_rls_status()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
  EXECUTE 'ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY';
  EXECUTE 'ALTER TABLE public.quality_areas ENABLE ROW LEVEL SECURITY';
  EXECUTE 'ALTER TABLE public.quality_origins ENABLE ROW LEVEL SECURITY';
  EXECUTE 'ALTER TABLE public.quality_occurrences ENABLE ROW LEVEL SECURITY';
  EXECUTE 'ALTER TABLE public.quality_actions ENABLE ROW LEVEL SECURITY';
  EXECUTE 'ALTER TABLE public.quality_attachments ENABLE ROW LEVEL SECURITY';
  EXECUTE 'ALTER TABLE public.quality_comments ENABLE ROW LEVEL SECURITY';
  EXECUTE 'ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY';
  EXECUTE 'ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY';
END;
$fn$;
GRANT EXECUTE ON FUNCTION public.check_rls_status() TO anon, authenticated, service_role;
SELECT 'check_rls_status criada' AS status;