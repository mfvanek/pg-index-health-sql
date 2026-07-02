/*
 * Copyright (c) 2019-2026. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds unlogged tables (including unlogged partitioned tables).
-- Unlogged tables are not backed by WAL, so data in them is not replicated to standbys
-- and will be truncated automatically after a server crash.
-- They are unsuitable for storing persistent data.
--
-- See https://www.postgresql.org/docs/current/sql-createtable.html#SQL-CREATETABLE-UNLOGGED
select
    pc.oid::regclass::text as table_name,
    pg_table_size(pc.oid) as table_size
from
    pg_catalog.pg_class pc
    inner join pg_catalog.pg_namespace nsp on nsp.oid = pc.relnamespace
where
    pc.relkind in ('r', 'p') and
    pc.relpersistence = 'u' and
    nsp.nspname = :schema_name_param::text
order by table_name;
