/*
 * Copyright (c) 2019-2026. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds self-referenced foreign keys (where a table references itself) with no ON DELETE rule or with ON DELETE RESTRICT.
--
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
