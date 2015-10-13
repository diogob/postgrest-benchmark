
GRANT SELECT ON public.users TO public;

CREATE POLICY same_user ON public.users
USING ( id = user_id() );

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

CREATE FUNCTION public.encrypt_pass()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    new.pass = public.crypt(new.pass, public.gen_salt('bf'));
    RETURN new;
END;
$$;

CREATE TRIGGER encrypt_pass
BEFORE INSERT OR UPDATE ON public.users
FOR EACH ROW
EXECUTE PROCEDURE public.encrypt_pass();

-- an admin can add users to the system but only with the right company_id
CREATE TRIGGER assign_company_id
BEFORE INSERT OR UPDATE ON public.users
FOR EACH ROW
EXECUTE PROCEDURE public.assign_company_id();

-- project (id, name, company_id)
CREATE TABLE public.projects (
       id serial primary key,
       name text not null,
       company_id integer references companies
);

CREATE POLICY same_company ON projects
       USING ( company_id = company_id() )
       WITH CHECK ( company_id = company_id() );

CREATE TRIGGER assign_company_id
BEFORE INSERT OR UPDATE ON public.projects
FOR EACH ROW
EXECUTE PROCEDURE public.assign_company_id();

ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.projects TO admin;

-- users_projects(project_id, user_id)
CREATE TABLE public.users_projects (
       project_id integer references projects,
       user_id integer references users,
       primary key(project_id, user_id)
);

CREATE POLICY same_company ON public.users_projects
WITH CHECK ( EXISTS (SELECT true FROM public.projects p WHERE p.id = project_id AND p.company_id = company_id()) );

ALTER TABLE public.users_projects ENABLE ROW LEVEL SECURITY;

GRANT INSERT ON public.users_projects TO admin;

/*
*/
CREATE SCHEMA "1";

GRANT USAGE ON SCHEMA "1" TO public;

-- signup - creates a new company and a user in that company as an admin (anonymous role)
CREATE VIEW "1".signup AS
    SELECT
        c.name AS company_name,
        u.name AS user_name,
        u.pass
    FROM
        public.users u
        JOIN public.companies c ON c.id = u.company_id;

CREATE FUNCTION public.signup()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  vcompany_id int;
BEGIN
  INSERT INTO companies (name) VALUES (new.company_name) RETURNING id INTO vcompany_id;
  INSERT INTO users (name, role, company_id) VALUES (new.user_name, 'admin', vcompany_id);
RETURN new;
END;
$$;

CREATE TRIGGER signup
INSTEAD OF INSERT OR UPDATE ON "1".signup
FOR EACH ROW
EXECUTE PROCEDURE public.signup();

GRANT INSERT ON signup TO anonymous;

CREATE OR REPLACE VIEW "1".users AS
    SELECT
        u.id,
        u.name,
        u.pass
    FROM
        public.users u
    WHERE
        u.company_id = company_id();

-- employees can not insert users in the system
GRANT SELECT, INSERT, UPDATE ON "1".users TO admin;
GRANT SELECT ON "1".users TO employee;

CREATE VIEW "1".users_projects AS
    SELECT
        project_id,
        user_id
    FROM
        public.users_projects
    WHERE
        EXISTS (SELECT true FROM public.projects p WHERE p.id = project_id AND company_id = company_id());

CREATE OR REPLACE FUNCTION public.insert_users_projects()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    -- This function is enough to use the table policy during insertion
    INSERT INTO public.users_projects (user_id, project_id) VALUES (new.user_id, new.project_id);
RETURN new;
END;
$$;

-- Without this trigger the view insert does not use RLS policy from table
CREATE TRIGGER insert_users_projects
INSTEAD OF INSERT ON "1".users_projects
FOR EACH ROW
EXECUTE PROCEDURE public.insert_users_projects();


-- employees can not insert users in the system
GRANT SELECT, INSERT, UPDATE ON "1".users_projects TO admin;

