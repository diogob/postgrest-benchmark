\setrandom user_id 101 10100
BEGIN;
SET ROLE "employee";
SET postgrest.uid TO :user_id;
SELECT * FROM "1".users;
SELECT * FROM "1".projects;
END;
