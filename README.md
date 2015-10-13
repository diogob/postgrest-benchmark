# PostgREST Test Database

This database is a proof of concept to test PostgREST authentication model and compare performance
between different authentication models.
It's supposed to be used in conjunction with PostgreSQL's pgbench tool.


## Setup

To initialize a database named test using the one role per user model
with 100 companies and 10 projects in each run:
```
psql -v n_companies=100 -v n_projects=10 -v db=test -v variation=one_role_per_user < setup.sql
```

The variation parameter changes the way the database functions identify users and its privileges.
To benchmark different variations is important to setup and run the benchmarking scripts for the same variation.

## Benchmarking

To test with 10 concurrent clients for 60 seconds using admin and employee sample transactions
for the one role per user model:

```
pgbench -f one_role_per_user/admin_transaction.sql -f one_role_per_user/employee_transaction.sql -c 10 -T 60 test
```

## Results

### 1 role per user

```
number of clients: 10
number of threads: 1
duration: 60 s
number of transactions actually processed: 495
latency average: 1212.121 ms
tps = 8.181729 (including connections establishing)
tps = 8.182146 (excluding connections establishing)
```

### Group roles and user id in environment variable

```
number of clients: 10
number of threads: 1
duration: 60 s
number of transactions actually processed: 496
latency average: 1209.677 ms
tps = 8.232896 (including connections establishing)
tps = 8.233462 (excluding connections establishing)
```

### Group roles, user id and company id in environment variable

```
number of clients: 10
number of threads: 1
duration: 60 s
number of transactions actually processed: 2810
latency average: 213.523 ms
tps = 134.914966 (including connections establishing)
tps = 134.941945 (excluding connections establishing)
```
