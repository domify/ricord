# Names in Ricord

Ricord keeps Active Record's names where ris allows them. These rules decide the rest.

## One method per action

Each action has one method: `find`, `find_by`, `first`, `last`, `create`, `save`, `update`,
`destroy`, `reload`. A failure is returned as an error value, a member of the method's result
union (`RecordNotFound`, `RecordInvalid`, `ScopeError`, `CallbackError`, `DatabaseError`,
`AfterCommitError`). Nothing raises, so there is no second "strict" or "bang" form.

The caller decides what a failure means: check it with `is_a?` or `case`, return it to its own
caller, or stop the program with `.or_panic` where a failure is a bug.

```text
court = Court[db].find(id).or_panic         # a missing row is a bug here
result = court.save
return result if result.is_a?(::Ricord::Failures::Failure)
```

A method that may find nothing (`find_by`, `first`, `last`, `pick`) returns `nil` for nothing
and keeps errors for failures.

## No `!` in names

ris forbids a trailing `!` in declaration names (SPEC.md, section III.1.7, in
`~/contribute/ris1/doc/reference/iyi/source/SPEC.md`). Grant's `find!`, `save!`, `create!`,
`first!` and the like are gone, not renamed; the one method returns the error instead. The
`_strict` suffix Grant used for them is gone too.

## Allowed forms

* `_in_place` marks a method that changes its receiver, where one is needed. Ricord's query
  methods do not: every query method returns a new query.
* A name that is a ris keyword gets an alias with a plain word. Ricord has `or_where` (Grant
  also had `and_where`, `group_records` and `import_records`, which Ricord does not offer).
* `build` stands in for `new` on an association (`owner.cases.build(...)`): ris treats an
  instance method named `new` as in-place construction.
* A question mark ends a method that answers a `Bool`: `changed?`, `persisted?`,
  `new_record?`, `destroyed?`, `exists?`, `any?`, `empty?`, `valid?`.

## Modules and types

A module path is also a namespace. A module that holds a type of the same name is plural:
`ricord/sessions` holds `Session`, `ricord/failures` holds the error structs (`Error` is their
union), `ricord/storage` holds `Store`, `ricord/values` holds `TextSpan`. Generated code names
every type fully (`::Ricord::Failures::DatabaseError`), since it is expanded in the user's file.
