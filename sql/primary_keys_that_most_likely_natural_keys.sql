/*
 * Copyright (c) 2019-2025. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds primary keys that are most likely natural keys.
-- It is better to use surrogate keys instead of natural ones.
-- See https://www.youtube.com/watch?v=s6m8Aby2at8
-- See also https://www.databasestar.com/database-keys/
with
    nsp as (
        select
            nsp.oid,
            nsp.nspname
        from pg_catalog.pg_namespace nsp
        where
            nsp.nspname = :schema_name_param::text
    )

select
    t.oid::regclass::text as table_name,
    c.conindid::regclass::text as index_name,
    pg_relation_size(c.conindid) as index_size,
    array_agg(quote_ident(col.attname) || ',' || col.attnotnull::text order by u.attposition) as columns
from
    pg_catalog.pg_constraint c
    inner join pg_catalog.pg_class t on t.oid = c.conrelid
    inner join nsp on nsp.oid = c.connamespace
    inner join lateral unnest(c.conkey) with ordinality u(attnum, attposition) on true
    inner join pg_catalog.pg_attribute col on col.attrelid = t.oid and col.attnum = u.attnum
where
    c.contype = 'p' and /* primary key constraint */
    c.conparentid = 0 and c.coninhcount = 0 and /* not a constraint in a partition */
    t.relkind = 'r' /* only regular tables */
group by t.oid, c.conindid
having bool_or(
        col.atttypid not in (
            'smallint'::regtype,
            'integer'::regtype,
            'bigint'::regtype,
            'uuid'::regtype
        )
    )

union all

select
    t.oid::regclass::text as table_name,
    c.conindid::regclass::text as index_name,
    pg_relation_size(c.conindid) as index_size,
    array_agg(quote_ident(col.attname) || ',' || col.attnotnull::text order by u.attposition) as columns
from
    pg_catalog.pg_constraint c
    inner join pg_catalog.pg_class t on t.oid = c.conrelid
    inner join nsp on nsp.oid = c.connamespace
    inner join lateral unnest(c.conkey) with ordinality u(attnum, attposition) on true
    inner join pg_catalog.pg_attribute col on col.attrelid = t.oid and col.attnum = u.attnum
where
    c.contype = 'p' and /* primary key constraint */
    c.conparentid = 0 and c.coninhcount = 0 and /* not a constraint in a partition */
    t.relkind = 'p' and /* only partitioned tables */
    not t.relispartition
group by t.oid, c.conindid
having bool_or(
        /* for partitioned tables decided to allow a few more data types that usually are used in ranges */
        col.atttypid not in (
            'smallint'::regtype,
            'integer'::regtype,
            'bigint'::regtype,
            'uuid'::regtype,
            'date'::regtype,
            'timestamp'::regtype,
            'timestamptz'::regtype,
            'time'::regtype,
            'timetz'::regtype
        )
    )
order by table_name, index_name;
