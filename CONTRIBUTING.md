## Implementing a new check

### Write a new SQL query

Each database structure check starts with an SQL query to the pg_catalog.

1. [SQLFluff](https://github.com/sqlfluff/sqlfluff) is used as a linter for all sql queries
2. All queries should be schema-aware, i.e. we filter out database objects on schema basis:
   ```sql
   where
       nsp.nspname = :schema_name_param::text
   ```
3. All tables and indexes names in the query results should be schema-qualified.
   We use `::regclass` on `oid` for that.
   ```sql
   select
       psui.relid::regclass::text as table_name,
       psui.indexrelid::regclass::text as index_name,
   ```
