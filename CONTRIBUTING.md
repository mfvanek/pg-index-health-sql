## Implementing a new check

### Write a new SQL query

Each database structure check starts with an SQL query to the pg_catalog.

1. [SQLFluff](https://github.com/sqlfluff/sqlfluff) is used as a linter for all SQL queries
2. Always query `pg_catalog` system tables — never `information_schema`.
3. All `pg_catalog` table references must be fully schema-qualified:
    ```sql
    -- correct
    pg_catalog.pg_index pi
    -- wrong
    pg_index pi
    information_schema.columns
    ```
4. Use the same aliases as the existing SQL files for consistency.
5. All queries must be schema-aware, i.e. we filter out database objects on a schema basis:
   ```sql
   where
       nsp.nspname = :schema_name_param::text
   ```
   This filtering condition must appear exactly once per query file.
6. All tables, sequence and indexes names in the query results must be schema-qualified.
   We use `::regclass` on `oid` for that.
   ```sql
   select
       psui.relid::regclass::text as table_name,
       psui.indexrelid::regclass::text as index_name,
       s.seqrelid::regclass::text as sequence_name
   ```
7. All names should be enclosed in double quotes, if required.
8. The columns for the index or foreign key must be returned in the order they are used in the index or foreign key:
   ```sql
   select
       array_agg(quote_ident(a.attname) || ',' || a.attnotnull::text order by u.ordinality) as columns
   ```
9. All query results must be ordered in some way.
10. All queries must have a brief description.
    Links to documentation or articles with detailed descriptions are welcome.
11. The name of the sql-file with a query must correspond to diagnostic name in [Java project](https://github.com/mfvanek/pg-index-health).
12. Remember to update `README.md`.
