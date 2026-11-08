# Ricord contract

Ricord is an ORM for ris over SQLite and Turso. Its unit of work is a session:
`Ricord.open(url) do |db| ... end` opens one connection, and the block owns the
session, its store of records and everything read through it. A web worker
keeps one session and gives each request a child session (`db.request`).

The memory contract is ris's (`~/contribute/ris1/doc/reference/iyi/source/SPEC.md`).
ris owns memory safety, block lifetimes and cleanup; Ricord adds database
behavior. The design is [doc/DESIGN.md](doc/DESIGN.md); where the code does not
yet meet a rule, the design's "As built" notes say so.

Cite a rule by its number, for example RICORD_SPEC 3.2. Numbers never change:
new rules go last in their section; a removed rule keeps its number with
"(removed)".

## 1. Session lifetime and ownership

* 1.1 A session owns the query state, binds, records, validation errors,
  loaded associations and SQL log made through it. A web server gives each
  request its own child session, not one per keep-alive connection.
* 1.2 The session stays alive until its block ends. Code that writes a
  response from records does so inside the block. `db.release` ends the read
  transaction before a slow step without ending the session.
* 1.3 When the block ends, the session frees its store at once. Early
  returns, returned errors and panic follow ris's block-exit rules.
* 1.4 Helpers and queries use the caller's session. They open no session of
  their own.
* 1.5 Jobs, commands and tests open a session the same way. Ricord does not
  depend on an HTTP context.
* 1.6 A session's end is a memory boundary, not a transaction. Ending it does
  not undo committed writes. Writes commit at the end of `db.write`.
* 1.7 A long session keeps what it reads until it ends. `each` reads in
  batches with a fresh store per batch, and `request` gives each request a
  fresh store; these are the bounded-memory tools.

## 2. Storage and persistent resources

* 2.1 Records live flat in the session's store: columns in arrays, text as
  spans into one buffer. Reads, writes, validation, callbacks and query
  building need no garbage collector.
* 2.2 Runtime text uses `String`. Collections use `Array`. SQL binds are an
  `Array(DBValue)` built for the statement.
* 2.3 Text read from a record is a view into the store. Ricord exposes no
  raw pointer to records, query text, binds or values.
* 2.4 A session owns one connection for its block; records refer to their
  session. There is no pool and no global connection registry.
* 2.5 Nothing that outlives a session keeps a borrow from it. Model metadata
  is static and built at compile time.
* 2.6 Ricord keeps no cache beyond a session's store.
* 2.7 Each growing part obeys ris's stable-storage rules. The store's arrays
  are flat; records do not nest arrays of records.
* 2.8 Closing the connection is explicit and happens when the session's block
  ends, before its storage is freed.

## 3. Models, records and identity

* 3.1 `model Name do ... end` declares columns (`col`), indexes, associations,
  validations and callbacks. Applications do not inherit from a base class.
* 3.2 A record is a handle: its session and an index into the store. Writes
  change the store in place.
* 3.3 Copying or passing a record keeps its identity. A change through one
  copy is seen through the others.
* 3.4 Two queries for the same row return two records. Ricord has no identity
  map. Primary-key equality and record identity are different things.
* 3.5 Text getters return `String`, or `String?` for nullable columns.
  Integer, float, boolean, time and JSON columns keep their declared types.
  Binary columns keep their bytes.
* 3.6 A record stays valid after its result set closes, until its session
  ends. It borrows no cursor, statement or driver buffer.
* 3.7 Records track new, persisted and destroyed state, changed columns and
  the values last saved. Loading and reloading set that baseline; a
  successful write moves it.
* 3.8 (removed) Ricord has no record duplication.
* 3.9 Associations are kept as indexes in the store, not as nested records,
  so a record's shape is never recursive.

## 4. Queries and results

* 4.1 Queries start at `Model[db]` and offer `where`, `or_where`, `order`,
  `limit`, `offset`, `joins`, `distinct`, `includes`, `find`, `find_by`,
  `first`, `last`, `count`, `exists?`, `pluck`, `pick`, `to_a`, `each`,
  `update_all`, `delete_all` and `destroy_all`. There are no parallel
  variants of one operation.
* 4.2 Queries are lazy. Building one sends no SQL; a terminal method runs it.
* 4.3 Chaining makes a new query. The query it came from keeps its own
  conditions. There are no in-place mutators.
* 4.4 `to_a` returns `Array(Model)`. `pluck(:col)` returns
  `Array(Ricord::Plucked)`; `pluck(:col, into: array)` converts into the
  caller's element type.
* 4.5 Plucked text is a view into the session's store and stays valid until
  the session ends. `pick` returns one value of the same shape as `pluck`.
* 4.6 A missing optional result is `nil`; an empty array is a valid result.
  Database and decoding failures are errors, never empty results.
* 4.7 A mistake found while building a query (an unknown association, a
  nullable order column for `each`) is returned by the terminal method.
* 4.8 Values are bound parameters. Identifier quoting belongs to the
  dialect; the query API never puts user values into SQL text.
* 4.9 `each` gives a record valid for one batch. The compiler refuses to keep
  it past the batch.
* 4.10 `each` closes its cursor at the end, on early exit and on error. A
  record holds no cursor.

## 5. Writes, errors and transactions

* 5.1 Failures are structs returned as union members: `RecordNotFound`,
  `RecordInvalid`, `ScopeError`, `CallbackError`, `DatabaseError`,
  `AfterCommitError`, `Rollback`. Nothing raises.
* 5.2 One method per action. `find`, `save`, `create`, `update` and `destroy`
  return their value or an error. Callers check the error or unwrap with
  `.or_panic`; no name ends in `!`.
* 5.3 A validation failure is the error `RecordInvalid`, with the messages on
  `record.errors`. There is no separate strict form.
* 5.4 Validation messages, dirty tracking, timestamps and callbacks use the
  session's store.
* 5.5 A write sets the new id and persisted state only after the database
  operation succeeds.
* 5.6 `db.write do |tx| ... end` runs one transaction (`BEGIN IMMEDIATE`) on
  the session's connection. Everything in the block takes part, for every
  model.
* 5.7 The block commits when it ends. `tx.roll_back` returns `Rollback` and
  rolls back. A failed commit is returned as an error.
* 5.8 A write inside a write is a savepoint. An inner block never commits the
  outer one.
* 5.9 A rollback restores the records' persisted state, id and baseline to
  what they were when the write began. Attempted values stay for inspection
  and count as changed.
* 5.10 After-commit work is a flat queue of (model, id, method) items in the
  session. Items run after the outermost commit, each in its own write;
  `after_rollback` items run after a rollback. A savepoint commits nothing.
* 5.11 The queue holds ids, not records. An item reads its record again by
  id. Queueing starts no background work.
* 5.12 An after-commit failure cannot undo the commit. The other items still
  run, and `write` returns `AfterCommitError`.
* 5.13 Panic or an abandoned write rolls back. A connection in an unknown
  transaction state is closed, not reused.
* 5.14 HTTP status does not decide a transaction's outcome. An app commits
  before it answers that a write succeeded.

## 6. Associations and serialization

* 6.1 `belongs_to`, `has_one` and `has_many` keep their Active Record meaning.
  Associated records live in the same session.
* 6.2 An association reads through its record's session. A `belongs_to` or
  `has_one` read loads the whole group the record was read with in one
  query; `includes` does so for `has_many`.
* 6.3 Changing a foreign key or reloading drops the loaded association. An
  unloaded association and a loaded empty one are different.
* 6.4 `dependent: :destroy`, `:delete_all` and `:nullify` run inside the
  parent's destroy write. Their failures are returned.
* 6.5 `to_json` writes into a caller's `String::Builder`.
* 6.6 JSON output tells NULL from empty text and keeps scalar types.
* 6.7 Serialization does not follow associations.
* 6.8 A response is written inside the session's block, after `db.release`.

## 7. Retention and concurrency

* 7.1 A record, query or plucked value cannot outlive its session. ris's
  checks refuse it at compile time.
* 7.2 What leaves a session is a value the caller owns: a number, a `String`,
  a tuple of those, or ids appended into the caller's array.
* 7.3 Keeping an id is how an app refers to a record after its session.
* 7.4 Ricord does not copy record graphs out of a session.
* 7.5 Ricord has no `to_heap` or `from_heap`.
* 7.6 Sessions share nothing. Each worker opens its own session, with its own
  connection.
* 7.7 Tasks obey ris's group and Share rules. Records are not sent through
  channels.
* 7.8 Background work opens its own session and reads its own records. Pass
  it ids.
* 7.9 The SQL log (`log: true`) belongs to the session and ends with it.
* 7.10 Long reads use `each`; a long-lived worker uses `request` per unit of
  work.

## 8. Engines and verification

* 8.1 SQLite and Turso give the same results, errors and ownership. Dialect
  differences are runtime branches in `ricord/dialects`.
* 8.2 Drivers decode into the session's store. A driver buffer is read only
  while the driver keeps it valid.
* 8.3 A session's connection closes after its result sets and statements are
  cleaned up and its transaction is resolved.
* 8.4 libsqlite3 and libturso own their memory; Ricord's records stay in the
  store.
* 8.5 Every database test runs on both engines (`RICORD_ENGINE=sqlite` and
  `turso`). An engine limit is an explicit error or a reported pending check,
  never a silently skipped assertion.
* 8.6 Compile-fail fixtures (`test/refused/`) cover records leaving a
  session or a batch.
* 8.7 Functional tests cover CRUD, NULLs, projections, independent queries,
  shared handles, associations, scope, validation and serialization.
* 8.8 Resource tests cover results after cursor close, rollback, nested
  writes and after-commit timing.
* 8.9 Repeated-request tests check that memory does not grow with the number
  of requests (`test/memory_test.ri`).
* 8.10 Request workloads run without a garbage collector.
* 8.11 Acceptance depends on behavior and resource correctness, not speed.
  Language gaps stay listed as gaps; they do not weaken this contract.

## 9. Public declarations and compatibility

* 9.1 Keep Active Record vocabulary where ris allows it. Changes are listed
  with before-and-after examples in `doc/API_CHANGES.md`.
* 9.2 Follow `doc/NAMING.md`: one method per action, no `!` in names,
  `_in_place` for mutation, and aliases for ris keywords.
* 9.3 One public operation has one contract.
* 9.4 Declarations keep the familiar table, column, association, validation
  and callback ideas, in a syntax that ris can check.

A model declaration has this shape:

```text
model User do
  table :users
  col :name, :string
  col :team_id, belongs_to: :team, null: true
  validates :name, presence: true
end
```

The session's block holds all use of its records:

```text
Ricord.open("sqlite3:app.db") do |db|
  body = String::Builder.new
  User[db].order(:name).each { |user| body << user.name << '\n'; nil }.or_panic
  db.release
  # send body here, before the block ends
end
```
