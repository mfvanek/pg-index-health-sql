select pi.indrelid::regclass::text   as table_name,
       pi.indexrelid::regclass::text as index_name,
       col.attname                   as column_name,
       col.attnotnull                as column_not_null
from
    pg_catalog.pg_index pi
    join pg_catalog.pg_class pc on pc.oid = pi.indexrelid
    join pg_catalog.pg_namespace pn on pn.oid = pc.relnamespace
    join pg_catalog.pg_attribute col on col.attrelid = pi.indrelid and col.attnum = any (pi.indkey)
where pn.nspname = 'public'::text
  and not pi.indisunique
  and pi.indisready
  and pi.indisvalid
  and col.atttypid = 'boolean'::regtype
order by table_name, index_name;
