INSERT INTO signup (company_name, user_name) SELECT 'Company ' || seq, 'Company ' || seq || ' Admin' FROM generate_series(1, :n_companies) seq;
INSERT INTO projects (name, company_id) SELECT 'Project ' || seq, companies.id FROM generate_series(1, :n_projects) seq, companies;
INSERT INTO users (name, company_id) SELECT 'User ' || seq, companies.id FROM generate_series(1, :n_users) seq, companies;
