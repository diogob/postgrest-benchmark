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
    current_user = 'admin' OR

    -- if the user is an employee he needs to see only the projects in his company that he is assigned to
    EXISTS(SELECT true FROM "1".users_projects up WHERE up.project_id = p.id)
    );

