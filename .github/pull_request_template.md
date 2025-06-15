### Common steps

- [ ] Read [CONTRIBUTING.md](https://github.com/mfvanek/pg-index-health-sql/blob/master/CONTRIBUTING.md)
- [ ] Linked to an issue
- [ ] Added a description to PR

### For a database check

- [ ] Name of the sql file with the query correspond to a diagnostic name in [Java project](https://github.com/mfvanek/pg-index-health)
- [ ] Sql query has a brief description
- [ ] Sql query contains filtering by schema name
- [ ] All tables, indexes and sequences names in the query results are schema-qualified
- [ ] All names have been enclosed in double quotes (if necessary)
- [ ] The columns for the index or foreign key have been returned in the order they are used in the index or foreign key
- [ ] All query results have been ordered
- [ ] I have updated the [README.md](https://github.com/mfvanek/pg-index-health-sql/blob/master/README.md)

### Does this introduce a breaking change?

- [ ] Yes
- [ ] No
