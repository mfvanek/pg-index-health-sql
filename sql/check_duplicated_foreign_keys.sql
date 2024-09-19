/*
 * Copyright (c) 2019-2024. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

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
    from pg_catalog.pg_constraint as c
    cross join
        lateral unnest(c.conkey)
        with ordinality as fk_conkey(conkey_number, conkey_order)
    left join
        lateral unnest(c.confkey)
        with ordinality as fk_confkey(confkey_number, confkey_order)
        on fk_conkey.conkey_order = fk_confkey.confkey_order
    left join pg_catalog.pg_attribute as rel_att
        on
            rel_att.attrelid = c.conrelid
            and rel_att.attnum = fk_conkey.conkey_number
    left join pg_catalog.pg_attribute as frel_att
        on
            frel_att.attrelid = c.confrelid
            and frel_att.attnum = fk_confkey.confkey_number
    where c.contype = 'f'
),

--
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
    r_from.relname as table_name,
    c1.fk_name as constraint_name,
    c2.fk_name as duplicate_constraint_name
from pg_catalog.pg_class as r_from
inner join pg_catalog.pg_namespace as nsp
    on r_from.relnamespace = nsp.oid
inner join fk_with_attributes_grouped as c1
    on r_from.oid = c1.conrelid
inner join fk_with_attributes_grouped as c2
    on
        c1.fk_name < c2.fk_name
        and c1.conrelid = c2.conrelid
        and c1.confrelid = c2.confrelid
        and c1.rel_att_names = c2.rel_att_names
where nsp.nspname = :schema_name_param::text;
