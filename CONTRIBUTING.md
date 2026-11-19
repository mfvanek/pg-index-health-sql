## Implementing a new check

### Write a new SQL query

Each database structure check starts with an SQL query against `pg_catalog`.

1. [SQLFluff](https://github.com/sqlfluff/sqlfluff) is used as a linter for all SQL queries
2. Use only lowercase for all SQL keywords, functions, and identifiers.
3. Always query `pg_catalog` system tables — never `information_schema`.
4. All `pg_catalog` table references must be fully schema-qualified:
    ```sql
    -- correct
    pg_catalog.pg_index pi
    -- wrong
    pg_index pi
    information_schema.columns
    ```
5. Use the same table aliases as the existing SQL files for consistency.
6. Use the same column aliases as the existing SQL files.
7. All queries must be schema-aware, i.e. we filter out database objects on a schema basis:
   ```sql
   where
       nsp.nspname = :schema_name_param::text
   ```
   This filtering condition must appear exactly once per query file.
8. If a check is applicable to partitioned tables, it must support them explicitly.
   The approach depends on the check:
   - **Table-based checks** — include partitioned parent tables (`relkind in ('r', 'p')`) and exclude child partitions (`not pc.relispartition`).
     Some checks intentionally include child partitions — document the reason in a comment when deviating from this rule.
   - **Index-based checks** — exclude child partition tables: `not pc.relispartition`.
   - **Constraint-based checks** — exclude constraints inherited into partitions: `c.conparentid = 0 and c.coninhcount = 0`.
9. All table, sequence, and index names in the query results must be schema-qualified.
   We use `::regclass` on `oid` for that.
   ```sql
   select
       psui.relid::regclass::text as table_name,
       psui.indexrelid::regclass::text as index_name,
       s.seqrelid::regclass::text as sequence_name
   ```
10. All names should be enclosed in double quotes, if required.
11. Index and foreign key columns must be returned in the order they appear in the index or constraint definition:
    ```sql
    select
        array_agg(quote_ident(a.attname) || ',' || a.attnotnull::text order by u.ordinality) as columns
    ```
12. All query results must be ordered, and the order must be deterministic —
    the same schema must always produce the same rows in the same order:
    - The `order by` columns together must uniquely identify each row, e.g.
      `table_name` for tables, `table_name, index_name` for indexes, `table_name, column_name` for columns,
      `table_name, constraint_name` for constraints, `object_type, object_name` for `objects_*` checks.
    - Sort by names only. Don't sort by sizes, statistics counters, OIDs or arrays of columns:
      they change over time, depend on object creation order, or produce ties.
    - Sort by the output aliases (`constraint_name`), not by raw catalog columns (`c.conname`).
    - Every `string_agg`/`array_agg` that builds a list of objects must have its own `order by`:
      ```sql
      string_agg('idx=' || idx::text, '; ' order by idx::text)
      ```
    - When a self-join produces pairs of objects, deduplicate them by name (`a.index_name < b.index_name`), not by OID.
    - Queries in `sql/ext/` that rank by a metric with `limit` are an exception and sort by that metric.
13. All queries must have a brief description.
    Links to documentation or articles with detailed descriptions are welcome.
14. The SQL file name must match the corresponding diagnostic name in the [Java project](https://github.com/mfvanek/pg-index-health).
15. When a check applies to both database objects (tables, indexes, sequences, views, functions, constraints) and columns, split it into two separate files:
    - `objects_*.sql` — covers object-level names only; returns `object_name` and `object_type`.
    - `columns_*.sql` — covers column-level names only; returns `table_name`, `column_not_null`, and `column_name`.

    See `objects_with_upper_case_names.sql` / `columns_with_upper_case_names.sql` and
    `objects_not_following_naming_convention.sql` / `columns_not_following_naming_convention.sql` as examples.
16. Remember to update `README.md`.
