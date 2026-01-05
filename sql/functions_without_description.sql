/*
 * Copyright (c) 2019-2026. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds functions and procedures that don't have a description.
-- See also https://www.postgresql.org/docs/current/sql-comment.html
select
    case when nsp.nspname = 'public'::text then quote_ident(p.proname) else quote_ident(nsp.nspname) || '.' || quote_ident(p.proname) end as function_name,
    pg_get_function_identity_arguments(p.oid) as function_signature
from
    pg_catalog.pg_namespace nsp
    inner join pg_catalog.pg_proc p on p.pronamespace = nsp.oid
where
    (obj_description(p.oid) is null or length(trim(obj_description(p.oid))) = 0) and
    nsp.nspname = :schema_name_param::text
order by function_name, function_signature;
