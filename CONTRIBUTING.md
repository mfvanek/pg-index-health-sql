## Implementing a new check

### Write a new SQL query

Each database structure check starts with an SQL query to the pg_catalog.

1. [SQLFluff](https://github.com/sqlfluff/sqlfluff) is used as a linter for all sql queries
2. All queries must be schema-aware, i.e. we filter out database objects on schema basis:
   ```sql
   where
       nsp.nspname = :schema_name_param::text
   ```
3. All tables and indexes names in the query results must be schema-qualified.
   We use `::regclass` on `oid` for that.
   ```sql
   select
       psui.relid::regclass::text as table_name,
       psui.indexrelid::regclass::text as index_name,
   ```
4. All query results must be ordered in some way.
5. All queries must have a brief description.
   Links to documentation or articles with detailed descriptions are welcome.
6. Name of the sql-file with query must correspond to diagnostic name in [Java project](https://github.com/mfvanek/pg-index-health).
7. Do not forget to update `README.md`.
