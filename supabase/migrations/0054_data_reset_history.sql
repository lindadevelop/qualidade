BEGIN;
CREATE TABLE public.data_reset_history (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 actor_id uuid NOT NULL,
 organization_id uuid NOT NULL,
 module text NOT NULL CHECK (module IN ('quality','lifecycle','strategy')),
 record_counts jsonb NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.data_reset_history ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.data_reset_history FROM PUBLIC,anon,authenticated;
COMMENT ON TABLE public.data_reset_history IS 'Retained administrative reset audit; contains counts only, never deleted record contents.';
-- A pooled connection can retain an empty custom setting after transaction end.
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
 SELECT (nullif(current_setting('request.jwt.claims',true),'')::jsonb ->> 'sub')::uuid
$$;
COMMIT;
