# Tasks

## 1. Decisions

- [x] 1.1 Confirm the check name `cyclic_foreign_keys` (must match the Java diagnostic name)
- [x] 1.2 Confirm the result format: one row per cycle with parallel arrays, no `table_name` column

## 2. SQL query

- [x] 2.1 Create `sql/cyclic_foreign_keys.sql` with the required file header and a description of the check
- [x] 2.2 Build the foreign key graph: exclude self-references, constraints inherited into partitions and foreign keys from or to a separate partition, filter by `:schema_name_param` exactly once
- [x] 2.3 Enumerate simple cycles with a recursive CTE, starting each cycle from the table with the smallest name
- [x] 2.4 Return `table_names`, `constraint_names`, `columns` ordered by `table_names`, `constraint_names`
- [x] 2.5 Add a comment stating that `not enforced` foreign keys (PostgreSQL 18) are treated as regular foreign keys
- [x] 2.6 Add a reference to `schemacrawler.tools.linter.LinterTableCycles` in the file comment

## 3. Verification

- [x] 3.1 Run the query against a test schema covering every scenario of the spec
- [x] 3.2 Run the query on PostgreSQL 14, 15, 16, 17 and 18
- [x] 3.3 Lint with SQLFluff (`sqlfluff/sqlfluff:4.5.0 lint /sql/sql`)

## 4. Documentation

- [x] 4.1 Add the check to the list in `README.md`

## 5. Companion Java project (tracked in pg-index-health#632)

- [ ] 5.1 Add the `ForeignKeyCycle` model
- [ ] 5.2 Add a result set extractor that groups array elements into `ForeignKey` objects
- [ ] 5.3 Add the diagnostic and the check on host / on cluster
- [ ] 5.4 Make exclusions by table name match any table of a cycle, not only the first one
