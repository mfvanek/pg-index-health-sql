/*
 * Copyright (c) 2019-2024. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

with
-- combine fk constraints with the attributes involved in them
fk_with_attributes as (
        select
            c.conname as fk_name,
            c.conrelid,
            c.confrelid,
            fk_conkey.conkey_order as att_order,
            fk_conkey.conkey_number,
            fk_confkey.confkey_number,
            rel_att.attname as rel_att_name,
            rel_att.atttypid as rel_att_type_id,
            rel_att.atttypmod as rel_att_type_mod,
            rel_att.attnotnull as rel_att_notnull,
            frel_att.attname as frel_att_name,
            frel_att.atttypid as frel_att_type_id,
            frel_att.atttypmod as rel_att_type_mod,
            frel_att.attnotnull as rel_att_notnull
        from pg_catalog.pg_constraint as c
            cross join lateral unnest(c.conkey) with ordinality as fk_conkey(conkey_number, conkey_order)
            left join lateral unnest(c.confkey) with ordinality as fk_confkey(confkey_number, confkey_order)
                on fk_conkey.conkey_order = fk_confkey.confkey_order
            left join pg_catalog.pg_attribute as rel_att
                on rel_att.attrelid = c.conrelid and rel_att.attnum = fk_conkey.conkey_number
            left join pg_catalog.pg_attribute as frel_att
                on frel_att.attrelid = c.confrelid and frel_att.attnum = fk_confkey.confkey_number
        where c.contype in ('f')
    ),
    --
    fk_with_attributes_grouped as (
        select
            fk_name,
            conrelid,
            confrelid,
            array_agg (rel_att_name order by att_order) as rel_att_names,
            array_agg (frel_att_name order by att_order) as frel_att_names
        from fk_with_attributes
        group by 1, 2, 3
    )
select
    r_from.relname,  -- referencing relation
    c1.fk_name,      -- name of the fk constraint
    c2.fk_name       -- name of the fk constraint (potential duplicate)
from fk_with_attributes_grouped as c1
    inner join fk_with_attributes_grouped as c2 on c1.fk_name < c2.fk_name
        and c1.conrelid = c2.conrelid and c1.confrelid = c2.confrelid
        and c1.rel_att_names = c2.rel_att_names
    inner join pg_catalog.pg_class as r_from on r_from.oid = c1.conrelid;
