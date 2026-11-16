# Cyclic foreign keys

## ADDED Requirements

### Requirement: Detect cycles of foreign keys between tables

The check SHALL report every simple cycle formed by foreign keys between two or more distinct tables
of the schema given by `:schema_name_param`. An edge of the graph SHALL lead from the referencing table
to the referenced table.

#### Scenario: Two tables reference each other

- **WHEN** table `a` has a foreign key to table `b` and table `b` has a foreign key to table `a`
- **THEN** the result contains exactly one row describing the cycle `a -> b -> a`

#### Scenario: Cycle of three tables

- **WHEN** `a` references `b`, `b` references `c` and `c` references `a`
- **THEN** the result contains exactly one row describing the cycle `a -> b -> c -> a`

#### Scenario: Table references a cycle without being part of it

- **WHEN** `a` and `b` reference each other and table `f` references `a`
- **THEN** no reported cycle contains `f`

#### Scenario: No cycles

- **WHEN** the foreign keys of the schema form no cycle
- **THEN** the result is empty

### Requirement: Report cycles regardless of deferrability and nullability

The check SHALL treat a foreign key as an edge of the graph whether or not the constraint is
`deferrable` and whether or not its columns are nullable.

#### Scenario: Cycle through a deferrable foreign key

- **WHEN** a cycle contains a foreign key declared `deferrable initially deferred`
- **THEN** the cycle is reported

#### Scenario: Cycle through a nullable column

- **WHEN** a cycle contains a foreign key whose column is nullable
- **THEN** the cycle is reported and that column has `false` as its not-null flag in `columns`

### Requirement: Exclude self-referenced foreign keys

The check SHALL ignore foreign keys whose referencing table and referenced table are the same.

#### Scenario: Table references itself

- **WHEN** table `g` has a foreign key to itself and takes part in no other cycle
- **THEN** the result contains no row for `g`

### Requirement: Limit detection to a single schema

The check SHALL build the graph only from foreign keys that belong to the schema given by
`:schema_name_param`, and the schema filter SHALL appear exactly once in the query. Cycles that pass
through a table in another schema SHALL NOT be reported.

#### Scenario: Cycle passes through another schema

- **WHEN** `s1.a` references `s2.b`, `s2.b` references `s1.a` and the check runs for schema `s1`
- **THEN** the result is empty

### Requirement: Support partitioned tables

The check SHALL report a cycle involving a partitioned table once, in terms of the parent table, and
SHALL exclude constraints inherited into partitions (`c.conparentid = 0 and c.coninhcount = 0`).
Separate partitions SHALL be ignored: a foreign key declared directly on a partition, or referencing
a partition directly, SHALL NOT be an edge of the graph (`not relispartition` for both the referencing
and the referenced table).

#### Scenario: Partitioned table in a cycle

- **WHEN** partitioned table `p` with several partitions and table `q` reference each other
- **THEN** the result contains exactly one row describing the cycle `p -> q -> p` and no row mentions a partition

#### Scenario: Foreign keys from and to a partitioned table without a cycle

- **WHEN** partitioned table `p` references table `a` and table `b` references `p`
- **THEN** the result is empty

#### Scenario: Cycle through foreign keys declared on a partition

- **WHEN** partition `p_1` of table `p` has its own foreign key to table `q`, `q` references `p_1` directly
  and the parent table `p` has no foreign keys
- **THEN** the result is empty

### Requirement: Enumerate cycles over constraints

The check SHALL enumerate cycles over foreign key constraints rather than over pairs of tables, so
that parallel foreign keys between the same tables produce separate cycles.

#### Scenario: Two parallel foreign keys

- **WHEN** `a` has two foreign keys to `c` and `c` has one foreign key to `a`
- **THEN** the result contains two rows, one for each foreign key from `a` to `c`

#### Scenario: Overlapping cycles

- **WHEN** `a` references `c`, `c` references `a`, `c` references `b` and `b` references `a`
- **THEN** the result contains one row for `a -> c -> a` and one row for `a -> c -> b -> a`

### Requirement: Canonical and deterministic representation of a cycle

Each cycle SHALL be reported exactly once and SHALL start from the table with the smallest name among
the tables of the cycle. Table names SHALL be compared as `regclass::text` values using the default
collation of the database. The result SHALL be ordered by `table_names` and then by `constraint_names`.

#### Scenario: Cycle is not repeated for each of its tables

- **WHEN** `a` references `b`, `b` references `c` and `c` references `a`
- **THEN** the result contains one row starting from `a` and no rows starting from `b` or `c`

#### Scenario: Same schema in two databases with different oids

- **WHEN** the same schema is created in two databases where the tables received different oids
- **THEN** the check returns identical rows in the same order in both databases

#### Scenario: Same schema in two databases with the same locale

- **WHEN** the same schema is created in two databases that have the same default collation
- **THEN** every cycle starts from the same table in both databases and the rows come in the same order

### Requirement: Result set format

The check SHALL return one row per cycle with exactly the following columns:

- `table_names` — array of referencing tables as `regclass::text` in cycle order, one element per foreign key column;
- `constraint_names` — array of constraint names wrapped in `quote_ident()`, one element per foreign key column;
- `columns` — array of columns in the established `quote_ident(name) || ',' || not_null` format.

The three arrays SHALL have equal length, and the columns of a multi-column foreign key SHALL keep
their original order within the constraint. The table referenced by a foreign key SHALL be implied by
the order of the chain: it is the table of the next foreign key, and for the last foreign key it is
the first table.

#### Scenario: Cycle of single-column foreign keys

- **WHEN** `customers` references `orders` by `(last_order_id)` via `customers_last_order_fk` and
  `orders` references `customers` by `(customer_id)` via `orders_customer_fk`
- **THEN** the row has `table_names` = `{customers,orders}`,
  `constraint_names` = `{customers_last_order_fk,orders_customer_fk}` and
  `columns` listing `last_order_id`, `customer_id` in that order

#### Scenario: Cycle with a multi-column foreign key

- **WHEN** `customers` references `orders` by `(last_order_id)` via `customers_last_order_fk` and
  `orders` references `customers` by `(customer_id, region_id)` via `orders_customer_fk`
- **THEN** the row has `table_names` = `{customers,orders,orders}`,
  `constraint_names` = `{customers_last_order_fk,orders_customer_fk,orders_customer_fk}` and
  `columns` listing `last_order_id`, `customer_id`, `region_id` in that order

### Requirement: Treat not enforced foreign keys as regular foreign keys

The check SHALL NOT reference `pg_constraint.conenforced` and SHALL treat `not enforced` foreign keys
of PostgreSQL 18 like any other foreign key. The query file SHALL state this behaviour in a comment.

#### Scenario: Query runs on PostgreSQL 14

- **WHEN** the query is executed on PostgreSQL 14, where `conenforced` does not exist
- **THEN** the query completes without error

#### Scenario: Not enforced foreign key in a cycle on PostgreSQL 18

- **WHEN** a cycle contains a foreign key declared `not enforced`
- **THEN** the cycle is reported
