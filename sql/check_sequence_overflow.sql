/*
 * Copyright (c) 2019-2024. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

select
    schemaname, -- schema name
    sequencename, -- check sequence growth direction (increment or decrement)
    case
        when increment_by > 0
        then
            100.0 * (max_value - coalesce(last_value, start_value)) / (max_value - min_value)
        else
            100.0 * (coalesce(last_value, start_value) - min_value) / (max_value - min_value)
    end :: numeric(5, 2) as remaining_percentage -- percentage of remaining values
from pg_catalog.pg_sequences
where not cycle -- exclude cyclic sequences
order by schemaname, sequencename;
