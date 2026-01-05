/*
 * Copyright (c) 2019-2026. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds sequences that may overflow in the near future
--
-- Based on a query from https://habr.com/ru/articles/800121/
with
    all_sequences as (
        select
            s.seqrelid::regclass::text as sequence_name,
            s.seqtypid::regtype as data_type,
            s.seqstart as start_value,
            s.seqmin as min_value,
            s.seqmax as max_value,
            s.seqincrement as increment_by,
            case
                when has_sequence_privilege(c.oid, 'select,usage'::text) then pg_sequence_last_value(c.oid::regclass)
                else null::bigint
            end as last_value
        from
            pg_catalog.pg_sequence s
            inner join pg_catalog.pg_class c on c.oid = s.seqrelid
            left join pg_catalog.pg_namespace nsp on nsp.oid = c.relnamespace
        where
            not pg_is_other_temp_schema(nsp.oid) and /* not temporary */
            c.relkind = 'S'::char and /* sequence object */
            not s.seqcycle and /* skip cycle sequences */
            nsp.nspname = :schema_name_param::text
    ),

    sequence_state as (
        select
            t.sequence_name,
            t.data_type,
            case
                /* ascending or descending sequence */
                when t.increment_by > 0 then 100.0 * (t.max_value - coalesce(t.last_value, t.start_value)) / (t.max_value - t.min_value)
                else 100.0 * (coalesce(t.last_value, t.start_value) - t.min_value) / (t.max_value - t.min_value)
            end ::numeric(5, 2) as remaining_percentage /* percentage of remaining values */
        from all_sequences t
    )

select s.*
from sequence_state s
where
    s.remaining_percentage <= :remaining_percentage_threshold::numeric(5, 2)
order by s.sequence_name;
