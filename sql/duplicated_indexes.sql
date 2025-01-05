/*
 * Copyright (c) 2019-2025. Ivan Vakhrushev and others.
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
        x.indexrelid::regclass as idx,
        x.indrelid::regclass::text as table_name, /* cast to text for sorting purposes */
        (
            x.indrelid::text || ' ' || x.indclass::text || ' ' || x.indkey::text || ' ' ||
            x.indcollation::text || ' ' ||
            coalesce(pg_get_expr(x.indexprs, x.indrelid), '') || ' ' ||
            coalesce(pg_get_expr(x.indpred, x.indrelid), '')
        ) as grouping_key
    from
        pg_catalog.pg_index x
        inner join pg_catalog.pg_stat_all_indexes psai on psai.indexrelid = x.indexrelid
    where psai.schemaname = :schema_name_param::text
) sub
group by table_name, grouping_key
having count(*) > 1
order by table_name, sum(pg_relation_size(idx)) desc;
