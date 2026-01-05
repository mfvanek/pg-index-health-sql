/*
 * Copyright (c) 2019-2026. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds completely identical indexes.
select
    table_name,
    string_agg('idx=' || idx::text || ', size=' || pg_relation_size(idx), '; ') as duplicated_indexes
from (
    select
        pi.indexrelid::regclass as idx,
        pi.indrelid::regclass::text as table_name, /* cast to text for sorting purposes */
        (
            pi.indrelid::text || ' ' || pi.indclass::text || ' ' || pi.indkey::text || ' ' ||
            pi.indcollation::text || ' ' ||
            coalesce(pg_get_expr(pi.indexprs, pi.indrelid), '') || ' ' ||
            coalesce(pg_get_expr(pi.indpred, pi.indrelid), '')
        ) as grouping_key
    from
        pg_catalog.pg_index pi
        inner join pg_catalog.pg_class pc on pc.oid = pi.indexrelid
        inner join pg_catalog.pg_namespace nsp on nsp.oid = pc.relnamespace
    where
        nsp.nspname = :schema_name_param::text and
        not pc.relispartition
) sub
group by table_name, grouping_key
having count(*) > 1
order by table_name, sum(pg_relation_size(idx)) desc;
