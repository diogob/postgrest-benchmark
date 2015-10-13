\setrandom user_id 1 100
BEGIN;
SET ROLE "admin";
SET postgrest.uid TO :user_id;
SET postgrest.company_id TO :user_id;
SELECT * FROM "1".users;
SELECT * FROM "1".projects;
INSERT INTO "1".users_projects (user_id, project_id) SELECT u.id, p.id FROM "1".users u, "1".projects p ORDER BY random() LIMIT 1;
END;
