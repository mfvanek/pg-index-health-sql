# Add a check for cyclical relationships between tables

## Why

Issue [pg-index-health#632](https://github.com/mfvanek/pg-index-health/issues/632) asks for an analogue of
SchemaCrawler's `LinterTableCycles`, which reports cyclical relationships between tables because they
"could cause issues with deletes and inserts".

A cycle of foreign keys between tables is a design smell even when it does not block inserts outright:

- inserts and deletes need a specific statement order followed by an `update`, or deferred constraints;
- `pg_dump --data-only` warns about circular foreign keys, and such a dump may not restore without `--disable-triggers`;
- `truncate` only works on all tables of the cycle at once, or with `cascade`;
- fixtures and ORMs cannot derive a load order for the data.

## What Changes

- Add `sql/cyclic_foreign_keys.sql`, a new diagnostic query that reports every simple cycle formed by
  foreign keys between two or more tables of a schema.
- Each result row describes one cycle as an ordered chain of foreign keys, so that a reader can see
  exactly which constraints form the cycle and decide which one to remove or redesign.
- Add the check to the list in `README.md`.

The check reports **any** cycle, including cycles made of `deferrable` foreign keys or foreign keys on
nullable columns. A narrower check that reports only cycles blocking plain inserts was considered and
rejected (see `design.md`).

## Impact

- Affected specs: `cyclic-foreign-keys` (new capability).
- Affected files: `sql/cyclic_foreign_keys.sql` (new), `README.md`.
- Companion Java project [pg-index-health](https://github.com/mfvanek/pg-index-health): needs a new
  diagnostic, a new model class and a new result set extractor. That work is tracked in the Java
  project; the expected shape is outlined in `design.md` so that the SQL result format fits it.
- No existing query changes. `self_referenced_foreign_keys.sql` keeps covering self-references.

## Confirmed Decisions

1. **Check name** — `cyclic_foreign_keys`, by analogy with `duplicated_foreign_keys` and
   `intersected_foreign_keys`. The name must match the diagnostic name in the Java project.
2. **Result format** — one row per cycle with three parallel arrays (`table_names`,
   `constraint_names`, `columns`) and no separate `table_name` column (see `design.md`).
