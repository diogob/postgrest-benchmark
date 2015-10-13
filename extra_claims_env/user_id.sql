SET postgrest.uid TO '';
SET postgrest.company_id TO '';

CREATE OR REPLACE FUNCTION user_id()
RETURNS integer
STABLE
LANGUAGE SQL
AS $$
    SELECT current_setting('postgrest.uid')::int;
$$;

CREATE OR REPLACE FUNCTION company_id()
RETURNS integer
STABLE
LANGUAGE SQL
AS $$
    SELECT current_setting('postgrest.company_id')::int;
$$;

CREATE FUNCTION public.assign_company_id()
RETURNS trigger
LANGUAGE plpgsql
AS $$
    BEGIN
        IF current_setting('postgrest.uid') ~ '^\d+$' THEN
            new.company_id := company_id();
        END IF;
        RETURN new;
    END;
$$;

