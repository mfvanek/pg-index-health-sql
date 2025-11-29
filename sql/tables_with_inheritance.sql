/*
 * Copyright (c) 2019-2025. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds tables that use table inheritance.
-- Never use table inheritance. This is a completely bad idea.
--
-- See https://wiki.postgresql.org/wiki/Don%27t_Do_This#Don.27t_use_table_inheritance
-- Not applicable to partitioned tables
select
    pc.oid::regclass::text as table_name,
    pg_table_size(pc.oid) as table_size
from
    pg_catalog.pg_class pc
    inner join pg_catalog.pg_inherits i on i.inhrelid = pc.oid /* child table oid */
    inner join pg_catalog.pg_namespace nsp on nsp.oid = pc.relnamespace
where
    pc.relkind = 'r' and
    nsp.nspname = :schema_name_param::text
order by table_name;
