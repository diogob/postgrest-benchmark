\setrandom user_id 101 10100
-- The company does not correspond to user
-- But this should not interfere with the performance results
\setrandom company_id 1 100

BEGIN;
SET ROLE "employee";
SET postgrest.uid TO :user_id;
SET postgrest.company_id TO :company_id;
SELECT * FROM "1".users;
SELECT * FROM "1".projects;
END;
