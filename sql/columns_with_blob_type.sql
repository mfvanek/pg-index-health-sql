/*
 * Copyright (c) 2019-2026. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds columns that reference PostgreSQL large objects stored in pg_largeobject.
-- Such columns have type oid (raw large object handle) or lo (a domain over oid from the lo extension).
-- Large objects require additional reads from pg_largeobject on every access.
-- It is better to use bytea for binary data or text for character data instead.
--
-- See https://www.postgresql.org/docs/current/lo.html
-- See https://www.postgresql.org/docs/current/largeobjects.html
--
-- Similar to schemacrawler.tools.linter.LinterTooManyLobs https://www.schemacrawler.com/lint.html
-- See also https://www.enterprisedb.com/postgres-tutorials/postgresql-toast-and-working-blobsclobs-explained
select
    pc.oid::regclass::text as table_name,
    col.attnotnull as column_not_null,
    col.atttypid::regtype::text as column_type,
    quote_ident(col.attname) as column_name
from
    pg_catalog.pg_class pc
    inner join pg_catalog.pg_namespace nsp on nsp.oid = pc.relnamespace
    inner join pg_catalog.pg_attribute col on col.attrelid = pc.oid
where
    pc.relkind in ('r', 'p') and
    not pc.relispartition and
    col.attnum > 0 and /* to filter out system columns such as oid, ctid, xmin, xmax, etc. */
    not col.attisdropped and
    col.atttypid in (
        select pt.oid
        from
            pg_catalog.pg_type pt
            inner join pg_catalog.pg_namespace tn on tn.oid = pt.typnamespace
        where
            (pt.typname = 'oid' and tn.nspname = 'pg_catalog') or
            (pt.typname = 'lo' and pt.typtype = 'd') /* lo extension domain over oid */
    ) and
    nsp.nspname = :schema_name_param::text
order by table_name, column_name;
