/*
 * Copyright (c) 2019-2022. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds functions and procedures that don't have a description.
-- See also https://www.postgresql.org/docs/current/sql-comment.html
select
    case when n.nspname = 'public'::text then p.proname else n.nspname || '.' || p.proname end as function_name,
    pg_get_function_identity_arguments(p.oid) as function_signature
from
    pg_catalog.pg_namespace n
    join pg_catalog.pg_proc p on p.pronamespace = n.oid
where
    (obj_description(p.oid) is null or length(trim(obj_description(p.oid))) = 0) and
    n.nspname = :schema_name_param::text
order by function_name, function_signature;
