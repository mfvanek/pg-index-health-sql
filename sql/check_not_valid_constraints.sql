/*
 * Copyright (c) 2019-2024. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

select
    c.conrelid::regclass::text as table_name, -- Name of the table
    c.conname as constraint_name, -- Name of the constraint
    c.contype as constraint_type  -- Type of the constraint
from
    pg_catalog.pg_constraint c
    inner join pg_catalog.pg_namespace nsp on nsp.oid = c.connamespace
where
    not c.convalidated and -- Constraints that have not yet been validated
    c.contype in ('c', 'f') and -- Focus on check and foreign key constraints
    nsp.nspname = :schema_name_param::text -- Make the query schema-aware
order by table_name, c.conname;
