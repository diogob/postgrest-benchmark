To initialize a database named test 
with 100 companies and 10 projects in each run:
```
psql -v n_companies=100 -v n_projects=10 -v db=test < setup.sql
```
