/*
 * Copyright (c) 2019-2026. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds cyclical relationships between tables: chains of foreign keys that lead from a table back to itself
-- through one or more other tables.
--
-- Such cycles are considered a design smell:
--   - inserts and deletes need a specific order of statements followed by an update, or deferred constraints;
--   - "pg_dump --data-only" warns about circular foreign keys and such a dump may not be restorable without --disable-triggers;
--   - truncate works only for all tables of the cycle at once (or with cascade);
--   - fixtures and ORMs cannot derive an order for loading the data.
--
-- Any cycle is reported, even if its foreign keys are deferrable or built on nullable columns.
-- Self-referenced foreign keys are not reported here, see self_referenced_foreign_keys.sql.
-- Cycles that pass through a table in another schema are not reported.
-- Foreign keys declared directly on a partition or referencing a partition directly are ignored:
-- partitioned tables take part in cycles only through the foreign keys of the parent table.
--
-- PostgreSQL 18 introduced NOT ENFORCED foreign keys (pg_constraint.conenforced).
-- They are still declared relationships between tables, so this check treats them as regular foreign keys.
-- The conenforced column is intentionally not used because it does not exist in PostgreSQL 14-17.
--
-- Each row describes one cycle as an ordered chain of foreign keys.
-- The three arrays have the same length and should be read position by position, one element per foreign key column
-- (a multicolumn foreign key takes several consecutive positions).
-- A foreign key references the table of the next foreign key in the chain; the last one references the first table.
--
-- A cycle of N tables can be written in N ways, so each cycle starts from the table with the smallest name
-- and is reported exactly once. The first table has no special meaning.
-- Names are compared using the default collation of the database, so in databases with different locales
-- the same cycle may start from a different table.
--
-- The number of simple cycles can grow exponentially in a densely connected graph,
-- so the query may run for a long time on a large schema with a lot of intertwined cycles.
--
-- See also schemacrawler.tools.linter.LinterTableCycles https://www.schemacrawler.com/lint.html
with recursive
    fk_edges as (
        select
            c.oid as constraint_oid,
            c.conrelid as table_oid,
            c.confrelid as foreign_table_oid,
            c.conrelid::regclass::text as table_name,
            c.confrelid::regclass::text as foreign_table_name
        from
            pg_catalog.pg_constraint c
            inner join pg_catalog.pg_namespace nsp on nsp.oid = c.connamespace
            inner join pg_catalog.pg_class pc on pc.oid = c.conrelid
            inner join pg_catalog.pg_class pfc on pfc.oid = c.confrelid
        where
            c.contype = 'f' and
            c.conrelid != c.confrelid and /* self-referenced foreign keys are covered by a separate check */
            c.conparentid = 0 and c.coninhcount = 0 and /* not a constraint inherited into a partition */
            not pc.relispartition and not pfc.relispartition and /* foreign keys from or to a separate partition are ignored */
            nsp.nspname = :schema_name_param::text
    ),

    fk_paths as (
        select
            e.table_oid as start_table_oid,
            e.table_name as start_table_name,
            e.foreign_table_oid as last_table_oid,
            array[e.table_oid, e.foreign_table_oid] as visited_tables,
            array[e.constraint_oid] as constraints_path,
            false as is_cycle
        from fk_edges e
        where e.table_name < e.foreign_table_name /* a cycle starts from the table with the smallest name */

        union all

        select
            p.start_table_oid,
            p.start_table_name,
            e.foreign_table_oid,
            p.visited_tables || e.foreign_table_oid as visited_tables,
            p.constraints_path || e.constraint_oid as constraints_path,
            e.foreign_table_oid = p.start_table_oid as is_cycle
        from
            fk_paths p
            inner join fk_edges e on e.table_oid = p.last_table_oid
        where
            not p.is_cycle and
            (
                e.foreign_table_oid = p.start_table_oid or /* the cycle is closed */
                (e.foreign_table_name > p.start_table_name and e.foreign_table_oid != all(p.visited_tables))
            )
    )

select
    array_agg(c.conrelid::regclass::text order by s.constraint_position, u.attposition) as table_names,
    array_agg(quote_ident(c.conname) order by s.constraint_position, u.attposition) as constraint_names,
    array_agg(quote_ident(col.attname) || ',' || col.attnotnull::text order by s.constraint_position, u.attposition) as columns
from
    fk_paths p
    inner join lateral unnest(p.constraints_path) with ordinality s(constraint_oid, constraint_position) on true
    inner join pg_catalog.pg_constraint c on c.oid = s.constraint_oid
    inner join lateral unnest(c.conkey) with ordinality u(attnum, attposition) on true
    inner join pg_catalog.pg_attribute col on col.attrelid = c.conrelid and col.attnum = u.attnum
where p.is_cycle
group by p.constraints_path
order by table_names, constraint_names;
