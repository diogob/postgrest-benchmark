CREATE EXTENSION pgcrypto;
CREATE ROLE postgrest;
CREATE ROLE anonymous;
CREATE ROLE admin;
CREATE ROLE employee;

-- companies (id, name)
CREATE TABLE companies (
       id serial primary key,
       name text unique
);

-- users (id, email, type, company_id, password) --type can be admin/employee
CREATE TABLE public.users (
       id serial primary key,
       name text not null,
       pass text,
       role text not null default 'employee',
       company_id integer not null references companies
);

GRANT SELECT ON public.users TO public;

CREATE POLICY same_user ON public.users
USING ( id = current_user::int );

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

CREATE TRIGGER create_db_user
BEFORE INSERT ON public.users
FOR EACH ROW
EXECUTE PROCEDURE public.create_db_user();

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

-- an admin can add users to the system but only with the right company_id
CREATE TRIGGER assign_company_id
BEFORE INSERT OR UPDATE ON public.users
FOR EACH ROW
EXECUTE PROCEDURE public.assign_company_id();

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

CREATE VIEW "1".projects AS
        SELECT
        p.id,
        p.name
        FROM
        public.projects p
        WHERE
        p.company_id = company_id() AND
        (
            -- each user when logged in can see only the projects within his company if he is an admin
            pg_has_role(current_user, 'admin', 'usage') OR

            -- if the user is an employee he needs to see only the projects in his company that he is assigned to
            EXISTS(SELECT true FROM "1".users_projects up WHERE up.project_id = p.id)
        );

-- and admin can edit a project, a user can not
GRANT SELECT, INSERT, UPDATE ON "1".projects TO admin;
GRANT SELECT ON "1".projects TO employee;

GRANT USAGE ON SEQUENCE companies_id_seq, projects_id_seq, users_id_seq TO public;

INSERT INTO signup (company_name, user_name) SELECT 'Company ' || seq, 'Company ' || seq || ' Admin' FROM generate_series(1, :n_companies) seq;
INSERT INTO projects (name, company_id) SELECT 'Project ' || seq, companies.id FROM generate_series(1, :n_projects) seq, companies;
INSERT INTO users (name, company_id) SELECT 'User ' || seq, companies.id FROM generate_series(1, :n_users) seq, companies;
