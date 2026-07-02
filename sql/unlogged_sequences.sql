/*
 * Copyright (c) 2019-2026. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds unlogged sequences.
-- Unlogged sequences are not backed by WAL, so their state is not replicated to standbys
-- and they will be reset automatically after a server crash.
-- Their current value is lost after a crash, which may cause duplicate key errors
-- if used as default values for columns.
--
-- See https://www.postgresql.org/docs/current/sql-createsequence.html
select
    pc.oid::regclass::text as object_name,
    'sequence' as object_type
from
    pg_catalog.pg_class pc
    inner join pg_catalog.pg_namespace nsp on nsp.oid = pc.relnamespace
where
    pc.relkind = 'S' and
    pc.relpersistence = 'u' and
    nsp.nspname = :schema_name_param::text
order by object_name;
