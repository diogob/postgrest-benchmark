CREATE OR REPLACE FUNCTION user_id()
RETURNS integer
STABLE
LANGUAGE SQL
AS $$
    SELECT current_user::int;
$$;

CREATE OR REPLACE FUNCTION company_id()
RETURNS integer
STABLE
LANGUAGE SQL
AS $$
    SELECT company_id FROM public.users u WHERE u.id = user_id();
$$;

CREATE FUNCTION public.create_db_user()
RETURNS trigger
LANGUAGE plpgsql
AS $$
    BEGIN
        EXECUTE 'CREATE ROLE ' || quote_ident(new.id::text) || ' IN ROLE ' || quote_ident(new.role);
        RETURN new;
    EXCEPTION
        WHEN others THEN
            RETURN new;
    END;
$$;

CREATE FUNCTION public.assign_company_id()
RETURNS trigger
LANGUAGE plpgsql
AS $$
    BEGIN
        IF current_user::text ~ '^\d+$' THEN
            new.company_id := company_id();
        END IF;
        RETURN new;
    END;
$$;

CREATE TRIGGER create_db_user
BEFORE INSERT ON public.users
FOR EACH ROW
EXECUTE PROCEDURE public.create_db_user();
