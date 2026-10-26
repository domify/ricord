# Grant on ris tape

Grant is an ORM for ris. Its usual unit of work is a web request: read input,
query and change records, build a response, send it, then release the request's
tape. Records and temporary data need no individual collection.

The memory contract is [ris TAPE_SPEC](../../rispure/TAPE_SPEC.md).
References such as TAPE_SPEC 1.5 name its numbered rules. ris owns memory
safety, task lifetimes and cleanup semantics; Grant adds database behavior.
This is the target contract, not a claim that the current implementation
already meets every rule.

Cite a Grant rule by its number, for example RIS_GRANT_SPEC 3.2. Numbers
never change: new rules go last in their section; removed numbers stay unused.

## 1. Request lifetime and ownership

* 1.1 A request owns the input, query state, binds, decoded records, validation
  errors, loaded associations and response data created for it. The server
  establishes an owning scope per request, not per keep-alive connection.
* 1.2 The owner remains alive through response transmission, joined request
  tasks and resource cleanup. Returning from a controller does not release
  data still borrowed by a response writer.
* 1.3 On completion, the request releases its owned regions together. Early
  returns, returned errors, cancellation and panic follow ris's exit rules
  (TAPE_SPEC 1.1, 4.1). Fatal termination has ris's stated cleanup limits.
* 1.4 Grant uses the caller's tape. Helpers and ordinary queries do not create
  independent tapes. Nested `tape` blocks share the caller's owner; they do
  not reclaim each method's temporary allocations (TAPE_SPEC 1.5).
* 1.5 Jobs, commands and tests establish the same kind of work lifetime.
  Grant does not depend on HTTP context or create an HTTP request implicitly.
* 1.6 Request lifetime is a memory boundary, not a database transaction.
  Completing a request releases memory; it does not undo committed writes.
  Applications choose transaction boundaries explicitly.
* 1.7 A long-running request retains its allocations until their owning
  scopes end. Batch APIs provide separate scratch lifetimes where needed;
  nested shared `tape` blocks are not a bounded-memory batching mechanism.

## 2. Storage and persistent resources

* 2.1 Grant uses static data, scoped tapes and typed pools. General heap
  allocation and GC are not required by reads, writes, record identity,
  validation, callbacks, query construction or serialization.
* 2.2 Runtime text uses `Str`. Collections use `Ary`, fixed views or typed
  pools as their shape requires. SQL parameters do not pass through heap
  `String` or `Array` copies.
* 2.3 Read-only input borrows `Str`; generated text goes directly into a
  caller's builder or onto the caller's tape. Grant exposes no raw pointer
  interface for records, query text, binds or decoded values.
* 2.4 Configuration and model metadata have program or application lifetime.
  Database pools and physical connections have explicit service owners;
  a request borrows a connection lease, never ownership of the pool.
* 2.5 Persistent resources retain no request borrows. Prepared statements,
  schema metadata and other retained data are built on their destination
  owner or copied there explicitly.
* 2.6 Persistent caches have explicit bounds, invalidation and reclamation.
  Copying every request's data to `Program.tape` is not a cache policy.
  Request-local query caches end with their request.
* 2.7 Each growing component obeys ris's stable-storage rules. Runtime-sized
  collections of growing components use `SlicePool` or fixed views, not
  nested `Ary` values (TAPE_SPEC 2.2).
* 2.8 Pool reuse does not close files, sockets, statements or transactions.
  Resource cleanup is explicit and precedes storage release
  (TAPE_SPEC 6.5).

## 3. Models, records and identity

* 3.1 Model declarations describe columns, keys, associations, validations
  and callbacks. They generate tape-native records and model operations;
  applications do not inherit from `Grant::Base`.
* 3.2 A public record is an `@[OnTape]` value referring to its mutable state.
  Its backing state and any identity-bearing class instances live on the
  same work owner. Writes do not require promotion to a heap record.
* 3.3 Assigning or passing a record preserves its handle identity. Field
  changes, dirty state, errors and association-cache changes made through
  one alias are visible through the others.
* 3.4 Independent queries for the same database row return independent
  handles. Grant has no automatic identity map. Database primary-key
  equality and in-memory handle identity are distinct.
* 3.5 Text column readers return `Str`, or `Str?` for nullable columns.
  Numeric, boolean, timestamp and UUID columns retain their declared
  scalar types. Binary fields preserve their bytes without text decoding.
* 3.6 Hydrated records remain valid after their result set closes and their
  connection returns to the pool. A record borrows no reusable cursor,
  statement or connection buffer.
* 3.7 Records track new, persisted and destroyed state, changed attributes
  and the persisted baseline needed by writes. Loading and reloading
  establish baselines; successful writes advance them.
* 3.8 Record duplication is an explicit model operation with Grant's
  documented key and persistence semantics. Assignment is not duplication;
  `copy_to` is not a database clone operation.
* 3.9 Association caches must not force recursively embedded model graphs.
  Internal tables, handles and indices may represent relationships on the
  owner without making a record's value shape infinitely recursive.

## 4. Queries and results

* 4.1 Preserve Grant's public operations where ris permits them: `where`,
  `order`, `limit`, `offset`, `find`, `first`, `pluck`, `pick`, `ids`,
  `count`, `exists?`, `save`, `create`, `update` and `destroy`.
  Do not add parallel tape variants such as `pluck_tape`.
* 4.2 Relations are lazy. Building a relation performs no database query.
  A terminal operation executes it using the selected runtime adapter.
* 4.3 Chaining produces an independent relation. Its mutable clause storage
  must not alias storage that a later mutation can change in the source
  relation. Explicit mutators use the `_in_place` suffix.
* 4.4 Materialized model collections return `Ary(Model)`. Scalar projections
  return scalar collections; multi-column projections return fixed-width
  row values or fixed pooled runs. Neither requires `Ary(Ary(Value))`.
* 4.5 Projection values contain tape-native scalars and text. Their storage
  remains valid independently of cursor stepping and result-set closure.
  `pick` uses the same row shape as the corresponding `pluck`.
* 4.6 Missing optional results return `Nil`; empty collections are valid
  results. Database and decoding failures remain errors, not empty results
  or missing records.
* 4.7 Chain-time errors may be deferred until execution. A terminal operation
  returns the deferred error without issuing SQL.
* 4.8 Values use bound parameters. Identifier quoting and placeholder syntax
  belong to the adapter; the query API does not interpolate user values
  into SQL.
* 4.9 Batch iteration has explicit batch ownership. A batch's records cannot
  escape its scratch lifetime or be appended by borrow to an outer result.
  Retained output is constructed on its destination or copied explicitly.
* 4.10 Streaming and batch APIs close cursors on completion, early termination
  and error. A live cursor may retain a connection lease; materialized
  records do not.

## 5. Writes, errors and transactions

* 5.1 Operational failures implement `Error` and are returned as union
  members. Database failures, invalid arguments, validation failures and
  cancellation retain distinguishable meanings.
* 5.2 Failing strict methods use `_strict`, including `find_strict`,
  `save_strict` and `create_strict`. Callers propagate with postfix `!`
  or deliberately unwrap with `.or_panic`; declarations have no trailing `!`.
* 5.3 Ordinary save and update operations may report validation rejection
  with `false` and errors on the record. Operational failures remain error
  values. Strict variants return a validation error on rejection.
* 5.4 Validation messages, dirty tracking, timestamps and write callbacks
  use the work owner. Validation does not silently cross a heap boundary
  for regular expressions, formatting or error construction.
* 5.5 Writes publish generated keys and successful persistence state only
  after the corresponding database operation succeeds. A failed write does
  not mark its attempted values as successfully persisted.
* 5.6 `transaction` pins one connection for its block. All operations using
  that connection participate, including operations on other models.
  Transactions on different connections are independent.
* 5.7 A normal block result commits; an `Error` result rolls back.
  `Rollback` itself implements `Error` and remains an explicit result.
  A failed commit is returned as an error, never reported as success.
* 5.8 Nested transactions follow Grant's documented join and savepoint
  behavior. A nested block must not accidentally commit its outer
  transaction. Adapter differences remain explicit runtime behavior.
* 5.9 Rollback restores enrolled records' persistence flags, generated
  identity and persisted baselines to their transaction-entry state.
  Attempted field values remain available for inspection or retry and
  are dirty relative to the restored baseline.
* 5.10 Lifecycle callbacks run within the work lifetime. `after_commit`
  runs after the outer commit succeeds; `after_rollback` runs after the
  applicable rollback. Savepoints do not publish an outer commit.
* 5.11 Deferred transaction callbacks may borrow records only while their
  owner remains alive. Callback registration does not create background
  work or retain a record beyond its request.
* 5.12 An `after_commit` failure cannot undo the committed transaction.
  Grant reports the callback failure without claiming the write rolled
  back or automatically replaying the committed work.
* 5.13 Cancellation, panic and abandoned transaction scopes initiate rollback
  and release their leases. A connection whose transaction or protocol
  state cannot be recovered is discarded rather than reused.
* 5.14 HTTP status and socket success do not decide transaction outcomes.
  Applications commit required writes before publishing a response that
  promises those writes succeeded.

## 6. Associations and serialization

* 6.1 Preserve `belongs_to`, `has_one` and `has_many` semantics. Associated
  records and collection results use the same work owner as their caller.
* 6.2 Lazy association loads require a live work scope. Preloading resolves
  associations before traversal without retaining driver resources.
  Loaded association state is shared through the record handle.
* 6.3 Foreign-key changes and reload invalidate affected cached associations.
  An unloaded association and a loaded empty association are distinct.
* 6.4 Dependent destroy, delete and nullify operations retain their declared
  callback and transaction behavior. Their failures are returned; they are
  not hidden by releasing tape storage.
* 6.5 Serialization writes fields directly into a caller's builder or
  supported output writer. A convenience result may be a `Str` on the
  caller's tape; an intermediate heap document is not required.
* 6.6 Serialization distinguishes database NULL from empty text and preserves
  scalar types. Public output applies declared codecs and propagates their
  errors; raw encrypted storage is not emitted as decoded application data.
* 6.7 Recursive associations are serialized only through an explicit finite
  projection. Serialization does not implicitly traverse the entire loaded
  relationship graph.
* 6.8 A response writer may borrow records until its final write completes.
  Socket submission alone is insufficient if the transport still retains
  the submitted bytes.

## 7. Retention and concurrency

* 7.1 A record, relation, error or response view cannot outlive its roots.
  Grant relies on ris's checked provenance, not runtime conventions that
  merely ask applications to avoid stale references (TAPE_SPEC 3.1-3.4).
* 7.2 Prefer building retained output directly on its destination owner.
  Otherwise use `copy_to(owner)` for supported data shapes. It deep-copies
  data, splits sharing and runs no constructors or callbacks
  (TAPE_SPEC 1.7).
* 7.3 `copy_to` is not persistence, attachment to a new connection or
  preservation of record identity. Retained application data should usually
  be an ID or an explicit acyclic snapshot.
* 7.4 Unsupported cyclic or self-reaching record graphs are not copied by
  bypassing ris's checks. Project their needed fields, retain keys, or
  construct an indexed representation on the destination owner.
* 7.5 Grant defines no required `to_heap` or `from_heap` lifecycle. Legacy
  conversion APIs are migration facilities, not the storage model.
* 7.6 Concurrent requests share no mutable request-owned data. Connection
  pools coordinate exclusive leases without storing request borrows in
  global or thread-local state.
* 7.7 Tasks obey ris's group and Share rules. Grant does not send mutable
  record handles, `Ary` values or request tape borrows through channels
  (TAPE_SPEC 5.1-5.3).
* 7.8 Background work has its own lifetime and obtains its own records.
  Transfer supported independent values or persist a job description;
  a closure capturing a request record is not a background job payload.
* 7.9 Logging and instrumentation consume borrowed data synchronously or
  retain an explicit supported copy. They must not keep request SQL,
  parameter views, records or errors after the owner ends.
* 7.10 Long-lived streams establish bounded work units. Resetting scratch
  while a response or application holder still borrows it is forbidden;
  retaining every batch until a stream closes is not bounded processing.

## 8. Adapters and verification

* 8.1 SQLite and PostgreSQL implement the same public ownership, result and
  error contracts. SQL dialect, locking and capability checks remain
  runtime adapter branches.
* 8.2 Drivers decode into caller-owned storage. Reusable native or protocol
  buffers may be borrowed only within their proven lifetime; copy bytes
  to the work owner before advancing, resetting or releasing that storage.
* 8.3 Connection return happens after result sets and statements are cleaned
  up and transaction state is resolved. A later request must not observe
  the previous request's binds, transaction context or callbacks.
* 8.4 External library resources have explicit ownership and cleanup.
  Required foreign allocations are distinguished from Grant's record
  storage; an FFI boundary does not authorize general heap fallback.
* 8.5 Every database behavior test runs under both `CURRENT_ADAPTER=sqlite`
  and `CURRENT_ADAPTER=pg`. Adapter limitations produce explicit supported
  behavior or errors, not silently skipped assertions.
* 8.6 Lifetime checks cover escaping records and errors, invalid batch
  retention, captured request borrows and supported destination copies.
  Unsafe shapes are rejected with the corresponding safe form.
* 8.7 Functional checks cover CRUD, NULL values, typed projections,
  independent relation chains, handle aliasing, association invalidation,
  validation, codecs and serialization.
* 8.8 Resource checks cover results surviving cursor closure, connection
  reuse, returned-error rollback, nested transactions, callback timing,
  cancellation, panic and client disconnect.
* 8.9 Repeated-request checks include keep-alive and concurrent requests.
  Released request storage must not accumulate with total request count.
  Runtime mapping caches are distinguished from live retained data.
* 8.10 Supported request workloads are checked without general heap or GC.
  `RIS_TAPE_STATS` helps inspect ownership, retained regions and copying;
  correct decoding copies are not mislabeled as forbidden allocations.
* 8.11 Acceptance depends on behavior and resource correctness, not a
  throughput target. Language and runtime gaps remain explicit gaps;
  they do not weaken this contract.

## 9. Public declarations and compatibility

* 9.1 Keep Grant's vocabulary where the tape permits it. Necessary changes
  describe what an application updates, with before-and-after examples in
  `doc/API_CHANGES.md` when the implementation changes.
* 9.2 Follow `doc/NAMING.md`: strict failures use `_strict`, mutation uses
  `_in_place`, and reserved words receive documented aliases such as
  `import_records`, `group_records`, `and_where` and `or_where`.
* 9.3 One public operation has one storage contract. Tape-native behavior
  replaces its old internals rather than adding a second public ORM beside
  the first.
* 9.4 Model declarations retain familiar table, column, association,
  validation and callback concepts. Declaration syntax serves ris's
  type and ownership checks; Crystal's inheritance and macro expansion
  structure are not requirements.

A model declaration has this shape:

```ris
model User do
  connection sqlite
  table users
  column id : Int64, primary: true
  column name : Str
  validates_presence_of :name
end
```

The request's owning scope contains its complete use of the returned records:

```ris
tape do
  users = User.where(active: true).order(:name).to_a.or_panic
  body = Str::Builder.new

  users.each do |user|
    body << user.name << '\n'
  end

  # Finish sending body before this owner is released.
end
```

In a web server the request boundary supplies this scope. Rendering, transaction
blocks and helper calls borrow it. A transaction may end before the request;
the records remain usable until their memory owner ends.
