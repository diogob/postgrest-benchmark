\c postgres
DROP DATABASE :db;
CREATE DATABASE :db;
\c :db

-- The commands bellow are needed by the variation functions
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

\i :variation/user_id.sql
\i schema.sql
\i :variation/projects_view.sql

-- and admin can edit a project, a user can not
GRANT SELECT, INSERT, UPDATE ON "1".projects TO admin;
GRANT SELECT ON "1".projects TO employee;

GRANT USAGE ON SEQUENCE companies_id_seq, projects_id_seq, users_id_seq TO public;

\i data.sql
