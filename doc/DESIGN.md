# Ricord: an ORM for ris

*   **Author:** Priit Tark
*   **Status:** Proposed (revised after the EGM review, stages 5-7)
*   **Date:** 2026-11-06
*   **Decision record:** [BRAINSTORM.md](BRAINSTORM.md) holds the brainstorm, the goldfish
    findings and every decision cited below as "rejected by author".

--------------------------------------------------------------------------------

## Overview

Ricord is an ActiveRecord-style ORM for ris. It replaces Grant in this repository. Grant is the
Crystal ORM whose port to ris this repository held until now.

The current ris compiler has no heap and no garbage collector. Data lives on tapes that are freed
when the block owning them ends, and a database connection belongs to the block and the task that
opened it. Ricord keeps the model declarations of ActiveRecord (`col`, `has_many`, validations,
callbacks, `where`/`order` chains) and passes the database session explicitly where a query
starts:

```ris
Ricord.open("file:./data/accounts/42.db") do |db|
  account = Account[db].find(42)!
  court = account.courts.create(name: "Harju")!
  court.name = "Harju maakohus"
  court.save!                     # the record knows its session
end
```

A postfix `!` returns an error from the enclosing function (iyi III.1.2). It is never part of a
method name. `save!` above is `save` followed by that operator, not a Rails bang method.

Ricord supports two in-process engines from the start: SQLite (the default) and Turso, a Rust
rewrite of SQLite that reads its file format, SQL dialect and C API. The first user is the port of a Rails 8
application (ct-ruby, 107 models) to ris, which plans one database file per customer account.

| Milestone | Delivers |
|---|---|
| M0 | old Grant tagged and removed, project renamed, compiler and packages pinned, probes |
| M1 | session, store, `Model[db]`, CRUD, write transactions, errors, `create_sql`, statement log |
| M2 | validations, callbacks, dirty tracking, timestamps, after-commit queue, `json_field` |
| M3 | associations, scope inheritance, group loading, `includes`, `dependent:` |
| M4 | batched `each`, `pluck`, bulk writes, joins, request scope, memory checks |
| M5 | example web app, guide, API changes, contract rewrite |

## The Problem

Grant does not build today. `main` (code last changed in `012c71b3`) requires db v0.1.1; db v0.2
removed connection pools and made connections block-scoped, and v0.3.1, the version used now,
only changed `ResultSet#read_tape`. So `grant/adapter/pool_support.ri` fails on the missing
`Db::Core::StringKeyCache`. Behind that first error there are three deeper mismatches with the
new compiler:

1.  **Grant assumes a heap.**
    *   **Where:** about 25,000 of Grant's 29,000 lines are `Grant::Base`, a port of Rails' model
        class. It keeps connection pools, global registries, per-class caches and `after_commit`
        lists that hold records.
    *   **Why it breaks:** a value cannot outlive the block that made it (SPEC 1.1, 3.2), and a
        task cannot share mutable state with another (SPEC 5.1).
    *   **Where else:** the newer tape model (`grant/tape_model.ri`) still copies rows to the heap
        (`to_heap`, `User::Data`) and binds SQL arguments from heap arrays.
2.  **Grant finds its connection through global state.**
    *   **How today:** `User.find(1)` looks up a connection by name in a global registry
        (`Grant::Connections`).
    *   **Why it breaks:** a db v0.3 connection exists only inside
        `Db.open(uri) { |conn| ... }`, and the compiler refuses to store it anywhere that
        outlives that block. A model call must be handed the connection.
3.  **Text from a row is short-lived.** db reads text that is valid only inside the
    `query { |rs| }` block. A record that lives for a whole request must copy its column text into
    storage the session owns. Today's tape model returns rows out of the query block without such
    a copy (`load_all`). This was not checked further: `grant/tape_model.ri` is deleted in M0 and `ricord/model.ri` replaces it in M1.

The user's side of the problem has two parts.

*   **The first user cannot move yet.** Porting ct-ruby needs an ORM that builds on the current
    compiler and keeps the Rails model style its 107 models are written in.
*   **Account isolation leaked rows in Rails.** ct-ruby used `activerecord-multi-tenant`. It keeps
    the account scope in global state, and in practice the scope was missing from harder SQL
    (joins, subqueries, raw SQL). The new design must not repeat that.

## Goals

*   **Builds on today's stack.** Ricord builds and its tests pass on the compiler commit recorded in
    `.ris-version`, with db v0.3.1 and the ris sqlite driver, which links libsqlite3 and a renamed static libturso
    into one binary.
    No `replace`
    line points at an unpinned checkout without a recorded version.
*   **The session API, in this form:**
    *   `Ricord.open(uri) { |db| ... }` opens a session on one connection.
    *   A query or a create starts by naming the session: `User[db].find(1)`,
        `User[db].where(active: true)`, `User[db].create(name: "Ann")`. A write transaction
        works the same way: `User[tx].create(...)`.
    *   A record holds its session, so `record.save`, `record.destroy` and association readers take
        no connection argument.
    *   `db.write { |tx| ... }` runs several writes in one `BEGIN IMMEDIATE` transaction. A lone
        `save` opens and commits its own.
*   **One method per action; errors are returned values.** `find` returns `RecordNotFound` when
    the row is missing, as in Rails; `find_by` and `first` return `nil`. `save`, `create` and
    `update` return `RecordInvalid` when validation fails. There are no `_strict` variants.
*   **Model declarations, one way to write each:**
    *   **One column:** `col :name, :type, **options`, in ActiveRecord's schema vocabulary. This
        follows the author's earlier `doc/RAILS-DSL.md` on the `native-iyi` branch.
        *   Types: `:primary`, `:integer`, `:bigint`, `:string`, `:text`, `:boolean`, `:float`,
            `:date`, `:datetime`, `:timestamp`, `:json`, `:binary`. `:decimal` is accepted by the
            parser and refused with a compile error until `Ricord::Decimal` exists (see Column
            types).
        *   Options: `null:`, `default:`, `limit:`, `precision:`, `scale:`, `collation:`.
        *   Getter types follow `null:` and `default:`: with `null: false` and a default the
            property is not nilable; otherwise it is nilable.
    *   **A reference column:** `col :account_id, belongs_to: :account` declares the column, its
        index (`index: false` drops it), the foreign key (`on_delete:`, `to_table:`) and the reader
        `court.account`.
    *   **A bundle of columns that always go together:** `cols :timestamps` declares `created_at`
        and `updated_at`, which a save sets. Later bundles such as `cols :userstamps` are added
        when a port needs them.
    *   **Associations without a column here:** `has_many`, `has_one`, `dependent:`.
    *   **Table-level declarations:** `table`, `index`, `foreign_key`, `check_constraint`.
    *   **Validations:** presence, length, format, inclusion, custom `validate`.
    *   **Callbacks:** method-named `before_`/`after_` for validation, save, create, update and
        destroy, and the Rails after-commit names: `after_commit`, `after_create_commit`,
        `after_update_commit`, `after_save_commit`, `after_destroy_commit`, `after_rollback`.
*   **Tables from models.** `Model::SCHEMA.create_sql` produces `CREATE TABLE` with columns,
    indexes, foreign keys and checks. Tests and new account files use it. Changing an existing
    table (`ALTER`) belongs to the later migrations.
*   **Queries:** `find`, `find_by`, `where` (equality, nil, arrays, ranges, raw SQL with binds),
    `or_where`, `order`, `limit`, `offset`, `first`, `count`, `exists?`, `pluck`, `create`,
    `update`, `update_all`, `delete_all`, `destroy_all`, `includes`. A `where` on a name that is
    not a column fails at compile time.
*   **Defined record lifetime.** The guide states who owns a record's bytes, when they are freed,
    what `each` yields, and how values leave a session. Tests prove that text read in one batch
    stays correct while that batch is used, and that returning a record out of `open` fails to
    compile.
*   **Scope inherited through associations.** A record reached through `account.courts` keeps its
    parent. Its associations, `create` and bulk writes stay inside that account, and joins built by
    the query builder add the parent condition to each joined table that has the key column.
    Changing a scoped column returns `Ricord::ScopeError`.
*   **No N+1 queries for single-record associations.** Records read by one query (or one `each`
    batch) form a load group. Reading a `belongs_to` or `has_one` association on one of them loads
    it for the whole group with one `IN (...)` query, as Ruby's `goldiloader` gem does. `has_many`
    is preloaded with `includes`.
*   **Bounded memory for large reads.** `each` reads in batches, and each batch's records, group
    and preloads are freed when the batch ends. A test measures memory over 10,000 rows.
*   **One complete example.** `examples/tape_web` runs one resource (index, show, create, update,
    destroy) on the session API.
*   **Visible API changes.** `doc/API_CHANGES.md` lists every removed or changed API with its
    replacement. The last commit with `Grant::Base` carries the tag `grant-base-final`.

## Non-Goals

*   **`Grant::Base` and its Rails surface:** connection pools, sharding, replicas, encryption,
    async queries, the health monitor, connection registries, query cache, counter caches, STI.
    Deleted, not ported.
*   **PostgreSQL, for now.** v1 runs on SQLite and Turso. PostgreSQL and its row-level security
    come later. The dialect interface
    keeps room for both.
*   **Migrations.** `create_sql` makes new tables; altering tables, and running changes over many
    account files, come later.
*   **Background jobs.** A job package with the ActiveJob API is planned separately (see Future
    Improvements). Ricord v1 only runs after-commit callbacks in the same process.
*   **Later model features:** typed `includes`, `has_many :through`, nested attributes,
    polymorphic associations, group loading for `has_many`, `save(db: other)`/`copy(db: other)`,
    `Ricord::Decimal`.
*   **Records that outlive one session block.** They cannot, by design. Values that must live
    longer leave as plain values (see the appendix).
*   **A `tenant` keyword or any global scope.** Account isolation is one database file per
    account, chosen by the application. Inside a file, scope comes from associations.
*   **Isolating accounts inside one shared database file.** Temporary views and
    `sqlite3_set_authorizer` are not built.
*   **Compiler changes beyond prelude gaps.** Small missing prelude methods may be added in ris1,
    ris2 or ris3. New language rules (a module visibility rule, a `using` context parameter,
    compiler plugins) are not part of this work.

## Open Questions

*   **Does the ris sqlite driver work against libturso?** Turso v0.8.3's `COMPAT.md` and
    `bindings/c` show that `sqlite3_create_function` (called on every open, for REGEXP),
    `sqlite3_bind_zeroblob` and `sqlite3_db_mutex` are not exported. M0 changes the driver to skip
    them on libturso (REGEXP is built into Turso); the M0 probe then runs the driver's operations.
    If more is missing, the Turso CI job stays non-blocking and SQLite carries v1.
*   **Are Turso's `numeric(P,S)` and `BEGIN CONCURRENT` usable?** Both are experimental. Ricord v1
    does not depend on them; the M0 probe records their state.
*   **Can ris's `std/json` hold a parsed document on the tape inside a store?** The M0 probe
    settles it before `:json` getters are built.
*   **Can the after-commit queue call a model method through a non-capturing proc?** The M0 probe
    settles it. Fallback: an application list `Ricord.models(Court, Room)` from which the macro
    builds the dispatch `case`.
*   **How are ct-ruby's `multi_tenant` call sites found?** This is for the port, not for Ricord.
    Each `Court.find(id)` that relied on the global scope becomes `account.courts.find(id)` or a
    query on the account's own file. 88 models use `multi_tenant :account`.

## Glossary

*   **ris, iyi:** ris is the compiler this targets (`~/contribute/ris`). It is iyi (a statically
    typed language derived from Crystal, specified in `doc/reference/iyi/source/SPEC.md`) plus
    tape memory. "SPEC n.m" cites ris's `SPEC.md`; "iyi X" cites iyi's spec.
*   **Tape:** the memory a block, def or loop round allocates in. It is freed when that scope ends
    (SPEC 1.1). There is no heap.
*   **Owner:** a class with a growing field (`Array`, a builder). It must be built as a named local
    (`x = T.new`), cannot be subclassed and ends with its declaring scope (SPEC 2.1).
*   **`@[OnTape]`:** marks a struct that holds tape values. It can be stored only where it cannot
    outlive its sources (SPEC 3.2).
*   **Round:** one pass of a loop or block; its scratch is freed at its end.
*   **`Program.tape`:** the tape that lives as long as the program.
*   **ris1, ris2, ris3:** compiler checkouts where prelude fixes are made; `~/contribute/ris` is
    not changed.
*   **`DBValue`, `DBError`:** db's value union for binds and results, and its flat error struct
    (at most 240 message bytes).
*   **`String::Builder`, `String::Span`:** a growing text buffer, and a (start, length) pair that
    names a slice of it. `builder.to_s[span]` is a view of those bytes, not a copy.
*   **SPEC rules cited:** 1.1 every scope frees its scratch; 1.5 a fresh result moves to the
    caller in one move; 1.9 a result that would need copying out is refused; 2.1 owners; 2.2 no
    runtime-sized collection of growing values; 3.2 a store must not outlive its source; 3.6 a
    scope that may keep scratch is a compile error; 5.1 tasks share only Share values and use their
    own resources; 5.2 RisBoard copies messages between tasks.
*   **`RIS_TAPE_STATS`:** a runtime switch that prints tape use, for memory tests.
*   **minitest:** the 32-core build server used for long test runs.
*   **EGM, goldfish:** the Elephant-Goldfish review process; goldfish are reviewers with no prior
    context.

## Critical User Journeys (CUJs)

### CUJ 1: A request reads and changes records

*   **Given**:
    *   A web worker opened `Ricord.open(global_uri) { |global| ... }` once, in its
        `with_handler`.
    *   An account's database file holds that account's courts.
*   **When**:
    *   A request runs inside `global.request { |g| ... }` and opens the account file with
        `Ricord.open(account_uri) { |db| ... }`.
    *   It reads `court = Court[db].find(court_id)!`, sets `court.name = "Uus"` and calls
        `court.save!`.
    *   It writes the page from `court.name`.
*   **Then**:
    *   **The read:** the first read opens a shared read transaction on the account file.
    *   **The write:** the save ends that read transaction with `COMMIT`, then runs
        `BEGIN IMMEDIATE`, the `UPDATE` and `COMMIT`.
    *   **The page:** it contains the new name.
    *   **When the blocks end:** the account file's connection closes, and the request's records
        and strings on both sessions are freed. The worker's global connection stays open.

### CUJ 2: No N+1 queries for an owner

*   **Given**: A page lists 50 courts with their account.
*   **When**: The handler iterates `Court[db].each { |c| c.account!.name }`, with no `includes`.
*   **Then**: Two queries run: one reads the courts, and on the first `c.account` one reads the
    accounts of all 50.

### CUJ 3: Several writes, and after-commit work

*   **Given**: `model Room do after_create_commit :notify_members end`.
*   **When**: The code runs `db.write { |tx| ... }`, creating a room with
    `Room[tx].create(name: "Üldine")!` and adding three memberships.
*   **Then**:
    *   **Atomicity:** all four rows commit together.
    *   **After COMMIT:** Ricord reads the room again by id in a new write (the method may write)
        and calls `notify_members`.
    *   **On an error inside the block:** the block's result is that error, nothing is written,
        and `notify_members` does not run.
    *   **If `notify_members` fails:** the rows stay committed, and `db.write` returns
        `Ricord::AfterCommitError` with the room's id and the error.

### CUJ 4: Atomic destroy

*   **Given**: An account with courts, `has_many :courts, dependent: :destroy`.
*   **When**: The code runs `account.destroy!`, and a `before_destroy` callback on one court
    returns an error.
*   **Then**: The whole destroy rolls back, no row is deleted, and the call returns that error.

### CUJ 5: Reading many rows with bounded memory

*   **Given**: A table with 10,000 rows.
*   **When**: A job runs `User[db].order(:email).each { |u| report << u.email }`.
*   **Then**:
    *   **Paging:** rows come in batches of 1,000 by keyset on `(email, id)`.
    *   **Memory:** each batch's records and text are freed when the batch ends, so memory does
        not grow with the row count.
    *   **Escape:** code that keeps `u` past its batch fails to compile.

### CUJ 6: Data from one database into another

*   **Given**: A user in `global.db` and an account file.
*   **When**: The code reads `user = User[global].find(1)!`, runs
    `Membership[account_db].create(user_id: user.id)!`, then `user.save!`.
*   **Then**: The membership is written to the account file, and the save writes to `global.db`,
    where the user came from. The two writes are separate transactions, and no foreign key can
    check the cross-file reference.

### CUJ 7: Values leave a session

*   **Given**: A job needs a count and some user names after its session block ends.
*   **When**:
    *   It does the work that needs records inside the block.
    *   It returns a single value from the block:
        `count = Ricord.open(uri) { |db| User[db].count! }`.
    *   For a list, it fills a caller-owned array:
        `ids = Array(Int64).new; Ricord.open(uri) { |db| ids.concat(User[db].pluck(:id)!) }`.
*   **Then**: The count and the ids are usable after the block. Returning a record, or assigning
    a block-made array to an outer variable, fails to compile.

## Technical Plan (Architecture)

### Origin

*   **The core comes from Campfire.** The session, write transaction and after-commit core follows
    `once-campfire-rust/crates/db/src/database.rs` and its ris port
    `once-campfire-ris/rils/record/database.ri`: a write is an explicit `BEGIN IMMEDIATE`
    transaction with a queue of flat after-commit items, and a request's reads share one read
    transaction.
*   **The declarations come from Grant's tape model and the `col` spec.** `model ... do`, columns,
    associations, validations and callbacks sit on top of that core.

### Layers

```text
 application code
   │  model Court do col ... has_many ... after_create_commit ... end   (ricord/model.ri)
   ▼
 Court (generated record handle)        Court::Query (generated, @[OnTape])
   │  save / destroy / associations          │ where / order / includes / find
   ▼                                         ▼
 Ricord::Session ── Ricord::Tx (a write) ── after-commit queue
   │ conn : Db::Core::Connection (reference)
   │ store : Ricord::Store (owner: flat record storage)
   │ write depth, savepoint counter, reading flag, statement log
   ▼
 Ricord::Sql + Ricord::Sqlite | Ricord::Turso  (SQL text, quoting, RETURNING, times, pragmas)
   ▼
 db v0.3.1  ─►  ris sqlite driver  ─►  sqlite3:// → libsqlite3,  turso:// → libturso (turso_*)
```

### Verified constraints

Probes run while drafting (manual runs, scratch files; M0 turns them into tests under
`test/probe/`) and facts read from the sources:

*   **Row text in a store.** `store.values << rs.read(String)!` is refused (SPEC 1.1, 3.6);
    `copy_to(store)` fails because `copy_to` supports only `Program.tape` as owner today ("other
    owner kinds are added separately" in the ris source). What works: one `String::Builder` per
    store, and a `String::Span` per value built from numbers after `store.text << value`.
*   **Records are structs.** `class Court < Base` with `macro inherited`/`macro finished` builds,
    but a class instance made in the row loop cannot be appended to the result. An `@[OnTape]`
    struct holding a session reference and an index can.
*   **Mixins do not cross files.** `include Ricord::Model` works in one file only: iyi modules are
    compilation units, and `pub` cannot apply to a module.
*   **Values leaving a block.** A number, a `String` (a store view or a fresh one) and a tuple
    return from a session block; a block-made `Array` assigned to an outer variable is refused;
    `outer.concat(block_array)` of `Int64` values works.
*   **Names.** `in:` works as a named argument and `in`/`on` as method names, but `db:`-style
    arguments were dropped for `Model[db]`. `User(db)` cannot parse (a capitalized name is a type,
    and `T(...)` is a generic). `with ... yield` is not supported (iyi SPEC IV.2).
*   **db's `Connection` is not an owner** (only an `Options` struct and two `Bool`s), so a session
    can hold a reference to it. Bind arguments are `Array(DBValue)`, a tape type.
*   **db has savepoints** (`Transaction#transaction`, one nested level at a time). Ricord issues
    its own savepoint SQL instead (see Writes).
*   **web does not start a task per request.** `Server.serve` starts a fixed number of worker
    tasks; each calls `Factory.with_handler(config)` once and serves requests in turn
    (`web/server.ri:120-160`). A worker can open a connection in `with_handler` and keep it.

### Session and opening

*   **`Ricord.open(uri, log = false) { |db| ... }`:**
    *   It adds the pragmas `journal_mode=wal`, `busy_timeout=5000` and `foreign_keys=on` to the
        URI unless the URI sets them. Without them a writer blocks readers, a lock fails at once,
        and `on_delete:` does nothing.
    *   It calls `Db.open(uri) { |conn| ... }`, declares `store = Ricord::Store.new` as a named
        local, builds a `Ricord::Session` holding references to both, and yields it.
    *   It returns the block's value or a `Ricord::Error`.
*   **Lifetime:** the connection, the store, every record and every copied string end with the
    block. The compiler refuses any of them escaping (SPEC 3.2).
*   **In a web app:** a worker opens the global database once in `with_handler`. An account file
    is opened per request; on Turso and SQLite that is a file open plus the pragmas.

### Reads and the request scope

*   **`session.request { |db| ... }`** gives a child session on the same connection with a fresh
    store, freed when the request ends. Records read on a long-lived session outside `request`
    pile up in its store, so long-lived sessions are used only through `request`.
*   **Shared read transaction:** the first read in a request runs `BEGIN` (deferred), and later
    reads share it, so they see one snapshot and take the WAL read lock once. The session's
    `reading` flag tracks it.
*   **Before a write:** `save`, `create`, `destroy` and `db.write` first end the read transaction
    with `COMMIT`. The next read opens a new one, with a newer snapshot.
*   **Before waiting:** `request` ends the read transaction when its block ends, and the web
    adapter calls `db.release` before writing the response, so an app calls `release` only before
    its own external I/O. With `log: true`, a read transaction held longer than 100 ms is logged at
    warn level with the statements it covered.
*   **A transaction left open:** `request` first rolls back a transaction that a panicked request
    left open on the connection, as Campfire's `enter` does.
*   **A session without `request`** (the per-request account file) uses the same rules for its
    own reads.

### Writes and transactions

*   **`db.write { |tx| ... }`:**
    *   It runs `BEGIN IMMEDIATE` and yields a `Ricord::Tx`, an `@[OnTape]` struct holding the
        session and an `in_transaction` flag.
    *   On success it runs `COMMIT`, then the after-commit queue.
    *   A block result that is a `Ricord::Error`, a call to `tx.roll_back`, or an early exit runs
        `ROLLBACK` (through `defer`) and drops the queue's new items.
    *   A panicked write leaves its transaction open; the next write rolls it back first.
*   **Nesting:** a `db.write` inside a write runs `SAVEPOINT ricord_<n>` and `RELEASE` or
    `ROLLBACK TO`. The session keeps a write depth (how deep the nesting is) and a savepoint
    counter (a name suffix that only grows). Ricord issues this SQL itself through `conn.exec`:
    db's `Transaction` objects live only inside their block and allow one nested level.
*   **`Model[tx]`** works like `Model[db]` inside a write. `record.save` joins the open write on
    its session if there is one.
*   **`save`:**
    1.  Run `before_validation`, the validations and `after_validation`.
    2.  Stop and return `Ricord::RecordInvalid` when the errors are not empty; the messages stay
        on `record.errors`.
    3.  Open a write or savepoint.
    4.  Run `before_save`, then `before_create` or `before_update`.
    5.  Write the row. `INSERT ... RETURNING id` sets the key.
    6.  Run `after_create` or `after_update`, then `after_save`.
    7.  Queue the after-commit items.
    8.  Release the savepoint or commit.

    A callback that returns a `Ricord::Error` rolls that level back. `create` and `update` follow
    the same steps.

### After-commit queue

*   **Declarations:** `after_commit :m, on: :create | :update | :destroy`, and the Rails short
    forms `after_create_commit`, `after_update_commit`, `after_save_commit`,
    `after_destroy_commit`. `after_rollback :m` runs when the transaction rolls back.
*   **What is queued:** a flat `Ricord::CommitItem`: the model id, the record's key, the kind and
    the method index. It holds no record and no closure, as Campfire's `CommitAction` does.
*   **Running it:** after `COMMIT`, Ricord runs every item in order, each in its own write. For
    create and update it reads the record again by key and calls the instance method. For destroy
    the record is gone, so the method is a class method that receives the key:
    `def self.cleanup_files(db : Ricord::Tx, id : Int64)`, since each item runs in its own write.
*   **Dispatch:** the macro generates `self.__after_commit(tx, key, method)` per model, and the
    item holds a non-capturing proc to it. An M0 probe checks that ris allows this; the fallback
    is an application list `Ricord.models(...)` from which the macro builds the dispatch `case`.
*   **Nesting:** items queued by after-commit work run in the same drain, up to a depth of 8.
*   **Errors:** every item runs even if an earlier one failed, and each error is logged. The
    write (or the lone `save`) then returns `Ricord::AfterCommitError`, which holds the record id
    and the first error, so the caller can tell that the data was committed.
*   **On rollback:** `after_rollback` methods run after the outermost `ROLLBACK`, outside any
    write, once per queued item, in queue order; then the items are dropped. A `ROLLBACK TO` (a
    nested write) only drops the items queued at that level. Like `after_destroy_commit`, an
    `after_rollback` method is a class method `def self.m(db : Ricord::Session, id : Int64 | Nil)`:
    the row may not exist, and `id` is nil for a rolled-back create.
*   **Durability:** the queue lives in memory. A crash between COMMIT and the run loses the work;
    work that must survive goes through the planned job package.

### Record storage: flat, in the store

*   **The rule this follows:** a runtime-sized collection of growing values is refused
    (SPEC 2.2), so records are not objects with their own arrays.
*   **What the store keeps:** one `Ricord::Store` (an owner class) per session, request scope or
    `each` batch:
    *   `values : Array(Value)`, where `Value` is
        `Nil | Bool | Int64 | Float64 | Time | String::Span`. Each record takes `columns.size`
        consecutive slots; text, json and binary slots hold a span.
    *   `text : String::Builder`, the bytes of every text value, one after another.
    *   `changed : Array(Bool)`, the same layout, for dirty marks.
    *   `flags : Array(UInt8)`, one per record: persisted, destroyed, loaded marks.
    *   `scopes : Array(Int32)`, one per record: its inherited scope, or -1.
    *   `groups : Array(Int32)`, one per record: the query or batch that read it.
    *   `links : Array(Int32)` and `link_ranges : Array(Int32)`: loaded associations as index
        lists.
    *   `scope_pairs`: the inherited scopes' `(column, value)` pairs, which `scopes` indexes.
    *   `errors : Array(ErrorEntry)`: validation messages tagged with the record index.
*   **What a record is:** `Court` is a generated `@[OnTape]` struct holding its session, its store
    and its index. A copy of the handle is an alias; there is no identity map.
*   **Getters** read the slots. A text getter returns `store.text.to_s[span]`, a view.
    **Setters** write the slot and set the changed mark; a text setter appends the new text to
    `store.text` and replaces the span, so old bytes stay until the store ends. This is accepted:
    a store lives for one request or one batch.
*   **Rows** are read inside `conn.query { |rs| }`. Each text column is appended to `store.text`
    and its slot gets `String::Span.new(start, bytesize)`.

### Column types

| `col` type | Getter type | Stored in the slot | SQL (SQLite and Turso) |
|---|---|---|---|
| `:integer`, `:bigint`, `:primary` | `Int64` | `Int64` | `INTEGER` / `BIGINT` |
| `:boolean` | `Bool` | `Bool` | `BOOLEAN` (0/1) |
| `:float` | `Float64` | `Float64` | `REAL` |
| `:string`, `:text` | `String` | span | `VARCHAR(n)` / `TEXT` |
| `:date`, `:datetime`, `:timestamp` | `Time` | `Time` | ISO text in UTC |
| `:json` | `Ricord::Json` | span | `TEXT` |
| `:binary` | `Ricord::Blob` | span | `BLOB` |
| `:decimal` | compile error until `Ricord::Decimal` exists | — | `numeric(P,S)` later |

*   **`:json`:** `Ricord::Json` parses on read with `std/json` and returns values by key:
    `account.settings[:theme]` and `account.settings["theme"]` are the same. `json_field
    :settings, :theme, :string, default: "auto"` (M2) adds a typed accessor `account.theme`.
*   **`:binary`:** `Ricord::Blob` wraps the span with `bytesize`, `byte_at`, `each_byte` and
    `write_to(io)`. It is not a `String`, so printing it as text is a compile error.
*   **`:decimal`:** money in ct-ruby is `:bigint` cents, so v1 needs no decimal column. A
    fixed-size `Ricord::Decimal` (an `Int128` and a scale, about 38 digits) comes with a separate
    decimal package; Turso then stores it as `numeric(P,S)` and SQLite as exact text.

### Streaming

*   **`to_a` and `first`** load into the session's or request's store.
*   **`each`** pages in batches of `batch_size` (a tunable default of 1,000) by keyset on the
    order columns plus the primary key: the next batch runs `WHERE (name, id) > (last_name,
    last_id)`. Each batch has its own store holding the records, their load group and their
    preloads, freed when the batch ends. `limit` caps the total; `offset` with `each` is a compile
    error. A large ordered `each` wants an index on `(order columns, id)`.

### Queries

*   **Entry:** `Court[db]` (a session) or `Court[tx]` (a write) returns a `Court::Query` bound to
    it; the macro generates `self.[]` on each model. A query from a record (`account.courts`)
    already has its session.
*   **State:** the session, `wheres : Array(String)`, `binds : Array(DBValue)`, order, limit,
    offset, includes and the inherited scope. Each chained call returns a new query.
*   **SQL text:** `Ricord::Sql` builds it through the dialect. Values always go to SQL as bound
    parameters in the query API; a raw SQL fragment passed to `where` is the caller's
    responsibility.

### Scope inherited through associations

*   **What a scope is:** a list of `(column, value)` pairs. `account.courts` starts with
    `[(account_id, 42)]`.
*   **What inherits it:** records loaded through such a query keep the scope. Their associations
    add the pairs whose column exists in the target table; `create`, `build` and `update` set those
    columns; `update_all`, `delete_all` and `destroy_all` add them to `WHERE`; builder joins and
    subqueries add them per joined table.
*   **Changing a scoped column** (setting `account_id` on a record scoped to account 42) returns
    `Ricord::ScopeError` on save. With one file per account, moving a record to another account
    is a copy into another file, not an `UPDATE`.
*   **Raw SQL** in `where("...")` gets the scope on the main table only. `doc/GUIDE.md`, section
    "Isolation", says so; isolation between accounts comes from the file per account.

### Associations and group loading

*   **`belongs_to` and `has_one`:** `court.account` returns `Account | Nil | DatabaseError`. When
    the association is loaded it returns from the store; otherwise it loads it for the record's
    whole load group with one `IN (...)` query, then returns. A record found alone (`find`) is a
    group of one.
*   **`has_many`:** `account.courts` returns a `Court::Query`. `includes(:courts)` preloads the
    children of every owner with one `IN (...)` query; without `includes`, each owner's
    `courts.to_a` runs its own query.
*   **`dependent:`:** `:destroy` destroys the children in batches inside the destroy's write;
    `:delete_all` issues one `DELETE`; `:nullify` one `UPDATE`.

### Schema and `create_sql`

*   The macro builds `Model::SCHEMA` at compile time: each column (type, null, default, limit,
    precision, scale, collation), indexes, foreign keys and checks.
*   `SCHEMA.create_sql` returns the `CREATE TABLE` and `CREATE INDEX` statements through the
    dialect. Tests and new account files use it; `ALTER` is left to migrations.

### Errors

*   **Types:** each failure is its own flat struct implementing ris's `Error` trait, with a
    short message (limit in M1). `case` tells them apart, and `!` propagates any of them.

    | Error | Returned by |
    |---|---|
    | `Ricord::RecordNotFound` | `find` |
    | `Ricord::RecordInvalid` | `save`, `create`, `update` |
    | `Ricord::ScopeError` | a save that changed a scoped column |
    | `Ricord::CallbackError` | a callback that refused |
    | `Ricord::AfterCommitError` | a write whose after-commit work failed after COMMIT |
    | `Ricord::DatabaseError` | a `DBError` from the driver |
    | `Ricord::Rollback` | `tx.roll_back` |

    `Ricord::Error` is the union of all of them.
*   **Return types:**

    | Call | Returns |
    |---|---|
    | `find(1)` | `Court`, `RecordNotFound` or `DatabaseError` |
    | `find_by(...)`, `first` | `Court`, `Nil` or `DatabaseError` |
    | `save`, `update(...)` | `Nil` or a save error (below) |
    | `create(...)` | `Court` or a save error |
    | `destroy` | `Nil`, `CallbackError`, `AfterCommitError` or `DatabaseError` |

    Save errors: `RecordInvalid`, `ScopeError`, `CallbackError`, `AfterCommitError`,
    `DatabaseError`.
*   **Validation messages:** `record.errors` reads the store's entries for that record, apart from
    the error value.

### Dialect

*   **The interface:** `Ricord::Dialect` covers `quote_ident`, `placeholder(n)`,
    `insert_returning`, `limit_offset`, `keyset_after`, `write_time`, `read_time`, `begin_write`,
    `pragmas`, `column_sql(type, options)` and `translate(DBError)`.
*   **`Ricord::Sqlite`** is the default, for `sqlite3://` URIs. It uses the ris sqlite driver's
    libsqlite3 binding, `"` quoting, `?` placeholders, `RETURNING`, `BEGIN IMMEDIATE`, times as
    text in UTC.
    `create_sql` never emits `WITHOUT ROWID` (insert-only and experimental on Turso).
*   **`Ricord::Turso`** is a thin layer over `Ricord::Sqlite` for `turso://` URIs, served by
    libturso (pinned at v0.8.3). Turso-only features (`BEGIN CONCURRENT`, change data capture) are
    added here later.
    `BEGIN CONCURRENT` and `numeric(P,S)` are recorded by the M0 probe and not used in v1.
*   **The engine is chosen per URI, at run time.** `Ricord.open("sqlite3://global.db")` uses
    `Ricord::Sqlite`; `Ricord.open("turso://acct_42.db")` uses `Ricord::Turso`. One application
    can use both at once, for example the global database on SQLite and account files on Turso.
*   **How both fit in one binary:** libturso exports the same `sqlite3_*` names as libsqlite3.
    `bin/build-turso` builds libturso as a static library and renames its symbols to `turso_*`
    (`objcopy --redefine-syms`). The sqlite driver has two bindings generated by one macro,
    `LibSQLite3` (`@[Link("sqlite3")]`) and `LibTurso` (`@[Link("turso")]`, `turso_` prefix),
    and registers two db schemes, `sqlite3` and `turso`. `LibTurso` omits the three calls
    libturso lacks: `create_function` (REGEXP is built in), `bind_zeroblob` and `db_mutex`.
*   **Tests:** `RICORD_ENGINE=sqlite|turso` picks the URI scheme the test suite opens; CI runs
    every test on both, and one test opens both engines in one program.

### Logging

*   `Ricord.open(uri, log: true)` writes each statement and its duration to db's `LOG` at debug
    level, and tests read the same log to check SQL text and query counts. With no pool, this is
    the one place for SQL logging.

### Compiler and package pin

*   `.ris-version` records the ris checkout and commit; `bin/test` refuses another compiler
    unless `RIS_ANY=1` is set.
*   `ris.mod` requires db v0.3.1 and the sqlite driver at its current version; the driver links
    libsqlite3 from the system path and the renamed static libturso from `vendor/turso/lib`
    through `IYI_LIBRARY_PATH`.
*   `test/probe/` holds small programs that `bin/test` runs first, so a compiler change that
    breaks an assumption fails there.

## Alternatives Considered

Decisions marked "rejected by author" are recorded in [BRAINSTORM.md](BRAINSTORM.md).

### Alternative A: Port all of Grant::Base

*   **Pros**: Keeps the whole Rails surface and the 357 existing tests.
*   **Cons**: The 25,000 lines of `Grant::Base` rest on pools, global registries and
    `after_commit` lists holding records, which SPEC 1.1, 3.2 and 5.1 refuse.
*   **Reason for Rejection**: Rejected by author: most of it cannot be written under the memory
    rules, and what can has no user yet.

### Alternative B: Move Grant::Base to `legacy/` instead of deleting it

*   **Pros**: The code stays in the tree.
*   **Cons**: It never builds on the new compiler; its tests would fail, and searches would hit
    dead code.
*   **Reason for Rejection**: Rejected by author after review: the tag `grant-base-final` keeps
    the history.

### Alternative C: A connection that `User.find(1)` finds without an argument

Three forms were weighed:
1.  **Each call opens its own connection.** Legal today, but `User.find` and `user.save` run on
    different connections, so transactions break.
2.  **One connection on `Program.tape`.** Legal from the main task only (SPEC 5.1, 5.6).
3.  **A task-scoped implicit context in the compiler** (a hidden parameter bound for a block).
    The only form with no argument at all, but a new language rule of unknown cost.

*   **Reason for Rejection**: Rejected by author: 1 breaks transactions, 2 ties the app to one
    task, 3 is a compiler change. A `using` context can be added later without rewriting Ricord.

### Alternative D: Other entry forms

Weighed: `db.users.find(1)` with a `database AppDb do models ... end` declaration;
`User.find(1, db: db)` with `in:`, `on:`, `using:` or `in_db:` as the argument name;
`User.in(db)`; `db[User]`; `User.find(1).in(db)`; `with ... yield`.
*   **Pros**: `db.users` reads like Entity Framework; `User.in(db)` reads as English.
*   **Cons**: `db.users` needs a second declaration; `in:`, `on:` and `using:` are SQL keywords;
    `User.find(1).in(db)` makes `find` lazy; `with ... yield` is not supported (iyi SPEC IV.2).
*   **Reason for Rejection**: Rejected by author in favour of `User[db]`: short, model first, no
    list of models, and the same form for a write (`User[tx]`). A reader who knows Sequel may read
    `User[...]` as a lookup by key; in ris that cannot compile by mistake.

### Alternative E: A `tenant` keyword with a scope set for the session

*   **Pros**: Close to `activerecord-multi-tenant` and `acts_as_tenant`.
*   **Cons**: The scope lives apart from the query, the pattern that leaked rows; it misses raw
    SQL; users in several accounts do not fit one tenant column.
*   **Reason for Rejection**: Rejected by author: isolation comes from one file per account, and
    scope from associations.

### Alternative F: Restrict `Model[db]` at compile time

Weighed: a type split (`db.all_tenants.courts`), a ris visibility rule (`@[Visible(admin)]`,
like Rust's `pub(in path)`), and compiler plugins.
*   **Pros**: The compiler, not discipline, would stop a cross-account read.
*   **Cons**: Each needs a language change or adds a word to admin code.
*   **Reason for Rejection**: Rejected by author for now: with a file per account, a session sees
    one account.

### Alternative G: PostgreSQL first, with row-level security

*   **Pros**: Exact `numeric`, MVCC, `jsonb`, row-level security, `LISTEN`/`NOTIFY`; the pg
    driver is ported; ct-ruby runs on it today.
*   **Cons**: A server to run; one connection per worker removes the connect cost but not the
    operations work.
*   **Reason for Rejection**: Rejected by author: an in-process engine needs no server.

### Alternative H: SQLite first

*   **Pros**: Stable and widely tested; the ris driver passes its tests; Litestream and the
    `sqlite3` tools work. ct-ruby's money is `:bigint`, so SQLite's inexact `DECIMAL` does not
    matter.
*   **Cons**: One writer per file, no exact decimal, no change data capture.
*   **Reason for Rejection**: Superseded by Alternative R2: SQLite is the default engine, but not
    the only one.

### Alternative R1: Turso as the only first engine

*   **Pros**: `BEGIN CONCURRENT` (MVCC, no longer experimental in v0.8) and change data capture
    are available from the start; one engine to test.
*   **Cons**: v1 uses neither feature; Turso is pre-1.0 and releases every few weeks; the driver
    needs changes before it links; a Turso problem would block M1-M4.
*   **Reason for Rejection**: The cost comes before any v1 feature needs it.

### Alternative R2: Both engines, SQLite by default (chosen)

*   **Pros**: Development does not wait on Turso; Turso is tested from M1, so switching the
    default later is a link setting, not a port.
*   **Cons**: Every test runs twice; the Turso build chain is maintained.
*   **Reason for Rejection**: Chosen.

### Alternative I: Records as objects that own their values

*   **Pros**: Simple to read.
*   **Cons**: A runtime-sized collection of values that each own an `Array` is refused (SPEC 2.2).
*   **Reason for Rejection**: The compiler refuses the form.

### Alternative J: db's `Transaction` objects for nesting

*   **Pros**: Reuses db's code.
*   **Cons**: A `Transaction` exists only inside its block, and db allows one nested level.
*   **Reason for Rejection**: Ricord issues the savepoint SQL itself with a depth counter.

### Alternative K: Code after the transaction block, or an outbox table, instead of a queue

*   **Pros**: Code after the block needs no mechanism; an outbox survives a crash.
*   **Cons**: Code after the block is not tied to the model; an outbox needs a table, a worker and
    idempotent handlers.
*   **Reason for Rejection**: Rejected by author: the flat queue, as both Campfire ports do it.
    Durable work goes to the job package.

### Alternative L: A `durable: true` after-commit option

*   **Pros**: One option on the callback makes the work survive a crash.
*   **Cons**: It is a job system hidden in a callback option.
*   **Reason for Rejection**: Rejected by author in favour of a job package with the ActiveJob API
    (`perform_later` writes the job row in the same transaction).

### Alternative M: Typed `includes`

*   **Pros**: A preloaded association reads without an error case.
*   **Cons**: Generic types multiply per model and include set, and the loaded type has no name
    to write in a signature.
*   **Reason for Rejection**: Rejected for now, after review: group loading removes N+1 queries
    without a type change.

### Alternative N: Strict loading, or lazy loading per record

Weighed: a `NotLoaded` error (Rails `strict_loading`); a query per record (Rails' default); a
query per record plus a log warning (`bullet`); a mode chosen per query.
*   **Pros**: The error shows N+1 at once; a query per record needs no preload logic.
*   **Cons**: The error makes every page remember `includes`; 50 records cost 51 queries.
*   **Reason for Rejection**: Rejected by author in favour of group loading.

### Alternative O: Campfire's explicit form everywhere

`Room::find(conn, id)`, `Room::create(tx, ...)`, `message.destroy(tx)`, records as plain data.
*   **Pros**: Proven in both Campfire ports; a write outside a transaction cannot compile.
*   **Cons**: `record.save` and `record.association` are lost.
*   **Reason for Rejection**: Rejected by author: Campfire's core is taken, and records keep their
    session; a lone `save` opens its own write.

### Alternative P: `class Court < Ricord::Base`

*   **Pros**: ActiveRecord's shape, inheritance, `super`, one base type.
*   **Cons**: Probed: the class and its macros build, but a class instance made in the row loop
    cannot be kept in the result.
*   **Reason for Rejection**: The compiler refuses the form. It becomes possible if ris lets an
    instance be built on another owner's tape.

### Alternative Q: `@[OnTape] struct Court` with `include Ricord::Model`

*   **Pros**: A plain struct with macros from a mixin.
*   **Cons**: Probed: it works in one file only; iyi modules are compilation units, and `pub`
    cannot apply to a module.
*   **Reason for Rejection**: It does not cross the file boundary; `model Court do ... end` is an
    exported macro.

### Alternative R: Records owning slices from a store-owned SlicePool

*   **Pros**: SPEC 2.2 names `SlicePool` as the form for runtime-sized collections of growing
    values, so each record could own its values.
*   **Cons**: Not probed; one-pass row reading fits flat columns, and per-record slices add an
    allocation per row.
*   **Reason for Rejection**: Not weighed in depth; flat columns are kept. A probe may revisit it.

## Risks and Mitigations

Each risk: what can go wrong, its impact, and the mitigation or acceptance.

*   **libturso lacks C API calls the driver uses:** the Turso build fails. Known gaps are skipped
    in M0; the Turso CI job is non-blocking until M4, and SQLite carries v1.
*   **Turso changes quickly (pre-1.0):** an update breaks tests. The pin to v0.8.3; updates are
    deliberate.
*   **Turso's nested-write rollback differs:** a failed nested write may force the whole write
    to roll back. Probe 11 checks it; `write_test` runs on both engines and records the gap.
*   **Account files written by Turso:** `sqlite3` tools and Litestream may not read them once
    `numeric` or MVCC is used. v1 uses neither; the M0 probe checks that libsqlite3 reads a file
    Turso wrote.
*   **A panicked write leaves its transaction open:** the next write fails. The next write and
    `request` roll it back first.
*   **A read transaction is held while a request waits:** the WAL grows and writers wait.
    `request` ends it, the web adapter releases before the response, and a long hold is logged.
*   **The store grows when a record's text is rewritten:** more memory per request. Accepted: a
    store lives one request or one batch.
*   **Raw SQL is scoped on the main table only:** a raw join can read other rows of the same file.
    Accepted: other accounts are in other files.
*   **Write contention on one account file:** writers wait. WAL and `busy_timeout=5000`.
*   **Many account files:** descriptors and open cost slow requests. One open per request,
    measured in M4.
*   **Schema drift across account files:** old files miss columns. Accepted until migrations.
*   **A crash between COMMIT and after-commit work:** the work is lost. Accepted; durable work goes
    to the job package.
*   **A long `dependent: :destroy`:** the write lock is held. Use `:delete_all` for large trees.
*   **Cross-file references:** no foreign key checks them. Accepted and documented.
*   **The compiler changes under the pin:** tests fail after a bump. `.ris-version`; probes run
    first.

## Non-Functional Requirements

*   **Memory:** a request's records, strings and query state live in its store and end with it. A
    worker's memory must not grow with the number of requests it has served (RIS_GRANT_SPEC 8.9:
    released request storage must not accumulate). `each` is bounded by its batch size.
*   **Security:** the query API binds every value; the dialect quotes identifiers. Isolation
    between accounts is the file per account, chosen by the application from the authenticated
    account; scope through associations is a convenience inside one file.
*   **Concurrency:** writes use `BEGIN IMMEDIATE`, so two tasks writing one file wait on the lock
    (`busy_timeout`) instead of failing halfway. A connection is used only by the task that opened
    it.
*   **Rollout:** ct-ruby has only demo users, so there is no data migration risk. The old Grant
    stays at the tag `grant-base-final`.

## Additional Resources

*   [BRAINSTORM.md](BRAINSTORM.md): brainstorm, goldfish findings, decisions.
*   [RIS_GRANT_SPEC.md](../RIS_GRANT_SPEC.md): the contract, rewritten in M5.
*   `~/contribute/ris/SPEC.md`, `doc/TAPE_API.md`, `doc/reference/iyi/source/SPEC.md`.
*   `../db/db/core.ri`, `../sqlite/sqlite/core.ri`, `../web/web/server.ri`.
*   `~/contribute/once-campfire-rust/crates/db/src/database.rs`,
    `~/contribute/once-campfire-ris/rils/record/database.ri`.
*   `doc/RAILS-DSL.md` on branch `native-iyi`: the earlier `col` specification.
*   Turso: data types and `create type` in the Turso docs (2026), and the July 2026 Register
    article on Turso's direction.

## Future Improvements

*   **A job package** with the ActiveJob API: `job ... do`, `perform_later`, `perform_now`,
    `set(wait:/wait_until:)`, `queue_as`, `retry_on`, `discard_on`. Records pass as model and id
    (GlobalID). `perform_later` writes the job row in the same transaction, in the account's file;
    a RisBoard message after COMMIT wakes the worker; a sweep at startup finds jobs whose message
    was lost. ct-ruby already does this on PostgreSQL: Solid Queue in the same database with
    `enqueue_after_transaction_commit = :never`.
*   **`track_changes`:** a Ricord-level change log written in the same transaction, from the dirty
    marks, with the account and the acting user. It would replace PaperTrail's `versions` and feed
    Turbo broadcasts (228 uses in ct-ruby). Turso's change data capture is an alternative base.
*   **`Ricord::Decimal`** from a fixed-size decimal package; `numeric(P,S)` on Turso.
*   **Writing across databases:** `save(db: other)`, `copy(db: other)`.
*   **Group loading for `has_many`.**
*   **A `using` context parameter** in ris, so `Court.find(1)` works inside `using db do ... end`.
*   **Turso as the default engine** once `BEGIN CONCURRENT` or change data capture is needed.
*   **`Ricord::Postgres`;** possibly through Turso's experimental Postgres frontend (formerly
    pgmicro) as well as a server; row-level security set by `Ricord.open(uri, account:)`.
*   **Migrations** that alter tables over many account files.
*   **Typed `includes`, `has_many :through`, nested attributes, polymorphic associations.**
*   **Restricting `Model[db]`** with a ris visibility rule.
*   **Detached records:** a caller-owned store whose records stay readable after the block.
*   **An `account_route` web helper** that opens an account's file and loads the account.

## Appendix: getting values out of a session

The rule is to do the work inside the block. When something must leave:

| Need | Form | Probe |
|---|---|---|
| one number, text or tuple | the block's result | `String` and numbers returned |
| a list of numbers | `ids.concat(Court[db].pluck(:id)!)` into an array made outside | works |
| a list of text | `Court[db].pluck(:name, into: buf, spans: spans)` | as the store |
| an export | `Court[db].to_json(into: io)` | same pattern |
| a one-shot tool | `value.copy_to(Program.tape)` | memory is never freed |
| a record | not possible | refused (SPEC 3.2) |

--------------------------------------------------------------------------------

## Detailed Implementation Plan

Paths are relative to the repository root. "Delete" means `git rm`.

### M0: baseline and probes

Goal: a clean tree on the pinned compiler, the old Grant tagged, the project renamed, and every
probe that later milestones rely on passing or recorded.

**As built (M0, 2026-11-07).** Where the code differs from the items below, the code wins:

*   The `turso:` scheme lives in the driver's own module `sqlite/turso` (`import
    sqlite/sqlite/turso`), not in `sqlite/core`; only a program that imports it links libturso.
    The lib block it instantiates is defined there and passed to the generic classes as a type
    argument, which ris allows.
*   The driver classes are `SQLite3ConnectionOf(L)` and so on, with `SQLite3Connection` etc. as
    libsqlite3 aliases. Lib types are `alias ... = Void*` (a generic class cannot name
    `L::Statement` in an ivar type). The FULL-only C calls that pass `"...\0".to_unsafe` sit in
    top-level helpers (`sqlite3_register_regexp`, `sqlite3_backup`), because macro-expanded code
    may not call `to_unsafe`. In the macro, `fun` is written `{{"fun".id}}` and names are passed
    as identifiers.
*   `libturso_sqlite3` already builds a static library; `bin/build-turso` uses `cargo build`.
*   Probe results: `dispatch=proc`; `numeric(P,S)` and `BEGIN CONCURRENT` refused on Turso;
    REGEXP equal on both engines. The `copy_to_other_store` fixture was dropped: `copy_to` into
    another owner fails with an undefined-method error, not a lifetime one, so it proves nothing.
*   CI checks the repository out as `ricord/` beside `db/`, `sqlite/` and `web/`.

#### 1. Tag `grant-base-final` (Create)

*   **Type / Scope**: Git tag.
*   **Proposed Changes**: Tag the parent of the M0 deletion commit as `grant-base-final`. It
    holds the whole `Grant::Base` stack (the last change to that code is `012c71b3`) plus this
    design, committed on its own just before. The module rename is part of the M0 commit. `doc/API_CHANGES.md` will cite it (M5 item 2).

#### 2. Rename the project to Ricord (Modify)

*   **Type / Scope**: Module name, directories.
*   **Proposed Changes**: `ris.mod` declares `module github.com/domify/ricord`; new code lives under
    `ricord/`; the root file is `ricord.ri`; the namespace is `Ricord::`. The README credits Grant,
    Campfire and Rails.

#### 3. `grant/**`, `grant.ri` (Delete)

*   **Type / Scope**: Library, 174 files and the root file.
*   **Proposed Changes**: Remove the `Grant::Base` stack, including `grant/tape_model.ri`, which
    imports `grant/adapter/*`. The tag keeps it as the reference for `ricord/model.ri`;
    `ricord.ri` (item 18) replaces `grant.ri`.

#### 4. `test/**` (Delete)

*   **Type / Scope**: every file under `test/` (`git ls-files test`; 357 at `grant-base-final`),
    including `test/spec_helper.ri` and the three tape tests, which import `grant/base`,
    `grant/errors` and `test/spec_helper`.
*   **Proposed Changes**: The files are deleted because they call the `Grant::Base` API, but
    their scenarios are ported, not dropped. Before the deletion, M0 writes `doc/TEST_PORT.md`:
    *   **Layout:** the first line is exactly `completed:` followed by the finished milestones
        (`completed: M1, M2`, empty after M0); then a blank line and this table, one row per
        old test file:

        ```
        completed:

        | file | verdict | target | milestone | reason | done |
        |---|---|---|---|---|---|
        | test/delete_test.ri | port | test/crud_test.ri | M1 | | |
        | test/adapter_pg_test.ri | drop | | | PostgreSQL only | |
        ```
    *   **Verdicts:** `port`, `defer` (feature in Future Improvements) or `drop` (PostgreSQL
        only, or covered elsewhere); `defer` and `drop` rows need a reason and are never checked.
    *   **Enforcement:** a milestone rewrites its `port` scenarios against the Ricord API and
        writes exactly `x` in `done`. `bin/test` fails when a `port` row whose milestone is on
        the `completed:` line has an empty `done`.

    The tag keeps the originals for reference. After M0, `bin/test` runs only `test/probe/` and
    `test/refused/`.

#### 5. `port/`, `doc/PORTING.md`, `docs/adapter_matrix.md`, `lib/`, `build/`, other examples (Delete)

*   **Proposed Changes**: These hold the Crystal port's journal (`git ls-files port`),
    the vendored Crystal shards (`lib/`), build output (`build/`, added to `.gitignore`) and
    every example except `examples/tape_web`. `grant-base-final` keeps the tracked files;
    untracked logs in `port/` are not kept. The `docs/` directory goes with its only file.
    `doc/BRAINSTORM.md` is kept (the design cites it). After the deletions, `grep -rn` over
    `AGENTS.md`, `README.md` and `doc/` finds no link to a deleted path.

#### 6. `crystal-upstream/` (Keep)

*   **Proposed Changes**: None; a read-only reference, as `AGENTS.md` says.

#### 7. `ris.mod` (Modify)

*   **Proposed Changes**: Require `github.com/domify/db v0.3.1 as db` (v0.1.1 at `grant-base-final`, `ris.mod:3`) and
    `github.com/domify/sqlite v0.2.0 as sqlite` (tagged by item 11a, which is done first); drop pg;
    keep `replace` lines to `../db` and `../sqlite` (db has the tag v0.3.1). db v0.3.1 opens
    with `::Db::Db.open(uri) { |conn| ... } : U | DBError` (`db/db/db.ri:37`, URI overload at
    `:43`); `Ricord.open` wraps it. Ricord is new code, so nothing written against v0.1.1 is
    carried over; the APIs it calls (`Db.open`, `query`, `exec`, `scalar`, `DBError`, `LOG`)
    are the v0.3.1 ones cited here. The example's `ris.mod` becomes, in full:

    ```
    module tape_web

    require github.com/domify/web v0.1.0 as web
    require github.com/domify/ricord v0.0.0 as ricord

    replace github.com/domify/web => ../../../web
    replace github.com/domify/ricord => ../..
    replace github.com/domify/db => ../../../db
    replace github.com/domify/sqlite => ../../../sqlite
    ```

    db and sqlite resolve through Ricord's own requires. `bin/test` skips `examples/` until M5.

#### 8. `.ris-version` (Create)

*   **Proposed Changes**: `key=value` lines: `ris_path=~/contribute/ris1` (ris1, ris2 or ris3,
    never `~/contribute/ris`), `ris_commit=<hash>`, `turso_version=v0.8.3`,
    `turso_commit=<hash of that tag>`, `turso_mode=static|single` (item 10), `dispatch=proc|models`
    (from probe 15). `bin/test` reads `ris_path` (with `File.expand_path` for `~`)
    and checks `ris_commit`; CI fetches `https://github.com/rislang/ris.git` at `ris_commit`
    (so that commit must be pushed there first) and keys its cache on `ris_commit`; it ignores
    `ris_path`.

#### 9. `bin/test` (Modify)

*   **Type / Scope**: Test runner (Ruby).
*   **Proposed Changes**:
    *   **Remove PostgreSQL:** the header comment (`bin/test:2`), `TEST_ADAPTERS` and
        `PG_SERVER_URL`/`pg_database` (`:12-14`), the reachability and `CREATE DATABASE` block
        (`:17-22`), the per-slot `CREATE DATABASE` (`:31-34`) and `PG_DATABASE_URL` (`:36`).
        One invocation runs one engine, chosen by `RICORD_ENGINE` (`sqlite` by default, or
        `turso`).
    *   **Compiler:** `RIS` defaults to `<ris_path>/bin/ris` from `.ris-version`, not the
        hard-coded `~/contribute/ris/bin/ris` (`:11`); `.ris-version` is checked unless
        `RIS_ANY=1`.
    *   **Also removed:** `SQLITE_DATABASE_URL` (slot 0 wrote `./grant_green.db` into the
        repository, `:37`), `CURRENT_ADAPTER` and the `adapters.each` loop (`:52-53`), the
        `[#{adapter}]` prefix and "x N adapters" summary (`:68`, `:76`), and the `PORT_JOBS`
        comment (`:24-25`).
    *   **Slots:** `TEST_JOBS` parallel slots stay, each with its own `TMPDIR`
        (`build/jobs/<n>`, slot 0 included). Each slot gets `RICORD_DATABASE_URL`: `sqlite3:<tmp>/ricord.db` or
        `turso://<tmp>/ricord.db`. `test/spec_helper.ri` opens that URL; there is no in-memory
        default.
    *   **Order:** `test/probe/*_test.ri` first, serially, each with `ris test --json` (probes
        are ordinary tests with `it` blocks); a failing probe stops the run. Each
        `test/refused/*.ri` is built with `ris build` (no run) and must exit non-zero with the
        text of its `# expect:` first line in its output. Then the tests (`test/*_test.ri`,
        the glob at `:16` without `**`); an empty set is allowed (M0 has none), so the
        "no tests selected" error (`:23`) goes. `ris test --json` has no per-test skip reason
        (`ris1/src/compiler/iyi/command/test.cr:186-192`), so nothing is skipped at run time:
        when `.ris-version` has `turso_mode=single`, `bin/test` leaves `test/two_engines_test.ri`
        out of the set and prints that it did. Then
        `ris fmt --check` and `ris check` on `ricord/` and `test/`, then the `TEST_PORT.md`
        check (item 4).
    *   **Libraries:** `vendor/turso/lib` is prepended to `IYI_LIBRARY_PATH` (the only place
        this is done; item 11a refers here).

#### 10. `vendor/turso.md` and `bin/build-turso` (Create)

*   **Type / Scope**: Build script and notes.
*   **Proposed Changes**: `bin/build-turso`:
    1.  Check out tag v0.8.3 into `vendor/turso/src` (ignored by git) and build with the Rust
        toolchain named in its `rust-toolchain.toml`.
    2.  Build the C bindings as a static library: `cargo rustc -p turso_sqlite3 --release
        --crate-type staticlib` (no change to upstream `Cargo.toml`; the script first checks
        that `cargo metadata` lists the package `turso_sqlite3` and stops with that message
        if not); the output is
        `vendor/turso/src/target/release/libturso_sqlite3.a`.
    3.  Make the rename map from the library itself:
        `nm --defined-only libturso_sqlite3.a | awk '$3 ~ /^sqlite3_/ {print $3, "turso_" substr($3,9)}' > turso.syms`
        (every defined class: text, data and read-only, e.g. `sqlite3_version`).
    4.  `objcopy --redefine-syms=turso.syms` into `vendor/turso/lib/libturso.a`, then check that
        `nm libturso.a` shows no `sqlite3_` symbol, defined or undefined (`nm -u`), and fail
        otherwise.
    5.  Write the `turso_*` lines of `.ris-version`.

    The Rust standard library inside the archive needs `-lpthread -ldl -lm`. ris adds only a
    `Link` annotation's `ldflags` and library name (`lib_flags_posix`, `link.cr:151-182`), and it
    emits an annotation's `ldflags` before its `-l<name>`. With a static archive the system
    libraries must follow `-lturso`, so `LibTurso` carries two annotations, `@[Link("turso")]`
    and `@[Link(ldflags: "-lpthread -ldl -lm")]`, ordered so that `-lturso` comes first after
    `reverse_each` (`link.cr:169`); probe 11 prints the link line (`ris build --verbose`) and
    checks the order. Only one Rust archive is
    linked and libsqlite3 is C, so no symbol clash is expected; `two_engines_test` (M1 item 12)
    verifies it, and a failure triggers the Fallback.
*   **Fallback:** if the static build or the rename fails, Turso is linked instead of
    libsqlite3 by a compile flag (`-Dturso` selects `@[Link("turso")]` under the `sqlite3_`
    names; item 11a's fallback bullet). Each binary then has one engine, `two_engines_test` is skipped, and M4 item 3 makes
    the single-engine Turso job required.

#### 11. `test/probe/turso_driver_test.ri` (Create)

*   **Type / Scope**: Engine probe.
*   **Proposed Changes**: Run the sqlite driver's own operations (open, prepare, bind, step, read
    text, BLOB, `RETURNING`, savepoints, WAL pragmas) against libturso. Try `numeric(P,S)` in a
    `STRICT` table and `BEGIN CONCURRENT`; record their results without failing on them. Check
    `foreign_keys=on` with `on_delete: :cascade` and `:restrict`, and that libsqlite3 reads a file
    Turso wrote. Open one `sqlite3://` and one `turso://` connection in the same program. On
    Turso, check that an error in a nested write followed by `ROLLBACK TO` leaves the outer write
    usable (`COMPAT.md` says a dropped write makes the transaction rollback-only), and that
    `SAVEPOINT` while a statement is active returns busy. Compare `REGEXP` results on both
    engines for the patterns `format with:` uses (anchors, classes, alternation); a difference
    is recorded and `format` validation runs in ris (`Regex`) on both. Try `backup_step` and
    record whether it works. If a C API call is missing, the test names it.

#### 11a. `../sqlite/sqlite/core.ri` (Modify, in the driver repository; tag v0.2.0)

*   **Proposed Changes**:
    *   **Module rule:** a `lib` cannot be exported (`sqlite/core.ri:6`), so both lib blocks,
        both instantiations and both `register_driver` calls stay in `sqlite/core`; probe 16a
        checks the generic use inside one module.
    *   **Bindings:** a macro `sqlite_lib(name, link, prefix, full, ldflags = "", dll = "")`
        expands to a `lib` block that defines `FULL = <full>` and `NAME = <link>`. Each fun is
        written once in the macro body with its suffix, e.g.

        ```
        fun open_v2 = {{prefix.id}}open_v2(filename : UInt8*, db : SQLite3*, flags : Int32, zVfs : UInt8*) : Int32
        ```

        and the funs only `FULL` libs have sit inside `{% if full %}`. The `Link` annotation is
        `@[Link({{link}}, ldflags: {{ldflags}})]`, plus `@[Link(dll: {{dll}})]` under
        `{% if flag?(:msvc) && dll != "" %}` (today's branch, `core.ri:134-136`). The calls:
        *   `sqlite_lib(LibSQLite3, "sqlite3", "sqlite3_", true, dll: "sqlite3.dll")`;
        *   `sqlite_lib(LibTurso, "turso", "turso_", false, ldflags: "-lpthread -ldl -lm")`; a
            non-empty `ldflags` is emitted as its own `@[Link(ldflags: ...)]` (item 10).

        `LibTurso` leaves out `create_function`, `bind_zeroblob`, `db_mutex` and the backup
        calls. libturso does not export the first three (`lib.rs` defines only
        `sqlite3_create_function_v2`, `:3141`); the backup calls are stubs that ignore their
        arguments (`lib.rs:1807-1835`) and are not used. `create_function_v2` is not bound:
        `format` validation runs in ris `Regex` on both engines (probe 11), so Turso needs no
        user function.
    *   **Classes:** `SQLite3Driver(L)`, `SQLite3Connection(L)`, `SQLite3Statement(L)`
        (`core.ri:500`) and `SQLite3ResultSet(L)` (`:257`) take the binding module as a type
        parameter; each passes its `L` on when it builds the next (`build_statement`,
        `:710-712`, builds `SQLite3Statement(L)`; the statement builds `SQLite3ResultSet(L)`).
        Every `LibSQLite3.` call becomes `L.`, and type references change with it:
        `connection.as(SQLite3Connection(L))` (`:605-607`), the `L::Statement` return
        (`:609`), `dump(to : SQLite3Connection(L))` (`:771`). The callback types
        `SQLite3Context`, `SQLite3Value` (`type ... = Void*`) and `FuncCallback`
        (`:143-145`) move out of the lib block to top-level aliases; `REGEXP_FN` and `regexp`
        (`:204-209`, already top level) are re-typed against them.
    *   **Names:** `driver_name` (`:718-720`) returns `L::NAME` (`"sqlite3"` or `"turso"`) and
        `server_name` (`:723-725`) returns `"SQLite"` or `"Turso"`; Ricord does not read them.
    *   **Differing call sites** check `L::FULL` at compile time:
        *   `set_up` skips `create_function` on Turso (`:695`; Turso has REGEXP built in);
        *   an empty `Bytes`: SQLite keeps `bind_zeroblob(..., 0)` (`:591`); Turso uses the
            `bind_blob` path (`:593`) with a non-null pointer to a one-byte buffer and length 0,
            so it binds an empty BLOB, not NULL;
        *   `mutexed?` returns false on Turso without calling `db_mutex` (`:790`);
        *   `dump` (`:771`) returns a `DBError` "backup not supported on turso".
    *   **Schemes:** `register_driver "sqlite3", SQLite3Driver(LibSQLite3)` (today's line,
        `:813`) and `register_driver "turso", SQLite3Driver(LibTurso)`. Both use the existing
        `SQLite3Connection.filename(uri)` (`:700-708`, host plus path, decoded), so
        `turso:///abs/path.db` is `/abs/path.db`, `turso://rel.db` is `rel.db`, and the
        in-memory URIs are `sqlite3:%3Amemory%3A` and `turso:%3Amemory%3A`.
    *   **Linking:** the driver does not know where libturso is; see item 9 ("Libraries").
    *   **Release:** the driver's `ris.mod` moves from db v0.2.0 (`sqlite/ris.mod:4`) to
        v0.3.1. Before tagging v0.2.0, list the db API changes between those tags
        (`git -C ../db diff v0.2.0 v0.3.1 -- db/`) in the commit message, adapt `core.ri` to
        them, and pass the driver's own suite (`ris test sqlite/`) plus probe 11. `sqlite3://`
        behaviour is unchanged.
    *   **Fallback mode** (the one description of item 10's Fallback): under `-Dturso` the macro is called once,
        `sqlite_lib(LibSQLite3, "turso", "sqlite3_", false)` inside `{% if flag?(:turso) %}`,
        so `FULL` is false and only the `"sqlite3"` scheme is registered. Ricord reads the same
        flag: `Ricord::TURSO_ONLY = {{ flag?(:turso) }}`. When it is true, `Ricord.open` maps
        `turso://` to `sqlite3://` and picks the `Turso` dialect for every URI. `bin/test`
        passes `-Dturso` when `RICORD_ENGINE=turso` and `.ris-version` has `turso_mode=single`;
        CI then runs the SQLite job without the flag and the Turso job with it.

#### 12. `test/probe/store_text_test.ri` (Create)

*   **Proposed Changes**: M0 has no Ricord code, so every M0 probe and fixture defines its own
    minimal stand-ins in the file: an owner class `ProbeStore` (a `String::Builder` and an
    `Array(String::Span)`) and an `@[OnTape] struct ProbeRecord` (store reference and index).
    Read text rows inside `conn.query { |rs| }` into the store with a span per value; build an
    `Array` of `ProbeRecord`; check the text after the block and after later queries. The
    compile-fail case (`record.copy_to(other : ProbeStore)`) is the fixture
    `test/refused/copy_to_other_store.ri`. M1 item 12 rewrites the fixtures that name stand-ins
    on Ricord types and captures their `# expect:` text again. If a compiler update makes a
    fixture build, `bin/test` fails on it.

#### 13. `test/probe/session_ref_test.ri` (Create)

*   **Proposed Changes**: Inside `::Db::Db.open { }`, an `@[OnTape]` struct holding references
    to a connection and an owner:
    *   can be built;
    *   can be stored in an `Array`;
    *   can be passed to a generated `self.[](db)`;
    *   and a `Tx` struct can be passed the same way.

#### 14. `test/probe/json_test.ri` (Create)

*   **Proposed Changes**: Parse a JSON text held in a store span with `std/json`, read a key by
    `String` and by `Symbol`, and keep the parsed value for a round of the row loop.

#### 15. `test/probe/dispatch_test.ri` (Create)

*   **Proposed Changes**: Store a non-capturing proc to a class method in a flat struct, keep it in
    an `Array`, and call it after the block that queued it. The result goes to `.ris-version` as
    `dispatch=proc` or, if refused, `dispatch=models`; M2 item 2 builds the matching variant.

#### 16. `test/probe/block_exit_test.ri` (Create)

*   **Proposed Changes**: Return a number, a `String` and a tuple from a session block;
    `concat` `Int64` values into an outer array; expect assignment of a block-made array to fail.

#### 16a. `test/probe/lib_generic_test.ri` (Create)

*   **Proposed Changes**: The ris features item 11a and M4 rely on:
    *   a macro that expands to a `lib` block with a constant and a nested `{% if flag?(...) %}`;
    *   a struct generic over a `lib` module, reading `L::FULL` in a `{% if %}` and calling
        `L.fn(...)`;
    *   both of the above inside one module that also registers two drivers (the
        `sqlite/core.ri:6` rule).

    The fixture `test/refused/each_escape.ri` (a `ProbeRecord` yielded by a block and assigned
    to an outer variable) belongs with this probe; it is the compile-fail check M4 relies
    on.

    Fallback if the first two fail: the macro generates two concrete classes,
    `SQLite3Connection` and `TursoConnection`, from one body.

#### 17. `test/refused/record_escapes_open.ri` (Create)

*   **Proposed Changes**: Return a record built inside `::Db::Db.open { }` out of the block;
    `# expect:` the compiler's message about the value outliving its source. For every
    fixture, the `# expect:` text is copied from the compiler's first refusal, then kept fixed,
    so a changed diagnostic shows up as a failure. A refusal for an undefined name never
    counts: the person capturing it checks that the message is about lifetime or ownership.

#### 18. `ricord.ri` (Create), `.github/workflows/test.yml`, `AGENTS.md` (Modify)

*   **Proposed Changes**:
    *   `ricord.ri` imports nothing yet.
    *   `.github/workflows/test.yml`. Current: it sets `RIS_REF` and runs SQLite and
        PostgreSQL (`RIS_REF` at `test.yml:16`, service at `:29-37`, `postgresql-client` at `:50`).
        Change:
        *   read the compiler from `.ris-version` instead of `RIS_REF`;
        *   drop the header comment (`:3`), the `adapter: [sqlite, pg]` matrix (`:25`), the
            PostgreSQL service and `PG_SERVER_URL` (`:29-37`), `postgresql-client` (`:50`) and the
            `getent hosts postgres` export (`:73`);
        *   check out the siblings next to the repository, so the `replace ../db`,
            `../sqlite` and `../../../web` paths resolve: `domify/db` at v0.3.1,
            `domify/sqlite` at v0.2.0 and `domify/web` at v0.1.0, each into
            `$GITHUB_WORKSPACE/../<name>`;
        *   install `binutils` (`nm`, `objcopy`) with apt and Rust with rustup (the toolchain
            from Turso's `rust-toolchain.toml`) in the existing build image (`test.yml:27`);
        *   cache `vendor/turso/lib` keyed on `turso_commit`, and run `bin/build-turso` on a
            miss;
        *   run `bin/test` in two jobs: `RICORD_ENGINE=sqlite` (required) and
            `RICORD_ENGINE=turso` (`continue-on-error: true` until M4).
    *   `AGENTS.md` states:
        *   the design is `doc/DESIGN.md`;
        *   SQLite and Turso are supported, chosen per URI;
        *   no `_strict` methods;
        *   no `!` in method names;
        *   the compiler pin in `.ris-version`;
        *   format with `ris fmt`, check with `ris check` (CI runs `ris fmt --check`);
        *   long builds and test runs go to minitest;
        *   no attribution trailers.

#### 19. Checkout and repository (Rename, after the M0 commit)

*   **Proposed Changes**: All M0 work is committed in the current checkout, `rispacks/grant`.
    After that commit, rename `rispacks/grant` to `rispacks/ricord` and the GitHub repository;
    the `replace ../db` and `../sqlite` paths still hold. Run `bin/test` in the new place.
    `~/apps/ct` updates its `ris.mod` when it moves to Ricord.

### M1: session, store, reads, writes, schema

Goal: one model can be created, found, listed, changed and deleted on SQLite and Turso through `Ricord.open`,
`Model[db]` and `db.write`, with tables from `create_sql` and SQL checked through the log.

**As built (M1, 2026-11-07).** Where the code differs from the items below, the code wins:

*   Module files are plural where a type of the same name lives in them, because a module path
    is also a namespace and `Ricord::Session` would name the module, not the struct:
    `ricord/values`, `ricord/failures` (the error structs; `Error` is the union there),
    `ricord/storage` (`Store`), `ricord/dialects`, `ricord/sessions` (`Session`, `Tx`, `Db`).
*   Store text spans are `Ricord::Values::TextSpan` (two `Int32`s), not `String::Span`, which
    the compiler treats as a view a def may not return. BLOBs live in a second builder and bind
    as hex text through `unhex(?)`, because libturso refuses non-UTF-8 text binds.
*   Error structs keep only numeric extra fields (`id`, `count`, `code`); text extras are part of
    the message.
*   `Court.create_table(db)` runs the DDL; there is no `SCHEMA.create_sql` (a def cannot return
    an array of strings it built).
*   Generated code is expanded in the user's file, so it names every type fully
    (`::Ricord::...`, `::Std::Time::Time`) and leaves NamedTuple/Tuple iteration to helpers in
    `ricord/model`.
*   Deferred: the `OffsetQuery` type split moves to M4 with `each`; the hold-warning log test and
    porting the M1 rows of `doc/TEST_PORT.md` are still open, so `completed:` stays empty.

#### 1. `ricord/value.ri` (Create)

*   **Proposed Changes**: `alias Ricord::Value = Nil | Bool | Int64 | Float64 | Time |
    String::Span | Ricord::ByteSpan`. `ByteSpan` is `{start : Int32, size : Int32}` into the
    store's `bytes`. `Ricord.bind(value : Value | Int32 | String | Bytes, store : Store, d :
    Dialect) : DBValue` turns `Int32` into `Int64`, a `String::Span` into its text (a view of
    `store.text`), a `ByteSpan` into a `Bytes` view of `store.bytes`, and `Time` into text by
    `d.write_time` (the one place the format is defined). `read_row` reads time columns as
    text and calls `d.read_time`; the driver's own `format_time`/`parse_time`
    (`sqlite/dates`, `core.ri:26`, `:596`) are not used. `types_test` round-trips a `Time`
    with microseconds on both engines.

#### 2. `ricord/error.ri` (Create)

*   **Proposed Changes**: The flat error structs, each implementing the trait `Ricord::Failure`. The message is
    `"<table> <operation>: <text>"`, at most 240 bytes (the driver's `DBError::MESSAGE_SIZE`, `db/db/errors.ri:11`) including the prefix and a final `…`
    when cut; the cut falls on a UTF-8 character boundary. Every struct has `table : String` and
    `operation : String`; in addition:

    | Error | Extra fields |
    |---|---|
    | `RecordNotFound` | `id : Int64` |
    | `RecordInvalid` | `count : Int32` (entries in `errors`) |
    | `ScopeError` | `column : String` |
    | `CallbackError` | `callback : String` |
    | `AfterCommitError` | `id : Int64`, `first : String` (the first error's message) |
    | `DatabaseError` | `code : Int32` (the driver's result code) |
    | `Rollback` | none |

    *   `alias Ricord::Error =
        RecordNotFound | RecordInvalid | ScopeError | CallbackError | AfterCommitError |
        DatabaseError | Rollback` is the union methods return.
    *   `Rollback` is what `tx.roll_back` returns, and only that method returns it. A write
        block that returns it rolls back, and `db.write` returns that `Rollback` value, which
        callers may ignore.
    *   Messages: `RecordNotFound` "<table> find: no row with id <id>"; `RecordInvalid`
        "<table> save: <first full message>" plus " (and <count - 1> more)" when count > 1;
        `ScopeError` "<table> save: <column> is scoped and cannot change"; `CallbackError`
        "<table> <operation>: <callback> refused"; `AfterCommitError` "<table> after_commit:
        <first>".
    *   `DatabaseError.from(e : DBError, table, operation)` copies the message, and the code
        when `e` is a `SQLite3Error` (`import sqlite/errors::{SQLite3Error}`,
        `sqlite/sqlite/errors.ri:3,8-12`); for any other `DBError` (whose base,
        `db/db/errors.ri:11`, has no code) `code` is -1. The dialect's `translate` calls it.
    *   Raw SQL (`exec`, `query`, `scalar`) uses `table = ""` and the method name as
        `operation`; the prefix is then "<operation>: ".

#### 3. `ricord/store.ri` (Create)

*   **Proposed Changes**: Owner class `Ricord::Store`:

    | Field | Type | Layout |
    |---|---|---|
    | `models` | `Array(Int32)` | one per record: its `MODEL_ID` |
    | `starts` | `Array(Int32)` | one per record: its first slot in `values` |
    | `values` | `Array(Value)` | `columns.size` slots per record, from `starts[index]` |
    | `text` | `String::Builder` | text bytes; slots hold spans into it |
    | `bytes` | `Array(UInt8)` | BLOB bytes; `:binary` slots hold a `ByteSpan` into it; never reclaimed, like `text` |
    | `changed` | `Array(Bool)` | same layout as `values` |
    | `flags` | `Array(UInt8)` | one per record: bit 0 persisted, bit 1 destroyed, bit 2 read in a load group of more than one record |
    | `scopes` | `Array(Int32)` | one per record: start in `scope_pairs`, or -1 |
    | `scope_pairs` | `Array({Int32, Value})` | each scope's pairs as (column index, value), ended by `{-1, nil}` |
    | `groups` | `Array(Int32)` | one per record: its load group (the records read by one query or one `each` batch; M3 item 1) |
    | `links` | `Array(Int32)` | loaded association targets (record indexes, -1 for nil) |
    | `link_ranges` | `Array(Int32)` | per record, 2 × the model's association count entries from `link_starts[index]`: start and length in `links`; start -1 means not loaded. A loaded nil `belongs_to` is (start, 1) with `links[start] = -1` |
    | `link_starts` | `Array(Int32)` | one per record: its first entry in `link_ranges` |
    | `errors` | `Array(ErrorEntry)` | `ErrorEntry` is `{record : Int32, column : Int32 (-1 for the record as a whole), message : String::Span}` |
    | `wheres` | `Array(WhereNode)` | query conditions as linked nodes (below) |
    | `binds` | `Array(Value)` | bind values; each node names its start and count. A `String` or `Bytes` argument is appended to `text`/`bytes` first and stored as a span; `Int32` becomes `Int64` |
    | `joins` | `Array(Int32)` | per query with joins: association indexes, ended by -1 (filled from M4) |
    | `orders` | `Array(OrderNode)` | `{column : Int32, desc : Bool, prev : Int32}`; own columns only (ordering by a joined column is out of v1) |

    `WhereNode` is `{prev : Int32, op : UInt8, sql : String::Span, bind_start : Int32,
    bind_count : Int32}`; `op` is 0 AND or 1 OR. `sql` is the predicate text, appended to the
    store's `text` when the call is made, from these templates (`c` the quoted column):
    value `c = ?`; `nil` `c IS NULL`; `Array` `c IN (?, ...)`, empty `Array` `1=0`;
    `Range` `c >= ? AND c <= ?` (exclusive end `c < ?`); raw SQL as given, in parentheses. Nodes are never changed after they are
    appended, and a query holds only the index of its last node, so a chain is a persistent
    list: a copy that appends a node points at the old last node, and the earlier query still
    sees exactly its own chain. `or_where(x)` appends an OR node, so the SQL is
    `(<conditions before>) OR (x)`.

    A store can hold records of several models. Text bytes are never reclaimed inside a store:
    `set_text` appends and moves the span, so a store grows with rewrites until the store is dropped (the
    M4 memory bound counts this). Spans are offsets and lengths, so they stay valid when the
    builder grows.
    Methods: `add_record(model : Int32, columns : Int32, associations : Int32) : Int32`; `read_row(index, rs)` reads result columns by position, in
    `COLUMNS` order (record queries always select `COLUMNS`), appends text columns to `text`
    and BLOB columns to `bytes`, and stores spans; `slot(index, col) : Value`; `set_slot(index, col, value)` (marks
    `changed`); `text(index, col) : String` (a view); `set_text(index, col, value)` appends and
    replaces the span; `flag?(index, bit) : Bool`; `set_flag(index, bit, on : Bool)`.

#### 4. `ricord/dialect.ri`, `ricord/sqlite.ri`, `ricord/turso.ri` (Create)

*   **Proposed Changes**: The trait `Ricord::Dialect`. Every method that makes SQL writes into
    a caller's builder:

    ```
    trait Ricord::Dialect
      def quote_ident(name : String, into : String::Builder) : Nil
      def placeholder(n : Int32, into : String::Builder) : Nil
      def insert_returning(primary : String, into : String::Builder) : Nil
      def limit_offset(limit : Int64 | Nil, offset : Int64 | Nil, into : String::Builder) : Nil
      def keyset_after(columns : Array(String), into : String::Builder) : Nil  # (a, b, id) > (?, ?, ?)
      def write_time(t : Time) : String                  # %Y-%m-%d %H:%M:%S.%6N, UTC
      def read_time(text : String) : Time | DatabaseError
      def begin_write : String                           # BEGIN IMMEDIATE
      def pragmas : Array(String)
      def column_sql(type : Symbol, options : ColumnOptions, into : String::Builder) : Nil
      def translate(error : DBError, table : String, operation : String) : DatabaseError
    end
    ```

    `ColumnOptions` is a flat struct: `null : Bool`, `default : Value` (nil for none),
    `limit : Int32` (-1 for none), `primary : Bool`, `references : String` (table, "" for
    none), `on_delete : Symbol` (`:none`, `:cascade`, `:restrict`, `:nullify`). `begin_write`
    is the single source of `BEGIN IMMEDIATE`; item 7 calls it. `Ricord::Sqlite` implements `Ricord::Dialect`. `Ricord::Turso` is a struct holding a
    `Ricord::Sqlite` and forwarding each method to it. `Ricord.open` picks the dialect from the
    URI scheme.

#### 5. `ricord/sql.ri` (Create)

*   **Proposed Changes**: Builds statements into a caller-owned builder; holds no state.
    `d` is the session's dialect. `q : Ricord::QueryState` is the one field list every
    generated `Query`/`OffsetQuery` holds (as its field `state`): `{db : Session | Tx,
    table : String, columns : Array(String), last_where : Int32, last_order : Int32 (-1 none),
    limit : Int64 | Nil, offset : Int64 | Nil, distinct : Bool, includes : Int64 (bit per
    association index, M3), joins : Int32 (start in the store's `joins : Array(Int32)` list of
    association indexes ended by -1, or -1; M4)}`. M1 creates all fields; `includes` and
    `joins` stay 0 / -1 until M3 and M4:

    ```
    def Ricord::Sql.select(d, store, q, columns : Array(String), into : String::Builder) : Nil
    def Ricord::Sql.insert(d, table, columns : Array(String), primary : String, into) : Nil
    def Ricord::Sql.update(d, table, columns : Array(String), primary : String, into) : Nil
    def Ricord::Sql.delete(d, table, primary : String, into) : Nil
    def Ricord::Sql.where(d, store, last : Int32, into) : Nil   # walks the node chain
    def Ricord::Sql.update_all(d, store, q, columns : Array(String), into) : Nil
    def Ricord::Sql.delete_all(d, store, q, into) : Nil
    ```

#### 6. `ricord/session.ri`, `ricord/commit_queue.ri` (Create)

*   **Proposed Changes**: `Ricord::Session` (`@[OnTape]`, built only by `Ricord.open` and
    `request`) with fields `conn` (reference), `store : Ricord::Store` (reference; `open`
    creates one store for the block, `request` a fresh one), `dialect : Ricord::Sqlite |
    Ricord::Turso`, `state : Ricord::TxState` (a reference to one shared owner object holding
    write depth `Int32` (0 = no write, 1 = outermost; *write depth*, used in M2),
    savepoint counter `Int32`, `reading : Bool`, `read_since : Time`, `chain : Int32` (the
    after-commit chain depth being run, M2) and `pending`), and `log : Bool`. A `request`
    child shares `conn` and `state` with its parent and differs only in `store`. Records
    read by `each` refer to their batch's store, not the session's; the batch store lives in
    the `each` block, as the owner rules require (probe 16a).
    `pending : Array(CommitItem)` lives in `state`. Signatures:
    *   `Ricord.open(uri : String, log = false, & : Session -> U) : U | DBError` (like
        `Db.open`); it runs the dialect's pragmas first. A failure to open is the driver's
        `DBError`, passed through unchanged (no table to name); errors after opening are
        `DatabaseError`.
    *   `exec(sql : String, *binds) : Int64 | DatabaseError` (rows changed);
        `query(sql : String, *binds, & : ResultSet -> T) : T | DatabaseError`;
        `scalar(sql : String, *binds) : DBValue | DatabaseError`;
        `release : Nil`.

    Read and write transaction states:

    | State | A read | `db.write` | `release` / `request` end |
    |---|---|---|---|
    | idle | `BEGIN`, then reading | `BEGIN IMMEDIATE`, then writing | nothing |
    | reading | uses it | `COMMIT`, then `BEGIN IMMEDIATE` | `COMMIT`, then idle |
    | writing | reads through the write | `SAVEPOINT` (depth + 1) | `release`: no-op, warning logged; `request` end: rolled back |

    *   **Hold warning:** with `log: true`, when a read transaction ends (`COMMIT` on
        `release`, `request` end or a write), a hold longer than
        `Ricord::READ_HOLD_WARN = 100.milliseconds` since `read_since` is logged at warn level.
    *   **`Session#request(& : Session -> T) : T`:** runs its block in a child session with a
        fresh store; it first rolls back a transaction left open and ends the read transaction
        when its block ends (in M1 because `read_tx_test` uses it).
    *   **Statement log:** each statement and its duration go to db's `LOG`
        (`pub LOG = Log.for("db")`, `db/db/core.ri:43`) at debug level, and the text is
        appended to `Session#statements : Array(String)`, which tests read.
    *   **`commit_queue.ri`:** created here with the complete flat `CommitItem`: `key : Int64`,
        `kind : UInt8`, `method : Int32`, `depth : Int32`, `chain : Int32`, and under
        `{% if flag?(:dispatch_models) %}` `model : Int32`, otherwise
        `dispatch : Proc(Ricord::Db, Int64, UInt8, Int32, Nil | Ricord::Error)`. `bin/test`
        passes `-Ddispatch_models` when `.ris-version` has `dispatch=models` (from M1 on).
        Nothing is queued until M2, which adds `run_after_commit` and the dispatch methods.
    *   **Raw SQL binds:** `*binds : Ricord::Value | Int32 | String | Bytes`, converted by
        `Ricord.bind`; `query` yields the driver's `ResultSet` and appends the statement to
        `statements` before running it.

#### 7. `ricord/tx.ri` (Create)

*   **Proposed Changes**:
    *   **`@[OnTape] struct Ricord::Tx`:** fields `session : Ricord::Session` and
        `depth : Int32`. `tx.session` gives the session; `Court[tx]` reads through the write.
        `tx.roll_back : Ricord::Rollback`. `alias Ricord::Db = Session | Tx` is the type every
        API that accepts either takes.
    *   **`Session#write(& : Tx -> T) : T | AfterCommitError`** (and `Tx#write`, nested):
        `BEGIN IMMEDIATE` (the text from `Dialect#begin_write`) or `SAVEPOINT ricord_<n>`.
        If the block's value is a `Ricord::Failure` (any member of `Ricord::Error`, including
        `Rollback`), it rolls back (`ROLLBACK`/`ROLLBACK TO`) and returns that value;
        otherwise it commits (`COMMIT`/`RELEASE`), runs the after-commit queue at the
        outermost level, and returns the block's value, or `AfterCommitError` if an item
        failed. An early exit from the block rolls back. Before `BEGIN`, a transaction left
        open is rolled back.

#### 8. `ricord/model.ri` (Create; `grant/tape_model.ri` in the tag is the reference)

*   **Type / Scope**: `pub macro model(name, &block)`, imported as `import ricord/model::{model}`.
*   **Proposed Changes**:
    *   **Input:** `table`, `col`, `cols`, `index`, `foreign_key`, `check_constraint` and `def`
        blocks. Each `col` type and its `null:`/`default:` map to a getter type per the Column
        types table; unknown types (including `:decimal`) and unknown options are compile errors.
    *   **Return types:** as in the table under "Return types" in the Technical Plan section
        "Errors".
    *   **`MODEL_ID`:** numbered by the macro in declaration order within one build. It is not
        stored in any file, so it need not stay stable across builds.
    *   **Query API:**

        | Call | Signature |
        |---|---|
        | entry | `Court.[](db : Session \| Tx) : Court::Query` (stores `db` in `state.db`) |
        | `where` | `where(**cols)` with each value the column's type, `nil`, an `Array` of it or a `Range` of it; `where(sql : String, *binds)` |
        | `or_where` | same forms as `where` |
        | `order` | `order(*cols : Symbol)`, `order(**cols : :asc \| :desc)` |
        | `limit`, `offset` | `(n : Int64) : Query` |
        | `find` | `(id : Int64) : Court \| RecordNotFound \| DatabaseError` |
        | `find_by`, `first` | `: Court \| Nil \| DatabaseError` |
        | `to_a`, `all` | `: Array(Court) \| DatabaseError` (into the session's store) |
        | `count` | `: Int64 \| DatabaseError` |
        | `exists?` | `: Bool \| DatabaseError` |
        | `new`, `create` | `(**attrs)`; `create` returns `Court` or a save error |

        A `Query` is a flat `@[OnTape]` struct; each chained call copies it and appends a node to
        the store's `wheres` (see item 3), so the earlier query stays usable.
    *   **Generated** (besides the Query API above): `@[OnTape] struct <Name>` (session,
        store, index); `COLUMNS`, `TABLE`, `PRIMARY`, `MODEL_ID`, `SCHEMA`
        (`SCHEMA.create_sql(d : Dialect) : Array(String)`, the table, its indexes and checks);
        getters and setters; on the record `save`, `destroy`, `reload`, `persisted?`,
        `new_record?`, `changed?`, `to_param`.
    *   **Expansion** for `model Court do table "courts"; col :name, :string; col :rank,
        :integer, null: true end` (sketch; column 0 is `id`):

        ```
        @[OnTape] struct Court
          getter session : Ricord::Session; getter store : Ricord::Store; getter index : Int32
          COLUMNS = ["id", "name", "rank"]; TABLE = "courts"; PRIMARY = "id"; MODEL_ID = 3
          def name : String = store.text(index, 1)
          def name=(v : String) : Nil = store.set_text(index, 1, v)
          def rank : Int64 | Nil
            v = store.slot(index, 2); v.is_a?(Int64) ? v : nil
          end
          def rank=(v : Int64 | Int32 | Nil) : Nil = store.set_slot(index, 2, v.try(&.to_i64))
          @[OnTape] struct Query
            getter state : Ricord::QueryState
            def where(*, name : String | Range(String, String) | Array(String) | Nil |
                        Ricord::Skip = Ricord::SKIP,
                      rank : Int64 | Range(Int64, Int64) | Array(Int64) | Nil |
                        Ricord::Skip = Ricord::SKIP) : Query
          end
        end
        ```

        `where` gets one keyword per column with that column's types, defaulting to the
        marker `Ricord::SKIP` (`struct Ricord::Skip; end; SKIP = Skip.new`, in `value.ri`), so a wrong type or an unknown column is a compile error. A non-null column's
        getter returns the type without `Nil`. If that slot is nil (a record built with `new`
        and not yet set), the getter returns the zero value: `0`, `0.0`, `false`, `""`,
        `Time::UNIX_EPOCH`, an empty `Ricord::Json` (`null`) or an empty `Ricord::Blob`. `save`
        sends NULL for an unset non-null column without a `default:`, so the database refuses
        it and `save` returns `DatabaseError`.
    *   **Two query types:** `offset(n)` returns `Court::OffsetQuery`, generated from the same
        body as `Court::Query`. Chain methods (`where`, `or_where`, `order`, `limit`,
        `includes`) on an `OffsetQuery` return an `OffsetQuery`; it has the reading methods
        (`find_by`, `first`, `to_a`, `all`, `count`, `exists?`, `pluck`) but not `each`,
        `offset`, `update_all`, `delete_all` or `destroy_all`. `limit` does not change the
        type. The entry `Court[db]` returns `Court::Query`.
    *   **Types:** `:json` getters return `Ricord::Json` with `[]` by `String` and `Symbol`;
        `:binary` getters return `Ricord::Blob`.

#### 9. `ricord/json.ri`, `ricord/blob.ri` (Create)

*   **Proposed Changes**: `Ricord::Json` over a store span (parse on read, `[]` by `String` and
    `Symbol`, setter `json=(v : String)` taking JSON text, validated by parsing); `Ricord::Blob` with `bytesize`, `byte_at`, `each_byte`,
    `write_to(io)`.

#### 10. `ricord.ri` (Modify)

*   **Proposed Changes**: `ricord.ri` publicly imports `ricord/session`, `ricord/tx`,
    `ricord/error` and `ricord/model`.

#### 11. `test/spec_helper.ri`, `test/models.ri` (Create)

*   **Proposed Changes**: `with_db(& : Ricord::Session -> T)` deletes and opens the file at
    `RICORD_DATABASE_URL` (item 9 of M0) and runs
    each model's `SCHEMA.create_sql`. `test/models.ri` declares `Account`, `Court`, `Case` and
    `User`.

#### 12. Tests (Create)

*   **`test/crud_test.ri`:** `create`, `find`, a missing `find` (`RecordNotFound`), `find_by`
    (`nil`), every `where` form, `order`, `limit`, `offset`, `first`, `count`, `exists?`, setter
    then `save`, `destroy`, each checked against the rows and the logged SQL.
*   **`test/write_test.ri`:** `db.write` commits; error results and `tx.roll_back` roll back; a
    nested write is a savepoint whose rollback keeps the outer rows; a lone `save` opens its own
    write; `Court[tx]` sees uncommitted rows.
*   **`test/read_tx_test.ri`:** reads share one transaction; a save ends it first; `release` ends
    it; `request` releases on exit; a hold over 100 ms is logged; a transaction left open is
    rolled back by the next write.
*   **`test/schema_test.ri`:** `create_sql` for each `col` type, indexes, foreign keys
    (`on_delete:` enforced with the pragma), checks; `:decimal` and unknown options refused (as
    `test/refused/` fixtures).
*   **`test/types_test.ri`:** `:json` by `String` and `Symbol` keys, `:binary` as `Blob`, a
    `Blob` printed as text refused (fixture).
*   **`test/two_engines_test.ri`:** one program opens `sqlite3://` and `turso://` and writes
    and reads a record on each.
*   **`test/lifetime_test.ri`:** text read in one query stays correct after later queries; the
    `record_escapes_open` fixture now uses Ricord.

### M2: validations, callbacks, dirty tracking, timestamps, after-commit

Goal: a model validates, runs its callbacks in order, writes only changed columns, and runs its
after-commit work after COMMIT with the rules in the Technical Plan section "After-commit
queue".

#### 1. `ricord/validations.ri`, `ricord/errors.ri` (Create)

*   **Proposed Changes**: Runtime checks for presence, length (`minimum`, `maximum`, `is`),
    format (`with:` a `Regex` on the store's text) and inclusion (`in:`), writing `ErrorEntry`s;
    `Ricord::Errors`, a view of one record's entries with `add`, `empty?`, `on`, `full_messages`
    and `size`.

#### 2. `ricord/commit_queue.ri` (Modify)

*   **Proposed Changes**:
    *   **Terms:** *write depth* as defined in M1 item 6 (1 = outermost write). *Chain depth*
        counts after-commit work that queues more after-commit work (0 = queued by the
        application's own write).
    *   **Item:** the `CommitItem` from M1 item 6; `key` is -1 for a create that was rolled
        back (it has no id); `kind` is create, update, destroy or rollback.
    *   **Short forms:** `after_create_commit` is kind create, `after_update_commit` update,
        `after_save_commit` create and update, `after_destroy_commit` destroy.
    *   **Variant choice:** the `-Ddispatch_models` flag from M1 item 6; an application build
        passes it the same way.
    *   **Dispatch**, per that flag; both variants call the same generated
        `self.__after_commit(db : Ricord::Db, key : Int64, kind : UInt8, method : Int32) : Nil |
        Error`, which calls the user's method as the "User signatures" table says. Rollback items
        are queued with kind rollback by every save or destroy whose model declares an
        `after_rollback`:
        *   `proc`: `dispatch : Proc(Ricord::Db, Int64, UInt8, Int32, Nil | Error)`, a
            non-capturing proc to that method.
        *   `models`: `model : Int32` (`MODEL_ID`). The application writes
            `Ricord.models(Court, Room, ...)` once at the top level of its main file; the macro
            generates `Ricord.__dispatch(model : Int32, db : Ricord::Db, key, kind, method)` as a
            `case` over `MODEL_ID`. Without that line `Ricord.__dispatch` is undefined, so
            the build fails with a missing-method error naming it.
    *   **User signatures** (the one definition; other sections refer here):

        | Callback | User method | Called with |
        |---|---|---|
        | `after_commit`, `after_create_commit`, `after_update_commit`, `after_save_commit` | `def m : Nil \| Ricord::Error` | on the record loaded by `key` through the item's `tx` |
        | `after_destroy_commit` | `def self.m(tx : Ricord::Tx, id : Int64) : Nil \| Ricord::Error` | `(tx, key)` |
        | `after_rollback` | `def self.m(session : Ricord::Session, id : Int64 \| Nil) : Nil` | `(session, nil)` when key is -1, else `(session, key)` |
    *   **Run:** `Session#run_after_commit(start)` opens one write per commit item and passes
        its `Tx` to `__after_commit`; rollback items get the session and no write. While an
        item runs, `state.chain` is its chain depth + 1, and anything it queues gets that
        chain. The loop runs items in queue order and continues with items queued during the
        loop (breadth-first) until the queue from `start` is empty. It
        logs each error, keeps the first and returns `AfterCommitError`.
    *   **Chain limit:** chain depths 0-7 run (eight levels); an item queued at chain depth 8
        is not run. It is logged at error
        level, and the write returns `AfterCommitError` naming the limit.
    *   **Rollback:** after the outermost `ROLLBACK`, every queued rollback item runs, then
        the whole queue is dropped. After `ROLLBACK TO` at write depth n, the rollback items
        with `depth >= n` run (as Rails runs `after_rollback` for a failed nested save), then
        all items with `depth >= n` are dropped. After a successful outermost `COMMIT`,
        rollback items are discarded unrun.

#### 3. `ricord/model.ri` (Modify)

*   **Proposed Changes**:
    *   **Validations:** declarations in Rails form: `validates :name, presence: true,
        length: {maximum: 80}, format: {with: /\A[a-z]+\z/}, inclusion: {in: ["a", "b"]}`;
        `validate :method`; `errors`; `valid?`. Messages: presence `"can't be blank"`; length `"is too short (minimum is N characters)"`,
        `"is too long (maximum is N characters)"`, `"is the wrong length (should be N
        characters)"`; format `"is invalid"`; inclusion `"is not included in the list"`; `full_messages` prefixes the humanized
        attribute (`"Name can't be blank"`).
    *   **Callbacks:** method-named `before_`/`after_` callbacks for validation, save, create,
        update and destroy. A callback method returns `Nil | Ricord::Error`; an error
        refuses. `after_commit` with `on:` and the Rails short forms; signatures in the M2 item 2
        "User signatures" table.
    *   **Dirty tracking:** `<col>_changed?`, `changed_attributes`, and `UPDATE` of changed
        columns only; `update(**attrs)`.
    *   **`json_field :col, :key, :type, default:`:** `:type` is `:string`, `:integer`,
        `:boolean` or `:float`. A missing key returns `default:`; a value of the wrong type
        returns the default and logs a warning. The setter `<key>=(v)` takes the field's type,
        rewrites the column's JSON text (`std/json` builder) and marks the whole column
        changed.
    *   **Timestamps:** `cols :timestamps` adds `created_at` (set on create only) and
        `updated_at` (set on create and on an update that changes another column), both
        `Time.utc` at save, stored by `write_time` (microseconds).

#### 4. Tests (Create)

*   **`test/validation_test.ri`:** each validator's message from the M2 item 3 list;
    `full_messages`; `validate :method` adding an entry; `save` of an invalid record returns
    `RecordInvalid` with `count`.
*   **`test/callback_test.ri`:** order recorded in an array; a `before_save` error rolls back,
    inside `db.write` only its savepoint.
*   **`test/after_commit_test.ri`:** runs after COMMIT, once per record, reads the committed
    row; not on rollback; `after_rollback` runs after an outer rollback and after a
    savepoint rollback, and not after a commit; a failing item still lets the others run and
    the write returns `AfterCommitError` with the record id; destroy gets the key; the chain
    limit.
*   **`test/dirty_test.ri`:** `<col>_changed?`; `UPDATE` lists only changed columns (from the
    log); saving with no change sends no `UPDATE` and does not move `updated_at`.
*   **`test/json_field_test.ri`:** a missing key returns the default; a wrong-typed value
    returns the default and logs a warning; the setter marks the column changed.

#### 5. `bin/test` (Modify)

*   **Proposed Changes**: none beyond M1 (`-Ddispatch_models` is passed from M1 on); listed so
    no milestone changes the runner unannounced.

### M3: associations, scope, group loading, dependent

**As built (M2-M3, 2026-11-08).** Where the code differs from the items below, the code
wins:

*   Identifiers are quoted with backticks: with double quotes SQLite reads a name that is not a
    column as a string. Validation patterns go through `Regex.new`, since a regex literal in
    generated code crashes the compiler.
*   A rolled-back create's after-commit and rollback items take the new id after the INSERT, so a
    later update of the same record in that write does not queue a second `after_rollback`; the
    method still gets `nil`.
*   `owner.cases.build(...)` stands in for `owner.cases.new(...)`: ris treats an instance method
    named `new` as in-place construction, which may not grow the store. The SQL builder helper
    is `build_sql`.
*   Loaders read rows with `read_rows` (no preload); `to_a` builds its array after preloading,
    because recursion through a growing local array is refused.
*   A `save` of an unchanged persisted record sends nothing and runs no callbacks (Grant sent
    nothing; Rails would still run the save callbacks).
*   Scope (part B) is a flat pair list in the store (`scope_cols`, `scope_vals`, ended by -1).
    It passes through `has_many`, `includes` and group loading: a preload query adds the
    owners' pairs mapped to the target, and a scoped owner's children get the scope
    `owner.children` gives; a `belongs_to`/`has_one` group load takes one query per distinct
    mapped scope in the group (an unscoped group keeps one query), and the targets keep that
    scope, so changing a scoped column returns `ScopeError`. `update_all` is added early,
    limited by the scope.
*   Rollback state (RICORD_SPEC 5.9): the store keeps an undo log. The first change of a record
    at a write depth logs its old flags, slot values and changed marks, linked to its earlier
    entry; records read inside the write are not logged. ROLLBACK / ROLLBACK TO replay the log
    tail backwards (dependent children included); RELEASE merges into the parent level, keeping
    the older entry; the outer COMMIT clears it. A write opened by `save`/`destroy` itself
    restores only flags, id and changed marks, so attempted values stay for inspection. The log
    arrays only grow (a store array may not shrink after the block's `yield`) and a restored
    `Time` comes back in UTC. Only the store of the session that opened the write is restored.

Goal: associations read through the record's session; `belongs_to` and `has_one` over a group
of N records take one query, not N; `has_many` takes one query with `includes`; scope follows
associations; and destroys cascade inside one write.

#### 1. `ricord/associations.ri` (Create)

*   **Proposed Changes**: A load group is every record read by one query or one `each`
    batch, so at most `batch_size` records with `each`; `find` alone is a group of one.
    *   **Group loading** (`belongs_to`, `has_one`), on first access to the association on
        any record of the group: one query `SELECT ... FROM <target> WHERE <key> IN (?, ...)`
        per 1,000 distinct keys (chunked below SQLite's 32,766-variable limit)
        over the group's distinct non-nil keys. Each row is read into the store; each group
        record's `links` entry is set to the matching record index or -1, its range in
        `link_ranges` to (start, 1), which marks it loaded.
    *   **`has_many`:** without `includes`, one query per owner on first access, filling that
        owner's range. With `includes(:cases)`, after the owner query one query
        `WHERE <fk> IN (<owner ids>) ORDER BY <fk>, id`; rows are appended in that order, so
        each owner's children are contiguous and its range is (first index, count).
        `has_one`/`belongs_to` in `includes` use the group query at once.
    *   **Scope** (rules in the Technical Plan section "Scope inherited through associations";
        no declaration): `account.courts` starts a scope `[(account_id, 42)]` from the
        association's foreign key. Records read through it point their `scopes` entry at those
        pairs; their own associations append the parent's pairs whose column exists in the
        target table, written as a new pair list ended by `{-1, nil}`.
    *   **Column matching** is resolved at compile time: each association's macro sees both
        models' `COLUMNS` and generates a constant mapping each source column index to the
        target's index or -1. A `joins(:a, :b)` chain composes these constants hop by hop
        (pair kept while the mapped index is not -1), so no runtime registry is needed. `create`/`new` through
        the association set the scope columns; every query through it adds `AND <col> = ?`
        per pair, also for each joined table. A record read directly by `Model[db]` has no
        scope (-1).
    *   **`dependent:`** `:destroy` (load the children and destroy each, running callbacks,
        children before parent), `:delete_all` (one `DELETE`), `:nullify` (one `UPDATE ...
        SET <fk> = NULL`), `:restrict` (refuse with `CallbackError` if any child exists). All
        run inside the parent's destroy write, before the parent's `DELETE`.

#### 2. `ricord/model.ri` (Modify)

*   **Proposed Changes**: `col :x_id, belongs_to: :x` readers and writers; `has_many` and
    `has_one` (`foreign_key:`, `dependent:`); `Query#includes`; inherited scope in `WHERE`,
    `create`, `new`, `update_all` and builder joins; `ScopeError` when a scoped column changes;
    `dependent:` modes inside the destroy's write.

#### 3. Tests (Create)

*   **`test/association_test.ri`**, **`test/scope_test.ri`** (`court.cases` carries `account_id`;
    `create` sets it; `update_all` limits by it; changing `account_id` on a scoped record returns
    `ScopeError`), **`test/group_loading_test.ri`** (50 courts' accounts in two queries; `find`
    alone is a group of one; `has_many` with `includes` in two queries, without it one per owner),
    **`test/dependent_test.ri`** (each mode; a refusing child callback rolls back the whole
    destroy).

### M4: batches, projections, bulk writes, request scope, memory

Goal, with batch size 1,000:

1.  An `each` over 10,000 rows peaks at most 2× the resident memory of one 1,000-row read.
2.  A long-lived session's resident memory after 1,000 `request` blocks is within 5 % of
    that after 100.
3.  The bytes in the `RIS_TAPE_STATS=1` line "ris program storage: N bytes taken" are equal
    after 100 and after 1,000 `request` blocks.

#### 1. `ricord/model.ri` (Modify)

*   **Proposed Changes**:
    *   **`Query#each`:** batches of `batch_size`, keyset on the order columns plus id; one
        store per batch holding its records, group and preloads; `limit` caps the total.
    *   **Refused at compile time:** an order column that allows NULL (use `pluck` or `to_a`);
        `offset` (`OffsetQuery` has no `each`, M1 item 8); keeping a yielded record past the
        block (probe 16a's fixture `test/refused/each_escape.ri`).
    *   **Signatures** (on `Query`; the read ones also on `OffsetQuery`):

        | Call | Signature |
        |---|---|
        | `each` | `each(batch_size : Int32 = 1000, & : Court -> Nil) : Nil \| DatabaseError` |
        | `pluck` one | `pluck(col : Symbol) : Array(T) \| DatabaseError` (T the column's getter type) |
        | `pluck` many | `pluck(*cols : Symbol) : Array({T1, T2, ...}) \| DatabaseError` |
        | `pluck` into | `pluck(*cols : Symbol, into : Array(T)) : Int64 \| DatabaseError` (rows appended) |
        | `pick` | `pick(*cols : Symbol)`: the first row as `pluck` would type it, or `nil` |
        | `to_json` | `to_json(into : String::Builder) : Nil \| DatabaseError` |
        | `update_all` | `update_all(**cols) : Int64 \| DatabaseError` (rows changed; one `UPDATE`, no callbacks) |
        | `delete_all` | `delete_all : Int64 \| DatabaseError` (one `DELETE`, no callbacks) |
        | `destroy_all` | `destroy_all : Int64 \| Ricord::Error` (loads in batches, `destroy` per record with callbacks, all in one write) |
        | `joins` | `joins(*assocs : Symbol) : Query`, an `INNER JOIN` per association on its foreign key, scope added per joined table |
        | `distinct` | `distinct : Query` |

#### 2. Tests (Create)

*   **`test/each_test.ri`** (10,000 rows in key order and in `order(:name)` order; inserts during
    iteration neither repeat nor skip rows; `offset` refused), **`test/memory_test.ri`** (the M4 goal: criterion 1
    compares `VmHWM` from `/proc/self/status` printed by two child processes; criterion 2
    reads `VmRSS` in-process; criterion 3 parses the "ris program storage: N bytes taken"
    line that `RIS_TAPE_STATS=1` prints, `ris1/src/iyi/region.iyi:783`), **`test/pluck_test.ri`**,
    **`test/bulk_test.ri`** (scope honoured), **`test/request_test.ri`**, **`test/two_db_test.ri`**
    (CUJ 6), **`test/session_exit_test.ri`** (CUJ 7, on Ricord; probe 16 stays as the compiler check).
    Cases: `pluck_test`: each signature row, `pick` on an empty result is `nil`;
    `request_test`: a fresh store per block, a transaction left open is rolled back, the read
    is released at the end; `two_db_test`: two `Ricord.open` blocks on two files, records of
    each stay in their own session; `session_exit_test`: values returned from a session block
    (number, `String`, tuple) survive it.

#### 3. `.github/workflows/test.yml` (Modify)

*   **Proposed Changes**: The Turso job becomes required (drop `continue-on-error`).

**As built (M4 part A, 2026-11-08).** Where the code differs from the items above, the code
wins:

*   `pluck(:col)` returns `Array(Ricord::Plucked)` (`String | Int64 | Float64 | Bool | Time |
    Nil`): ris cannot pick a return type from a symbol's value. `pluck(:col, into: typed)`
    converts into the caller's element type. Plucked text is a view into the session's store.
*   An order column that allows NULL is refused at run time by `each` (`DatabaseError`), not at
    compile time, because order columns are runtime symbols. An unknown association in `joins`
    is also a run-time `DatabaseError`.
*   `offset` returns `OffsetQuery`, which has no `each` (fixture `test/refused/each_offset.ri`);
    `batch_size < 1` counts as 1.
*   `delete_all`/`destroy_all`/`update_all` with `limit` or `joins` go through `` `id` IN (SELECT
    ...) ``. Typed conditions, order and select get the table prefix under `joins`.
*   Part B: `Ricord.open` and `request` end their blocks with `session.released(yield ...)` so
    a `String` or tuple can leave them. Memory criterion 2 is asserted on SQLite and reported
    as pending on Turso: libturso grows RSS once in the first 1,000 distinct-row saves (WAL
    frames), then stays flat. `memory_test` starts its children through `system(3)` because
    std `Process.run` does not build on ris1. The Turso CI job is required.

### M5: example, documents, contract

Goal: the guide's extracted examples build and pass, and the example app passes `app_test.ri`
on both engines.

#### 1. `examples/tape_web/app.ri`, `app_test.ri`, `ris.mod` (Modify)

*   **Proposed Changes**: The users resource on the new API. A worker opens the global database
    (a `sqlite3:` URI from the `DATABASE_URL` environment variable) in its factory's
    `with_handler` (contract at `web/web/server.ri:46`, called at `:128`) and
    keeps the session in its handler. Each request uses `request`, and the app's response
    helper in `examples/tape_web/app.ri` calls `db.release` before writing the response; the
    `web` package does not change.
    Routes: index (with `includes`), show, create (422 with errors), update, destroy, all driven by
    `app_test.ri`.

#### 1a. `bin/test` (Modify)

*   **Proposed Changes**: stop skipping `examples/`: run `ris test examples/tape_web/app_test.ri`
    once per engine with `DATABASE_URL` set to the slot's `RICORD_DATABASE_URL`; extract and
    run the guide's fences (item 3).

#### 2. `doc/API_CHANGES.md`, `doc/NAMING.md` (Modify)

*   **Proposed Changes**: A top entry "From Grant to Ricord" with before/after examples
    (`class < Grant::Base` to `model ... do`, connection names to `Model[db]`, `find!` to `find`,
    `save!` and `save` to one `save`, `after_commit` blocks to method names) and a table of removed
    APIs citing `grant-base-final`. `NAMING.md`: one method per action, with failures returned as error values, not raised; `!` never
    in names (`~/contribute/ris1/doc/reference/iyi/source/SPEC.md`, section III.1.7), `_in_place` suffixes and keyword-named aliases stay allowed.

#### 3. `doc/TAPE_MODEL.md` (Delete), `doc/GUIDE.md` (Create)

*   **Proposed Changes**: Opening, `Model[db]`, records, writes, after-commit, associations, scope,
    `each`, errors, values leaving a session, and a section "Isolation" on raw SQL and the file
    per account. `bin/test` extracts each ```` ```ris ```` fence of `doc/GUIDE.md` into
    `build/guide/<n>_test.ri` and builds and runs it.

#### 4. `RIS_GRANT_SPEC.md` to `RICORD_SPEC.md` (Rename with `git mv`, then Modify)

*   **Proposed Changes**: Rewrite to this design, keeping rule numbers (removed rules keep their
    number with "(removed)"): replace `Str` and `Ary` with `String` and `Array`; pools (2.4, 3.6, 7.6, 8.3) to "a
    session owns one connection for its block; records refer to their session"; 5.2 and 5.3 to one
    method per action; 5.10 and 5.11 to the flat queue and `AfterCommitError`; 8.1 and 8.5 to
    SQLite and Turso.

#### 5. `README.md` (Modify)

*   **Proposed Changes**: An introduction of at most 80 lines: installation, one model, one `Ricord.open` block
    with reads, a write, an association, and links to the guide and the design.

### Verification Plan

*   **Compilation/Build**: `bin/test` builds every test with the pinned compiler, with
    `IYI_CACHE_DIR=$PWD/.ris-cache`, once per engine (`RICORD_ENGINE=sqlite` and `turso`); the
    Turso job is non-blocking until M4 item 3.
*   **Unit Tests**: probes first, then every `test/*_test.ri`.
*   **Compile-fail checks**: every `test/refused/*.ri` must fail with its `# expect:` text.
*   **Static Analysis**: `bin/test` ends with `ris fmt --check ricord test` and
    `ris check ricord test`; CI fails on either.
*   **Memory**: `test/memory_test.ri`, bounds as in the M4 goal.
*   **E2E**: `examples/tape_web/app_test.ri` drives every route.
*   **Per milestone**: done when its tests and all earlier tests pass, its `doc/TEST_PORT.md`
    rows are closed, and it is in one commit (M0 and M5 include the documents they list).
