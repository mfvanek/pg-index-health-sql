/*
 * Copyright (c) 2019-2024. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds potentially duplicated foreign keys
--
-- Based on query from https://habr.com/ru/articles/803841/
-- noqa: disable=PRS
with
    fk_with_attributes as (
        select
            c.conname as fk_name,
            c.conrelid,
            c.confrelid,
            fk_conkey.conkey_order as att_order,
            fk_conkey.conkey_number,
            fk_confkey.confkey_number,
            rel_att.attname as rel_att_name,
            rel_att.atttypid as rel_att_type_id_1,
            rel_att.atttypmod as rel_att_type_mod_1,
            rel_att.attnotnull as rel_att_notnull_1,
            frel_att.attname as frel_att_name,
            frel_att.atttypid as frel_att_type_id_2,
            frel_att.atttypmod as frel_att_type_mod_2,
            frel_att.attnotnull as frel_att_notnull_2
        from
            pg_catalog.pg_constraint c
            cross join lateral unnest(c.conkey) with ordinality fk_conkey(conkey_number, conkey_order)
            left join lateral unnest(c.confkey) with ordinality fk_confkey(confkey_number, confkey_order)
                on fk_confkey.confkey_order = fk_conkey.conkey_order
            left join pg_catalog.pg_attribute rel_att
                on rel_att.attrelid = c.conrelid and rel_att.attnum = fk_conkey.conkey_number
            left join pg_catalog.pg_attribute frel_att
                on frel_att.attrelid = c.confrelid and frel_att.attnum = fk_confkey.confkey_number
        where c.contype = 'f'
    ),

    fk_with_attributes_grouped as (
        select
            fk_name,
            conrelid,
            confrelid,
            array_agg(rel_att_name order by att_order) as rel_att_names,
            array_agg(frel_att_name order by att_order) as frel_att_names
        from fk_with_attributes
        group by fk_name, conrelid, confrelid
    )

select
    r_from.oid::regclass::text as table_name,
    c1.fk_name as constraint_name,
    c2.fk_name as duplicate_constraint_name
from
    pg_catalog.pg_class r_from
    inner join pg_catalog.pg_namespace nsp on nsp.oid = r_from.relnamespace
    inner join fk_with_attributes_grouped c1 on c1.conrelid = r_from.oid
    inner join fk_with_attributes_grouped c2
        on c2.fk_name > c1.fk_name and c2.conrelid = c1.conrelid and c2.confrelid = c1.confrelid and c2.rel_att_names = c1.rel_att_names
where
    r_from.relkind = 'r' and
    nsp.nspname = :schema_name_param::text
order by r_from.oid::regclass::text, c1.fk_name;
