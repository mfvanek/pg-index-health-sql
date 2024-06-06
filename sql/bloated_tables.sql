/*
 * Copyright (c) 2019-2024. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds tables with the bloat.
--
-- Based on
-- https://wiki.postgresql.org/wiki/Show_database_bloat
-- https://github.com/dataegret/pg-utils/blob/master/sql/table_bloat.sql
-- https://github.com/pgexperts/pgx_scripts/blob/master/bloat/table_bloat_check.sql
-- https://github.com/ioguix/pgsql-bloat-estimation/blob/master/table/table_bloat.sql
--
-- Please note!
-- The user on whose behalf this sql query will be executed
-- have to have read permissions for the corresponding tables.
-- noqa: disable=ST06
with
    tables_stats as (
        select
            pc.oid as table_oid,
            pc.reltuples,
            pc.relpages as heap_pages,
            coalesce(toast.relpages, 0) as toast_pages,
            coalesce(toast.reltuples, 0) as toast_tuples,
            coalesce(substring(array_to_string(pc.reloptions, ' ') from 'fillfactor=([0-9]+)')::smallint, 100) as fill_factor,
            current_setting('block_size')::bigint as block_size,
            case when version() ~ 'mingw32' or version() ~ '64-bit|x86_64|ppc64|ia64|amd64' then 8 else 4 end as max_align,
            24 as page_header_size,
            23 + case when max(coalesce(ps.null_frac, 0)) > 0 then (7 + count(ps.attname)) / 8 else 0::int end + case when bool_or(pa.attname = 'oid' and pa.attnum < 0) then 4 else 0 end as table_tuple_header_size,
            sum((1 - coalesce(ps.null_frac, 0)) * coalesce(ps.avg_width, 0)) as null_data_width,
            bool_or(pa.atttypid = 'pg_catalog.name'::regtype) or sum(case when pa.attnum > 0 then 1 else 0 end) <> count(ps.attname) as stats_not_available
        from
            pg_attribute pa
            inner join pg_class pc on pc.oid = pa.attrelid
            inner join pg_namespace pn on pn.oid = pc.relnamespace
            left join pg_stats ps on ps.schemaname = pn.nspname and ps.tablename = pc.relname and ps.inherited = false and ps.attname = pa.attname
            left join pg_class toast on toast.oid = pc.reltoastrelid
        where
            not pa.attisdropped and
            pc.relkind = 'r' and
            pc.relpages > 0 and
            pn.nspname = :schema_name_param::text
        group by table_oid, pc.reltuples, heap_pages, toast_pages, toast_tuples, fill_factor, block_size, page_header_size
    ),

    tables_pages_size as (
        select
            (
                4 + table_tuple_header_size + null_data_width + (2 * max_align) -
                case when table_tuple_header_size % max_align = 0 then max_align else table_tuple_header_size % max_align end -
                case when ceil(null_data_width)::int % max_align = 0 then max_align else ceil(null_data_width)::int % max_align end
            ) as tpl_size,
            block_size - page_header_size as size_per_block,
            heap_pages + toast_pages as table_pages_count,
            reltuples,
            toast_tuples,
            block_size,
            page_header_size,
            table_oid,
            fill_factor,
            stats_not_available
        from tables_stats
    ),

    relation_stats as (
        select
            ceil(reltuples / ((block_size - page_header_size) * fill_factor / (tpl_size * 100))) + ceil(toast_tuples / 4) as estimated_pages_count,
            table_pages_count,
            block_size,
            table_oid::regclass::text as table_name,
            pg_table_size(table_oid) as table_size,
            stats_not_available
        from tables_pages_size
    ),

    corrected_relation_stats as (
        select
            table_name,
            table_size,
            (case when table_pages_count - estimated_pages_count > 0 then table_pages_count - estimated_pages_count else 0 end)::bigint as pages_ff_diff,
            block_size,
            stats_not_available
        from relation_stats
    ),

    bloat_stats as (
        select
            table_name,
            table_size,
            block_size * pages_ff_diff as bloat_size,
            case when table_size > 0 then round(100 * block_size * pages_ff_diff / table_size::numeric, 2) else 0 end ::numeric(5, 2) as bloat_percentage,
            stats_not_available
        from corrected_relation_stats
    )

select *
from bloat_stats
where
    not stats_not_available and
    bloat_percentage >= :bloat_percentage_threshold::numeric(5, 2)
order by table_name;
