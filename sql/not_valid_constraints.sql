/*
 * Copyright (c) 2019-2026. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds not validated constraints
--
-- Based on a query from https://habr.com/ru/articles/800121/
select
    c.conrelid::regclass::text as table_name,
    c.contype as constraint_type,
    quote_ident(c.conname) as constraint_name
from
    pg_catalog.pg_constraint c
    inner join pg_catalog.pg_namespace nsp on nsp.oid = c.connamespace
where
    not c.convalidated and /* constraints that have not yet been validated */
    c.contype in ('c', 'f') and /* focus on check and foreign key constraints */
    c.conparentid = 0 and c.coninhcount = 0 and /* not a constraint in a partition */
    nsp.nspname = :schema_name_param::text
order by table_name, c.conname;
