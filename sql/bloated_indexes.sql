/*
 * Copyright (c) 2019-2024. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds indexes with the bloat.
--
-- Based on
-- https://wiki.postgresql.org/wiki/Show_database_bloat
-- https://blog.ioguix.net/postgresql/2014/03/28/Playing-with-indexes-and-better-bloat-estimate.html
-- https://github.com/ioguix/pgsql-bloat-estimation/blob/master/btree/btree_bloat.sql
-- https://github.com/pgexperts/pgx_scripts/blob/master/bloat/index_bloat_check.sql
-- https://github.com/lesovsky/uber-scripts/blob/master/postgresql/sql/show_bloat.sql
--
-- Please note!
-- The user on whose behalf this sql query will be executed
-- have to have read permissions for the corresponding tables.
-- noqa: disable=PRS,ST06,AM06
with
    indexes_data as (
        select
            pc.relname as inner_index_name,
            pc.reltuples,
            pc.relpages,
            pi.indrelid as table_oid,
            pi.indexrelid as index_oid,
            pi.indnatts,
            nsp.nspname,
            coalesce(substring(array_to_string(pc.reloptions, ' ') from 'fillfactor=([0-9]+)')::smallint, 90) as fill_factor,
            string_to_array(textin(int2vectorout(pi.indkey)), ' ')::int[] as indkey
        from
            pg_catalog.pg_index pi
            inner join pg_catalog.pg_class pc on pc.oid = pi.indexrelid
            inner join pg_catalog.pg_namespace nsp on nsp.oid = pc.relnamespace
        where
            pc.relam = (select oid from pg_catalog.pg_am where amname = 'btree') and
            pc.relpages > 0 and
            nsp.nspname = :schema_name_param::text
    ),

    nested_indexes_attributes as (
        select
            inner_index_name,
            reltuples,
            relpages,
            table_oid,
            index_oid,
            fill_factor,
            indkey,
            nspname,
            pg_catalog.generate_series(1, indnatts) as attpos
        from indexes_data
    ),

    named_indexes_attributes as (
        select
            ic.table_oid,
            ct.relnamespace,
            ic.inner_index_name,
            ic.attpos,
            ic.indkey,
            ic.indkey[ic.attpos] as indattpos,
            ic.reltuples,
            ic.relpages,
            ic.index_oid,
            ic.fill_factor,
            coalesce(a1.attnum, a2.attnum) as attnum,
            coalesce(a1.attname, a2.attname) as attname,
            coalesce(a1.atttypid, a2.atttypid) as atttypid,
            ic.nspname,
            case when a1.attnum is null then ic.inner_index_name else ct.relname end as attrelname
        from
            nested_indexes_attributes ic
            inner join pg_catalog.pg_class ct on ct.oid = ic.table_oid
            left join pg_catalog.pg_attribute a1 on ic.indkey[ic.attpos] <> 0 and a1.attrelid = ic.table_oid and a1.attnum = ic.indkey[ic.attpos]
            left join pg_catalog.pg_attribute a2 on ic.indkey[ic.attpos] = 0 and a2.attrelid = ic.index_oid and a2.attnum = ic.attpos
    ),

    rows_data_stats as (
        select
            i.table_oid,
            i.reltuples,
            i.relpages,
            i.index_oid,
            i.fill_factor,
            current_setting('block_size')::bigint as block_size,
            /* max_align: 4 on 32bits, 8 on 64bits */
            case when version() ~ 'mingw32' or version() ~ '64-bit|x86_64|ppc64|ia64|amd64' then 8 else 4 end as max_align,
            /* per page header, fixed size: 20 for 7.x, 24 for others */
            24 as page_header_size,
            /* per page btree opaque data */
            16 as page_opaque_data_size,
            /* per tuple header: add indexattributebitmapdata if some cols are nullable */
            case
                when max(coalesce(s.null_frac, 0)) = 0 then 2 /* indextupledata size */
                else 2 + ((32 + 8 - 1) / 8) /* indextupledata size + indexattributebitmapdata size (max num filed per index + 8 - 1 /8) */
            end as index_tuple_header_size,
            /* remove null values and save space using it fractional part from stats */
            sum((1 - coalesce(s.null_frac, 0)) * coalesce(s.avg_width, 0)) as null_data_width,
            max(case when i.atttypid = 'pg_catalog.name'::regtype then 1 else 0 end) > 0 as stats_not_available
        from
            named_indexes_attributes i
            inner join pg_catalog.pg_namespace nsp on nsp.oid = i.relnamespace
            inner join pg_catalog.pg_stats s on s.schemaname = nsp.nspname and s.tablename = i.attrelname and s.attname = i.attname
        group by 1, 2, 3, 4, 5, 6, 7, 8, 9
    ),

    rows_header_stats as (
        select
            max_align,
            block_size,
            reltuples,
            relpages,
            index_oid,
            fill_factor,
            table_oid,
            (
                index_tuple_header_size + max_align -
                /* add padding to the index tuple header to align on max_align */
                case when index_tuple_header_size % max_align = 0 then max_align else index_tuple_header_size % max_align end +
                null_data_width + max_align -
                /* add padding to the data to align on max_align */
                case
                    when null_data_width = 0 then 0
                    when null_data_width::integer % max_align = 0 then max_align
                    else null_data_width::integer % max_align
                end
            )::numeric as null_data_header_width,
            page_header_size,
            page_opaque_data_size,
            stats_not_available
        from rows_data_stats
    ),

    relation_stats as (
        select
            /* itemiddata size + computed avg size of a tuple (null_data_header_width) */
            coalesce(1 + ceil(reltuples / floor((block_size - page_opaque_data_size - page_header_size) * fill_factor / (100 * (4 + null_data_header_width)::float))), 0)::bigint as estimated_pages_count,
            block_size,
            table_oid::regclass::text as table_name,
            index_oid::regclass::text as index_name,
            pg_relation_size(index_oid) as index_size,
            relpages,
            stats_not_available
        from rows_header_stats
    ),

    corrected_relation_stats as (
        select table_name,index_name,index_size,block_size,
            relpages,
            (case when relpages - estimated_pages_count > 0 then relpages - estimated_pages_count else 0 end)::bigint as pages_ff_diff,
            stats_not_available
        from relation_stats
    ),

    bloat_stats as (
        select
            table_name,
            index_name,
            index_size,
            block_size * pages_ff_diff as bloat_size,
            round(100 * block_size * pages_ff_diff / index_size::numeric, 2)::numeric(5, 2) as bloat_percentage,
            stats_not_available
        from corrected_relation_stats
    )

select *
from bloat_stats
where
    not stats_not_available and
    bloat_percentage >= :bloat_percentage_threshold::numeric(5, 2)
order by table_name, index_name;
