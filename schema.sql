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
       company_id integer not null references companies
);

CREATE POLICY same_user ON public.users
USING ( id = current_user::int );

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

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

CREATE OR REPLACE FUNCTION company_id()
RETURNS integer
STABLE
LANGUAGE SQL
AS $$
    SELECT company_id FROM users u WHERE u.id = current_user::int;
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

ALTER TABLE projects ENABLE ROW LEVEL SECURITY;

-- users_projects(project_id, user_id)
CREATE TABLE users_projects (
       project_id integer references projects,
       user_id integer references users,
       primary key(project_id, user_id)
);

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
  INSERT INTO companies (name) VALUES (new.company_name) RETURNING company_id INTO vcompany_id;
  INSERT INTO users (name, company_id) VALUES (new.user_name, vcompany_id);
RETURN new;
END;
$$;

CREATE TRIGGER signup
INSTEAD OF INSERT OR UPDATE ON "1".signup
FOR EACH ROW
EXECUTE PROCEDURE public.signup();

GRANT INSERT ON signup TO anonymous;

CREATE VIEW "1".users AS
    SELECT
        u.id,
        u.name,
        u.pass
    FROM
        public.users u;

-- employees can not insert users in the system
GRANT SELECT, INSERT, UPDATE ON "1".users TO admin;

CREATE VIEW "1".users_projects AS
    SELECT
        project_id,
        user_id
    FROM
        public.users_projects
    WHERE
        EXISTS (SELECT true FROM public.projects p WHERE p.id = project_id AND company_id = company_id());

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

INSERT INTO companies (name) SELECT 'Company ' || seq FROM generate_series(1, :n_companies) seq;
INSERT INTO projects (name) SELECT 'Project ' || seq FROM generate_series(1, :n_projects) seq, companies;
INSERT INTO projects (name , company_id) VALUES ('bootstrap', 1);
