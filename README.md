# PostgREST Test Database

This database is a proof of concept to test PostgREST authentication model and compare performance
between different authentication models.
It's supposed to be used in conjunction with PostgreSQL's pgbench tool.


## Setup

To initialize a database named test 
with 100 companies and 10 projects in each run:
```
psql -v n_companies=100 -v n_projects=10 -v db=test < setup.sql
```
