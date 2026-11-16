# Design: cyclic foreign keys check

## Context

SchemaCrawler builds a directed graph of tables from foreign keys and runs Tarjan's algorithm to find
strongly connected components. A SQL query cannot run Tarjan directly, but a recursive CTE can either
compute reachability (which yields the components) or enumerate paths (which yields the cycles).

Two further constraints shaped the design:

- the result must make it clear **what to fix**;
- pg-index-health plans to generate corrective migrations from check results.

## Goals / Non-Goals

Goals:

- Report every simple cycle of foreign keys between two or more tables of the requested schema.
- Present each cycle as an ordered chain of constraints.
- Keep the result deterministic across databases, so that it can be asserted in tests.
- Fit the existing conventions of this repository and the row-to-object extractor model of the Java project.

Non-Goals:

- Self-referenced foreign keys — covered by `self_referenced_foreign_keys.sql`.
- Cycles that pass through a table in another schema.
- Foreign keys declared directly on a partition or referencing a partition directly. Partitioned
  tables take part in cycles only through the foreign keys of the parent table.
- Classifying cycles by severity (blocking versus non-blocking).
- Generating a corrective migration automatically (see "Corrective migrations").

## Decisions

### Report any cycle, not only cycles that block inserts

An earlier iteration restricted graph edges to "hard" foreign keys: not `deferrable` and with all
columns `not null`. A cycle of such keys cannot be populated by ordinary sequential inserts at all.

That variant was rejected. A schema with a hard cycle fails on the first attempt to insert data, so it
is caught during development and almost never reaches a live database; the check would practically
never fire. The check therefore treats **any** cycle as a code smell and bad design, regardless of
deferrability and nullability.

Consequence: the check will fire on legitimate schemas. A nullable back-reference such as
`orders.customer_id` plus `customers.last_order_id` is a common pattern. Exclusions by table or
constraint name in pg-index-health are the expected way to handle accepted cycles.

### Enumerate simple cycles rather than strongly connected components

| Option | Result | Why not chosen |
|---|---|---|
| Strongly connected components (SchemaCrawler semantics) | Set of tables per component | Does not show which constraints form which cycle |
| Flat list of foreign keys lying on any cycle | One row per foreign key | In a component with overlapping cycles it is unclear which keys belong together |
| **Simple cycles** | **Ordered chain of foreign keys per cycle** | **Chosen** |

Only an explicit chain answers "what do I fix" and lets a tool verify that every cycle is broken when
cycles overlap.

Cycles are enumerated over **constraints**, not over pairs of tables. Two parallel foreign keys
between the same pair of tables produce two distinct cycles, because both must be dealt with.

### Canonical form of a cycle

- Edge direction: from the referencing table to the referenced table, the way a foreign key reads.
- Each cycle starts from the table with the smallest name, where the name is `conrelid::regclass::text`
  — the same value that is returned in the result.
- The start table carries no meaning: all tables of a cycle are equal. The rule exists only so that
  a cycle of N tables, which can be written in N rotations, is reported once.
- The rule is applied during traversal, not afterwards: a path starting from a table may only continue
  to tables with a greater name, or return to the start table and close the cycle. A cycle is therefore
  found only when the traversal starts from its smallest table; other rotations are never built.
- Names are compared with the default collation of the database, like the `order by` of every other
  check in this repository. On a given database the result is deterministic. On databases with
  different locales (case, underscores) the same cycle may start from a different table; it is the
  same cycle written in another rotation.
- An explicit `collate "C"` was considered and rejected: no other query uses it, it is the only
  identifier that cannot be written in lowercase, and SQLFluff mistakes the collation name for a
  column reference, which required four `noqa` suppressions. If locale independence is ever needed,
  the canonical rotation can be computed in the Java model, where string comparison does not depend
  on the database locale.
- Names are used instead of oids: an oid comparison is cheaper and collation-independent, but oids
  depend on the order in which tables were created, which would make expected results in tests fragile.
- Because the graph is directed and the start is fixed, every cycle is reported exactly once.

### Result format: one row per cycle with parallel arrays

PostgreSQL arrays must be rectangular, so a variable-length list of foreign keys, each with its own
variable-length list of columns, cannot be returned as a nested array. The chosen format uses three
parallel arrays with **one element per foreign key column**:

| Column | Type | Meaning |
|---|---|---|
| `table_names` | `text[]` | Referencing table, repeated for each column of its foreign key |
| `constraint_names` | `text[]` | Constraint name, repeated for each column of the foreign key |
| `columns` | `text[]` | Column in the established `name,not_null` format |

The arrays are read position by position. The table referenced by a foreign key is not returned
separately: it is the table of the next foreign key in the chain, and for the last one it is the first table.

Typical case, all foreign keys are single-column, so the arrays are simply the path along the cycle:

```
 table_names                  | constraint_names                             | columns
------------------------------+----------------------------------------------+--------------------------------------------
 {demo.customers,demo.orders} | {customers_last_order_fk,orders_customer_fk} | {"last_order_id,false","customer_id,true"}
```

Same cycle where `orders_customer_fk` is a two-column key and therefore takes two positions:

```
 table_names                              | constraint_names                                                | columns
------------------------------------------+-----------------------------------------------------------------+-------------------------------------------------------------
 {demo.customers,demo.orders,demo.orders} | {customers_last_order_fk,orders_customer_fk,orders_customer_fk} | {"last_order_id,false","customer_id,true","region_id,true"}
```

The `columns` format is unchanged, so the existing column parser of the Java project is reused as is.
The cost is that a multi-column key repeats its table and constraint name.

There is deliberately no separate `table_name` column. It would always equal `table_names[1]`, and a
dedicated column would suggest that the first table is special, while it is only the canonical start.

Not included in the format: the referenced columns (absent from the Java `ForeignKey` model and not
needed to understand a cycle) and the cycle length (derivable from the data).

Alternatives considered:

- **One row per foreign key** with `cycle_number` and `position` columns. Every row matches the
  existing foreign key row format and nothing is repeated, but it breaks the "one row is one finding"
  contract of the Java `ResultSetExtractor`, and a cycle is spread over several rows identified by an
  artificial number when the query is run by hand.
- **A single `jsonb` column** with a list of objects. Self-describing, but no query in this repository
  returns JSON and the Java side would need a JSON parser.
- **One element per foreign key with its columns joined into a string.** Removes the repetition, but
  introduces a new encoding with its own parser, and the separator may occur inside a quoted identifier.

### No severity or deferrability columns

Nullability is already visible through the `not_null` flag in `columns`. A `deferrable` flag is not
returned: the Java `ForeignKey` model has no such attribute, and adding it only to distinguish the rare
blocking case is not justified now.

### PostgreSQL 18 `not enforced` foreign keys

PostgreSQL 18 introduced `not enforced` foreign keys (`pg_constraint.conenforced`). The check is about
schema design, and a `not enforced` key is still a declared relationship, so such keys are treated like
any other foreign key. The column does not exist in PostgreSQL 14-17 and is not referenced.
This behaviour must be stated in a comment in the query file.

## Java model (companion project, informative)

`DuplicatedForeignKeys` cannot be reused because it requires all keys to belong to the same table.
A new class modelled on it is expected:

```java
public final class ForeignKeyCycle implements DbObject, TableNameAware, ConstraintsAware, Comparable<ForeignKeyCycle> {

    // Ordered along the cycle: foreignKeys[i] references the table of foreignKeys[i + 1],
    // the last one references the table of the first one.
    private final List<ForeignKey> foreignKeys;

    public String getTableName() { return foreignKeys.get(0).getTableName(); }
    public String getName() { return String.join(",", foreignKeysNames); }
    public PgObjectType getObjectType() { return PgObjectType.CONSTRAINT; }
}
```

- `ForeignKey` stays unchanged: the referenced table is implied by the order of the list.
- Constructor validation: at least two foreign keys, no repeated tables.
- The extractor groups consecutive array elements by (table, constraint) into `ForeignKey` objects.
  The pair is required because constraint names are unique only within a table. Two different foreign
  keys cannot be merged by mistake, since tables do not repeat within a simple cycle.
- `getTableName()` returns only the canonical start table. Exclusions by table name must therefore
  check **every** table of the cycle; otherwise excluding `orders` would not hide a cycle that starts
  from `customers`. How the existing predicates of pg-index-health behave here has not been verified.
- A human-readable form such as `orders -[orders_customer_fk]-> customers -[customers_last_order_fk]-> orders` is desirable.

## Corrective migrations

For the rejected "hard cycles" variant a fix could be generated mechanically, because
`alter constraint ... deferrable` or `alter column ... drop not null` would remove the finding.
With the general check this no longer holds: only a model change removes a cycle (dropping the
back-reference or moving the relationship into a separate table). That choice is semantic, and
`drop constraint` loses integrity, so it cannot be generated safely. A generator can at most emit a
commented template. This is why the result must show the complete ordered cycle.

A reasonable hint for choosing the constraint to remove: the foreign key that takes part in the
largest number of reported cycles.

## Risks / Trade-offs

- **Number of simple cycles can grow exponentially** in a densely connected component. Foreign key
  graphs are normally sparse, so typical schemas are unaffected, but the query may run long on a large,
  heavily entangled schema. Fallback if this proves to be a problem: switch to strongly connected
  components.
- **False positives on accepted designs** — mitigated by exclusions in pg-index-health.
- **Cycles through partition-level foreign keys are missed** — accepted; separate partitions are
  ignored for now, which also guarantees that no reported cycle ever mentions a partition.
- **Cross-schema cycles are missed** — accepted; the schema filter is applied to the graph edges,
  which keeps the query cheap and the filter in a single place.
