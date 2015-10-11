\c postgres
DROP DATABASE :db;
CREATE DATABASE :db;
\c :db
\i schema.sql
