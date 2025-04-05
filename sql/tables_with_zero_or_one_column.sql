/*
 * Copyright (c) 2019-2025. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds tables that have zero or one column.
-- This usually indicates a poor database design.
-- If you really need a table with one column, for example, as a global index for partitioned tables,
-- just ignore the results of this check.
--
-- Based on https://github.com/sdblist/db_verifier/blob/main/shards/r1002.sql
select
    pc.oid::regclass::text as table_name,
    pg_table_size(pc.oid) as table_size,
    coalesce(array_agg(a.attname::text || ',' || a.attnotnull::text order by a.attnum) filter (where a.attname is not null), '{}') as columns
from
    pg_catalog.pg_class pc
    inner join pg_catalog.pg_namespace nsp on nsp.oid = pc.relnamespace
    left join pg_catalog.pg_attribute a on a.attrelid = pc.oid and a.attnum > 0 and not a.attisdropped
where
    pc.relkind in ('r', 'p') and
    not pc.relispartition and
    nsp.nspname = :schema_name_param::text
group by pc.oid
having count(a.attname) <= 1
order by table_name;
