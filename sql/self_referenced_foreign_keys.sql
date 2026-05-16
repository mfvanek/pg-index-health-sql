/*
 * Copyright (c) 2019-2026. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds self-referenced foreign keys (where a table references itself) with no ON DELETE rule or with ON DELETE RESTRICT.
--
-- Self-referenced foreign keys are commonly used to model hierarchical or tree-structured data,
-- such as category trees, organizational charts, threaded comments, or bill-of-materials.
--
-- When the ON DELETE action is NO ACTION (the default when no rule is specified) or RESTRICT,
-- deleting a parent row that is still referenced by child rows will fail with a foreign key violation error.
-- To remove a node from such a hierarchy, the application must first recursively delete or re-parent
-- all descendants, which requires complex logic and careful transaction ordering.
-- In high-concurrency scenarios this also increases the risk of deadlocks.
--
-- Preferred alternatives:
--   ON DELETE CASCADE  - automatically removes all descendant rows when a parent is deleted;
--                        safe when the entire subtree should be removed together.
--   ON DELETE SET NULL - sets the FK column to NULL in child rows, detaching them from the deleted parent
--                        and turning them into new root nodes; requires the FK column to be nullable.
--
-- See https://www.postgresql.org/docs/current/ddl-constraints.html#DDL-CONSTRAINTS-FK
-- See also schemacrawler.tools.linter.LinterForeignKeySelfReference https://www.schemacrawler.com/lint.html
select
    c.conrelid::regclass::text as table_name,
    quote_ident(c.conname) as constraint_name,
    array_agg(quote_ident(col.attname) || ',' || col.attnotnull::text order by u.attposition) as columns
from
    pg_catalog.pg_constraint c
    inner join lateral unnest(c.conkey) with ordinality u(attnum, attposition) on true
    inner join pg_catalog.pg_namespace nsp on nsp.oid = c.connamespace
    inner join pg_catalog.pg_attribute col on col.attrelid = c.conrelid and col.attnum = u.attnum
where
    c.contype = 'f' and
    c.conrelid = c.confrelid and /* self-referenced: the referencing table is also the referenced table */
    c.confdeltype in ('a', 'r') and /* no ON DELETE rule (NO ACTION) or ON DELETE RESTRICT */
    c.conparentid = 0 and c.coninhcount = 0 and /* not a constraint in a partition */
    nsp.nspname = :schema_name_param::text
group by c.conrelid, c.conname, c.oid
order by table_name, constraint_name;
