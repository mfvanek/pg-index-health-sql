/*
 * Copyright (c) 2019-2026. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds indexes in which columns with the timestamp[tz] type are not the last.
--
-- It always looks suspicious if in your index a field with obviously greater variation of the timestamp[tz] type is not the last.
-- You would better to use ESR rule (Equality/Sort/Range).
-- When creating a composite B-tree index:
--   * E — Equality: first, the columns for which the query uses =
--   * S — Sort: then the ones that are sorted (ORDER BY)
--   * R — Range: and only at the end are columns with ranges (>, <, BETWEEN)
-- See https://habr.com/ru/articles/911688/
-- See also https://www.postgresql.org/docs/current/indexes-multicolumn.html
--
-- Based on a query from https://habr.com/ru/companies/tensor/articles/488104/
with
    columns_with_opclass as (
        select
            pi.indrelid as table_oid,
            pi.indexrelid as index_oid,
            array_agg(
                case
                    when a.attnum is not null then quote_ident(a.attname) || ',' || a.attnotnull::text
                    else quote_ident(pg_get_indexdef(pi.indexrelid, u.attposition::int, true)) || ',true'
                end
                order by u.attposition
            ) as columns,
            array_agg(replace(op.opcname::text, '_ops', '') order by u.attposition) as opclasses
        from
            pg_catalog.pg_index pi
            inner join pg_catalog.pg_class pc on pc.oid = pi.indrelid
            inner join pg_catalog.pg_namespace nsp on nsp.oid = pc.relnamespace
            left join lateral unnest(pi.indkey) with ordinality u(attnum, attposition) on true
            left join pg_catalog.pg_attribute a on a.attrelid = pi.indrelid and a.attnum = u.attnum
            left join lateral unnest(pi.indclass) with ordinality uop(opcoid, attposition) on uop.attposition = u.attposition
            left join pg_catalog.pg_opclass op on op.oid = uop.opcoid
        where
            nsp.nspname = :schema_name_param::text and
            not pi.indisunique and
            pi.indisready and
            pi.indisvalid and
            not pc.relispartition
        group by pi.indrelid, pi.indexrelid
    )

select
    opc.table_oid::regclass::text as table_name,
    opc.index_oid::regclass::text as index_name,
    opc.columns,
    pg_relation_size(opc.index_oid) as index_size
from
    columns_with_opclass opc
where
    array_length(opc.opclasses,1) > 1 and
    (
        'timestamp' = any(opc.opclasses[1:array_upper(opc.opclasses,1) - 1]) or
        'timestamptz' = any(opc.opclasses[1:array_upper(opc.opclasses,1) - 1])
    )
order by table_name, index_name;
