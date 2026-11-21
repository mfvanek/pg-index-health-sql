# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Git Commits (for AI agents)

**Never commit changes until the user explicitly asks.** Every commit must be approved by the user.
Make and stage edits as needed, but do not run `git commit` (or `git push`) on your own initiative —
wait for an explicit instruction such as "commit" or "push" from the user.

## Project Overview

**pg-index-health-sql** is a collection of PostgreSQL diagnostic SQL queries that detect structural issues in database schemas.
Each SQL file is a standalone check that queries `pg_catalog` system tables.
There is no build system — queries are executed directly against live PostgreSQL databases.

The SQL file names correspond 1:1 with diagnostic check names in the companion Java project [pg-index-health](https://github.com/mfvanek/pg-index-health).

## Linting

**SQLFluff** is used for SQL linting (CI: `.github/workflows/sqlfluff.yml`). Run locally via Docker:

**Linux/macOS:**
```bash
docker run --rm \
  -v "$(pwd)":/sql \
  sqlfluff/sqlfluff:4.5.0 lint /sql/sql
```

**Windows (PowerShell):**
```powershell
docker run --rm `
  -v "${PWD}:/sql" `
  sqlfluff/sqlfluff:4.5.0 lint /sql/sql
```

Keep the SQLFluff image tag in sync between the workflow, `README.md` and this file.

SQLFluff configuration lives in `.sqlfluff` at the repository root (PostgreSQL dialect, max line length 280).

## SQL Query Conventions

Every SQL file must follow these standards (enforced in PR review):

### Lowercase only
All SQL keywords, functions, and identifiers must be written in lowercase. No uppercase or mixed-case SQL.

### Required file header
```sql
/*
 * Copyright (c) 2019-2026. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */
-- Brief description of what this check detects
```

### Partitioned tables
If a check is applicable to partitioned tables, it must support them explicitly. The approach depends on the check:

- **Table-based checks** — include partitioned parent tables (`relkind in ('r', 'p')`) and exclude child partitions (`not pc.relispartition`). Some checks intentionally include child partitions — document the reason in a comment when deviating.
- **Index-based checks** — exclude child partition tables: `not pc.relispartition`.
- **Constraint-based checks** — exclude constraints inherited into partitions: `c.conparentid = 0 and c.coninhcount = 0`.

### Schema filtering (mandatory)
All queries must filter by schema using the `:schema_name_param` bind parameter,
and this filtering condition must appear exactly once per query file:
```sql
where nsp.nspname = :schema_name_param::text
```

### Result set column aliases
Use the same column aliases as the existing SQL files. The established conventions are:

| Concept | Alias |
|---|---|
| Table name | `table_name` |
| Index name | `index_name` |
| Sequence name | `sequence_name` |
| Column name | `column_name` |
| Column data type | `column_type` |
| Whether column is NOT NULL | `column_not_null` |
| Array of column names | `columns` |
| Constraint name | `constraint_name` |
| Table size in bytes | `table_size` |
| Index size in bytes | `index_size` |
| Bloat size in bytes | `bloat_size` |
| Bloat percentage | `bloat_percentage` |

### Table aliases
Use the same aliases as the existing SQL files for consistency. The established conventions are:

| Table | Alias |
|---|---|
| `pg_catalog.pg_namespace` | `nsp` |
| `pg_catalog.pg_class` | `pc` |
| `pg_catalog.pg_index` | `pi` |
| `pg_catalog.pg_attribute` | `col` |
| `pg_catalog.pg_constraint` | `c` |
| `pg_catalog.pg_stat_user_indexes` | `psui` |
| `pg_catalog.pg_stat_all_indexes` | `psai` |

### System catalog usage
Always query `pg_catalog` system tables — never `information_schema`. All `pg_catalog` table references must be fully schema-qualified:
```sql
-- correct
pg_catalog.pg_index pi
-- wrong
pg_index pi
information_schema.columns
```

### OID-to-name conversion
Use `::regclass::text` for table, sequence and index names — never raw OIDs:
```sql
pi.indrelid::regclass::text as table_name,
pi.indexrelid::regclass::text as index_name,
s.seqrelid::regclass::text as sequence_name
```

### Identifier quoting
Wrap constraint/column/index names in `quote_ident()` when returning them as text.

### Ordering
All result sets must have an `order by` clause, and the order must be deterministic:
the same schema must always produce the same rows in the same order, regardless of data volume, statistics or object creation order.

- **Use a unique sort key.** The `order by` columns together must uniquely identify each row. Established keys:

  | Result kind | `order by` |
  |---|---|
  | Table-level | `table_name` |
  | Index-level | `table_name, index_name` |
  | Column-level | `table_name, column_name` |
  | Constraint-level | `table_name, constraint_name` |
  | Object-level (`objects_*`) | `object_type, object_name` |
  | Sequence-level | `sequence_name` |

- **Sort by names, not by volatile values.** Never use sizes (`pg_relation_size`, `pg_table_size`), statistics counters
  (`idx_scan`, `seq_scan`), OIDs, or arrays of columns as a sort key: they change over time, depend on creation order, or produce ties.
- **Sort by the output aliases**, not by raw catalog columns. Names are returned through `quote_ident()`/`::regclass::text`,
  so use `order by table_name, constraint_name`, not `order by table_name, c.conname`.
- **Order inside aggregates too.** Every `string_agg`/`array_agg` that builds a list of objects must have its own `order by`
  (e.g. `string_agg(... order by idx::text)`), so the content of a value is stable.
- **Build pairs in name order.** When a self-join produces pairs of objects (intersected/duplicated indexes or foreign keys),
  deduplicate them by name (`a.index_name < b.index_name`), not by OID.

### Column order preservation
When returning index or foreign key columns, maintain original column order using `array_agg(... order by u.ordinality)`.

### Complex logic
Use CTEs (`with ... as (...)`) rather than deeply nested subqueries.
See `bloated_indexes.sql` and `intersected_foreign_keys.sql` for examples.

### SQLFluff suppressions
Use `-- noqa: disable=RULE` inline comments when linter rules must be overridden.

## Repository Structure

```
sql/              # One .sql file per diagnostic check (40+ checks)
.sqlfluff         # SQLFluff config (PostgreSQL dialect)
.github/
  workflows/      # CI workflows (sqlfluff.yml: lints sql/ on push to master and on PRs)
  dependabot.yml  # Weekly updates for GitHub Actions
```

## GitHub Workflows and Badges

- `.github/workflows/sqlfluff.yml` ("Lint with SQLFluff") is the only CI workflow. It runs the
  `sqlfluff/sqlfluff` Docker image against the whole `sql/` directory and reports issues as GitHub annotations
  (`--format github-annotation-native`). The config is picked up automatically from the root `.sqlfluff`.
- Every workflow has a status badge at the top of `README.md`, next to the license badge. The badge text matches
  the workflow `name:`, and both the image and the link point to the workflow file:
  ```markdown
  [![Lint with SQLFluff](https://github.com/mfvanek/pg-index-health-sql/actions/workflows/sqlfluff.yml/badge.svg)](https://github.com/mfvanek/pg-index-health-sql/actions/workflows/sqlfluff.yml)
  ```
- When adding, renaming or removing a workflow (file name or `name:`), update its badge in `README.md` in the same change,
  and update the workflow references in this file.
- Dependabot (`.github/dependabot.yml`) checks GitHub Actions versions weekly. When the SQLFluff image tag
  (`docker://sqlfluff/sqlfluff:<version>`) changes, update the local lint commands in `README.md` and this file to match.

## Adding a New Check

1. Create `sql/{check_name}.sql` — name must match the Java project's diagnostic name.
2. Follow all conventions above (header, schema param, regclass casting, ordering).
3. Update `README.md` to add the check to the table.
4. Open a PR linked to an existing issue; complete every item in the PR checklist.

### Object-level vs column-level checks
When a check applies to both database objects (tables, indexes, sequences, views, functions, constraints) and columns, split it into two separate files:
- `objects_*.sql` — covers object-level names only; returns `object_name` and `object_type`.
- `columns_*.sql` — covers column-level names only; returns `table_name`, `column_not_null`, and `column_name`.

See `objects_with_upper_case_names.sql` / `columns_with_upper_case_names.sql` and
`objects_not_following_naming_convention.sql` / `columns_not_following_naming_convention.sql` as examples.

## Supported PostgreSQL Versions

PostgreSQL 14, 15, 16, 17, and 18. PostgreSQL 13 and earlier are not supported.
