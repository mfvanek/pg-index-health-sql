# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**pg-index-health-sql** is a collection of PostgreSQL diagnostic SQL queries that detect structural issues in database schemas.
Each SQL file is a standalone check that queries `pg_catalog` system tables.
There is no build system — queries are executed directly against live PostgreSQL databases.

The SQL file names correspond 1:1 with diagnostic check names in the companion Java project [pg-index-health](https://github.com/mfvanek/pg-index-health).

## Linting

The only development tooling is **SQLFluff** for SQL linting. Run locally via Docker:

**Linux/macOS:**
```bash
docker run \
  -e RUN_LOCAL=true \
  -e USE_FIND_ALGORITHM=true \
  -e VALIDATE_SQLFLUFF=true \
  -v $(pwd):/tmp/lint \
  ghcr.io/super-linter/super-linter:slim-v8.6.0
```

**Windows (CMD):**
```bash
docker run ^
  -e RUN_LOCAL=true ^
  -e USE_FIND_ALGORITHM=true ^
  -e VALIDATE_SQLFLUFF=true ^
  -v "%cd%":/tmp/lint ^
  ghcr.io/super-linter/super-linter:slim-v8.6.0
```

SQLFluff configuration lives in `.github/linters/.sqlfluff` (PostgreSQL dialect, max line length 280).

## SQL Query Conventions

Every SQL file must follow these standards (enforced in PR review):

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

### Schema filtering (mandatory)
All queries must filter by schema using the `:schema_name_param` bind parameter:
```sql
where nsp.nspname = :schema_name_param::text
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
All result sets must have an `order by` clause to ensure consistent output.

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
sql/ext/          # Extension-dependent queries (requires pg_stat_statements)
.github/
  workflows/      # CI: SQLFluff lint runs on push/PR (changed files only)
  linters/        # .sqlfluff config
```

## Adding a New Check

1. Create `sql/{check_name}.sql` — name must match the Java project's diagnostic name.
2. Follow all conventions above (header, schema param, regclass casting, ordering).
3. Update `README.md` to add the check to the table.
4. Open a PR linked to an existing issue; complete every item in the PR checklist.

## Supported PostgreSQL Versions

PostgreSQL 14, 15, 16, 17, and 18. PostgreSQL 13 and earlier are not supported.
