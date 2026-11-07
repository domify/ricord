# Grant on the tape ris

* **Author:** Priit Tark
* **Date:** 2026-11-06

## Overview

Grant is an ActiveRecord-style ORM for ris. The current ris compiler has no heap
and no GC. Every def, block and loop round frees its scratch when it ends.
No reference may outlive its source (SPEC 1.1, 3.2). The db package (v0.3.1)
has no pools. A connection belongs to the block and the task that opened it, and
column text is valid only inside the block that read it. Grant HEAD no longer
builds, because `grant/adapter/pool_support.ri` needs `Db::Core::StringKeyCache`,
which was removed with the pools.

The goal is a small ORM on the new compiler. It keeps the declarations people
like (`has_many`, `belongs_to`, validations, callbacks, `where`/`order` chains,
`save`) and passes the connection explicitly:

```ris
AppDb.open(uri) do |db|
  user = db.users.find(1)!
  user.name = "Ann"
  user.save!            # the record holds its session
  user.team             # loads through the same session
end
```

The first user is a port of a Rails 8 app (ct-ruby: 107 models, 358
`belongs_to`, 319 `has_many`, 18 `after_commit`, 24
`accepts_nested_attributes_for`, 7 files with `through:`). Its counts set
what Grant must cover. Its ris port (ct, with its own `rils/record`) is an
experiment and not a design reference.

## Analysis

Seven fresh-context reviewers looked at the concept. Their main points, merged:

**1. Record lifetime is the core design, and it is not written down yet.** Every
reviewer raised it.
- **A record may refer to its session, but it cannot leave the session block.**
  Records cannot be returned out of `Grant.open`, stored, or captured by a task.
- **A def cannot return its own local owner** (SPEC 2.1). So `find` must build onto
  the session's storage, not onto a local.
- **Column text dies at the end of the `db.query` block.** Every attribute must
  therefore be copied into storage the session owns.
- **Session storage only grows.** Loading 10k rows, or preloading a big
  `has_many`, keeps all of it until the block ends. A streaming `each` and
  short sub-scopes (`db.batch {}`) are needed.

Two tests should prove the rules before anything else is built:
- Text read in one loop round is still correct after the next round.
- Returning a record out of `open` fails to compile.

A simpler fallback is to make records plain data and have each operation take
`db` (`db.save(user)`), with `User.in(db)` as sugar on top.

**2. Transactions and the `after_commit` replacement are undesigned.**
- **What db does today:** db's `Connection#transaction` refuses to nest and rolls
  back on an early exit or a `DBError`. It has no commit hook, so Grant must keep
  its own list of hooks for the outermost transaction and run them after
  `commit`.
- **Option A, payload queue:** a hook builds a small Share payload (ids, a few
  copied strings) inside the transaction. The session runs the payloads after
  COMMIT and drops them on rollback, which gives `after_rollback` too.
- **Option B, outbox table:** the payload is written as a row in the same
  transaction, and a worker task drains it. It is durable, but handlers must be
  idempotent.
- **Option C, no facility yet:** port the 18 call sites as plain code after the
  `transaction` block, and add a facility only if the same pattern keeps
  repeating.
- **Still to decide:**
  - Does `save` autocommit?
  - Do nested transactions use savepoints?
  - Is `dependent: :destroy` atomic?

**3. The plan is three projects in one.** It combines an ORM port, compiler
prelude work, and design research (typed `includes`, `after_commit`). "Done"
would not finish visibly. Use the first user's actual usage counts as the
spec, not Rails parity, and add features in milestones.

**4. Pin the compiler and dependencies.**
- **Current state:** `ris.mod` still requires db v0.1.1, and its `replace` lines
  build against whatever sibling checkout is current.
- **Do:**
  - Require db v0.3.1 and record the exact ris commit.
  - Land prelude fixes (`Array#run`, needed by `copy_to`) as separate compiler
    commits.
  - Keep a small probe suite that runs on every compiler bump, before Grant does.

**5. The tape model needs more than "a thin core on db".** It uses its own
bind and value types, `read_tape!`, `Executor.open_statement`,
`ensure_clause_template`, the error types and `to_heap` (at six call sites,
plus `User::Data`). Its regex and inclusion validators need tape-native
`===` and `includes?`. The good news: the global connection lookup is a single
choke point (`self.adapter`), so swapping in a session is feasible.

**6. Defer typed `includes`.**
- **Why defer:** in a fast-changing compiler it multiplies generic types (models ×
  include combinations), and the loaded type has no name you can write in a
  signature.
- **v1:** preload into the record's side storage, and give a missing
  preload an explicit `load(:team)` or a `NotLoaded` case. Keep "no foreign key"
  (nil) and "database failed" (error) as distinct cases.
- **Later:** a compile-time association descriptor, so that `includes` returns a
  relation over a known preload set.

**7. Delete Grant::Base rather than keep `legacy/`.** It will never build on the
new compiler, and its 357 tests would rot and mislead searches. Tag the last
Base commit (`grant-base-final`) and give one row per removed API in
`doc/API_CHANGES.md`.

**8. Treat PostgreSQL as its own milestone.**
- **Why:** PG roughly doubles adapter work: `$1` vs `?` placeholders, RETURNING vs
  last insert id, decoding.
- **Dialect seam:** one narrow interface (`dialect/sqlite`, `dialect/pg`), so the
  core never branches on the adapter.
- **Tests:** a shared conformance suite runs once per adapter.

**9. Define the error contract.**
- **The limit:** a `DBError` message is cut at 240 bytes, so put the table and
  operation first.
- **The difference:** validation `Errors` is a growing list, not a flat error.
- **The split:** keep validation failures and database failures apart in the
  return types.

**10. Smaller points.**
- **Per-request connect cost:** with no pool, every request opens a connection.
  Measure the connect cost on PG.
- **No global registry:** prefer `Grant.open(uri)` over `Grant.open(:name)`.
- **Layout:** split the 1175-line `tape_model.ri` (session, model, record,
  query, associations, validations, callbacks, errors, dialect) before adding
  features, and decide now whether to drop the `tape_` prefix.
- **SQL logging:** add an optional per-session statement logger, because there is
  no central place to log SQL any more.

**Contradiction at the core:** Rails ergonomics assume records and a
connection that are available everywhere, and the tape ris forbids exactly
that. The way through is one session per request, which matches the Rails
request lifecycle. Records never escape the session block, and data that must
leave goes out through `copy_to` or a small projection struct.

## Goals vs. Non-Goals

* **In-Scope Goals:**
  * Grant builds and runs on the current ris and db v0.3.1.
  * A session entry point: `Grant.open(uri) { |db| }` and `User.in(db)`. A
    record holds its session.
  * Models declared with `model ... do`: columns, timestamps, `belongs_to`,
    `has_many`, `has_one`, `dependent:`, validations, method-named callbacks.
  * Queries: `find`, `where`, `order`, `limit`, `includes` (untyped preload),
    `create`, `save`, `update`, `destroy`, transactions.
  * SQLite. Tests and `examples/tape_web` pass on it.
* **Out-of-Scope Non-Goals:**
  * Grant::Base and its Rails surface (pools, sharding, encryption, async,
    health monitor, registries).
  * Typed `includes`, nested attributes, `through:`, schema and migrations.
    These come later.
  * Records that live longer than one session block.
  * PostgreSQL and row-level security, for now. The design keeps room for
    them.

## Alternatives Weighed

* **Port all of Grant::Base.** Rejected by author: most of it (pools, global
  registries, `after_commit` holding records) cannot exist under the new
  memory rules, and it is weeks of work for features with no user.
* **Keep a global connection so `User.find(1)` takes no argument.** Rejected by
  author: SPEC 3.2 and 5.1 forbid storing a block-owned connection in program
  state or sharing it between tasks. The explicit entry point `User.in(db)`
  was chosen instead.
* **Use ct's `rils/record` as the model.** Rejected by author: ct is an
  experiment, not a reference.
* **Rename `Tape::String`/`Tape::Array` to `Str`/`Ary`.** Rejected by author:
  the compiler removed those names on 2026-11-02. The uncommitted diff is
  saved as a patch.

## Key Decisions & Staging for Next Steps

Decided:
* Grant becomes a small ORM on the tape ris. The first user is the ct-ruby port.
* Records live within one session block, and a record holds its session (or
  tenant), so `user.save` and `user.team` take no argument.
* Gaps in the ris prelude may be fixed in ris1, ris2 or ris3.
* Grant::Base is deleted. The last commit with Base gets the tag
  `grant-base-final`, and `doc/API_CHANGES.md` lists each removed API with that
  tag.
* `after_commit` uses option C for now: plain code after the `transaction`
  block. Option A (a payload run after COMMIT and dropped on rollback) comes
  later, shaped by the ct-ruby call sites.
* The entry point is the application's database, which lists its models:

  ```ris
  database AppDb do
    models Account, AccountUser, Country, Court, User
  end

  AppDb.open(uri) do |db|
    db.courts.all                           # every court in the database
    current_account = db.accounts.find!(id)
    current_account.courts.find(1)          # WHERE account_id = ? AND id = 1
    current_account.courts.create!(name: "x")  # account_id set from the account
  end
  ```

* There is no `tenant` keyword and no hidden global scope. In practice the
  author found that `activerecord-multi-tenant` hid its scope in global state and
  then failed to apply it to harder SQL. Isolation is built from four general
  parts instead:
  1. **Scope inherited through associations.** A record read through
     `current_account.courts` remembers its parent. Its own associations
     (`court.cases`), `create!` and `update_all` stay inside that account. Joins
     and subqueries built by the query builder add the account condition to
     every joined table that has it. This works for any parent model
     (account, organization, project), and for users in several accounts
     through `AccountUser`. It is a convenience and an early defence, not a
     guarantee: raw SQL does not get it.
  2. **PostgreSQL row-level security as the guarantee.**
     `AppDb.open(uri, account: id)` runs `SET app.account_id` when the block's
     connection opens. The setting holds only until the block ends, so it cannot
     leak to another request. Policies (`ENABLE` and `FORCE ROW LEVEL
     SECURITY`, `USING (account_id = current_setting('app.account_id')::bigint)`)
     cover joins, subqueries, raw SQL and views. A missing setting must match no
     rows. Admin code and jobs that must see every account connect with a role
     that has `BYPASSRLS`, through a different URI. This also answers who may
     read across accounts. Migrations later get a helper to create the
     policies.
  3. **Composite foreign keys.** `FOREIGN KEY (account_id, court_id)
     REFERENCES courts (account_id, id)` stops a row from pointing at another
     account's row. `belongs_to` inside an account joins on both columns.
  4. **A database per account, on SQLite.** SQLite has no row-level security.
     A database file per account is the same guarantee there. It is the
     application's choice, because `AppDb.open(uri)` takes any URI, and Grant
     needs nothing extra for it.
* `db.<model>` always means the whole database the connection can see.
  Restricting it in code (a ris visibility rule such as
  `@[Visible(admin, jobs)]`, or a compiler plugin system) is deferred. With
  row-level security the database role already sets the limit.

Proposed for the first version, not yet confirmed:
* An association that was not preloaded is an error unless it is loaded on
  purpose (`strict_loading` by default, with `user.load(:team)`).
* Scope inherited through associations in M2 or M3. Row-level security once
  PostgreSQL support and migrations exist.

* **SQLite first, PostgreSQL later.** Grant's milestones up to the stated Done
  target SQLite only. The first user's plan is a SQLite database file per
  account, with shared tables (users, `AccountUser`, countries) in a global
  file attached with `ATTACH`. A file per account is the isolation guarantee
  on SQLite: no query can reach another account's rows. PostgreSQL
  (the driver already works) and its row-level security come later, for
  example when a large customer wants its own server. Grant keeps the dialect
  seam so that adding PostgreSQL does not change the core.
  * Choosing the file for an account is application code
    (`AppDb.open(account_db(id))`), not a Grant feature.
  * Grant's later migrations must run over many files: lazily when a file is
    opened, or in batches.
  * One-file isolation on SQLite (temp views that shadow tables, plus
    `sqlite3_set_authorizer`) is not planned. It would need authorizer support
    in the ris sqlite driver.
  * Turso (the Rust rewrite of SQLite, still beta in 2026, with concurrent
    writes) and libSQL may be tried later as a drop-in driver. That needs no
    design change.
  * Risks the first user accepts: one server (backups with Litestream or
    similar), cross-account reports that read many files, and moving existing
    production data out of PostgreSQL. That data move is a separate project
    after the ris port.

Open, for the author:
1. Porting ct-ruby: code that calls `Court.find(id)` and relies on
   `multi_tenant` must become `current_account.courts.find(id)`. How should
   those call sites be found? 88 models use `multi_tenant :account`.

Ideas for later, from ideation:
* Column checks at compile time (`where(nmae: ...)` fails to build).
* Columns read from the schema instead of declared by hand.
* Projections that read rows straight into a block without building records
  (`db.users.select(:id, :name).each { |id, name| }`).
* Validation failure as its own return type for `create!`.
* Tests in a session that rolls back at the end.
* A statement cache that lasts for one session.

Facts to check before the draft:
* Does `ResultSet#read_tape!` copy or return a view? `load_all` may return text
  that is already dead.
* Is db's `Connection` an owner (SPEC 2.1)? That would limit how a session can
  hold it.
* Is there a savepoint path for nested transactions in db?
* Can db's `args : Array(A)?` take a tape array for binds?

Proposed milestones:
* **M0, baseline:**
  * Pin ris and db v0.3.1.
  * Remove `pool_support.ri` and the `base.ri` import from the tape model.
  * Land `Array#run`.
  * The probe suite passes.
* **M1, SQLite only:**
  * `Grant.open(uri)` and one model.
  * `find`/`where`/`order`/`limit`/`create`/`save`/`destroy`.
  * Text copied into session storage.
  * Associations loaded explicitly.
  * `db.transaction`, presence validation, `before_save`.
  * Gates: the lifetime tests, a reduced tape model test, one tape_web route, and
    a memory measurement on 10k rows.
* **M2:** update, the other validations, callbacks.
* **M3:** `includes` (untyped preload), `has_one`, `dependent:`.
* **M4:** the `after_commit` replacement. Hooks are dropped on rollback.
* **M5:** tape_web on SQLite, and `doc/API_CHANGES.md`. This is the stated
  Done.
* **Later:** PostgreSQL through the shared conformance suite, then row-level
  security.

## Revised while drafting (2026-11-06)

These supersede the matching items above.

* **Entry point:** `User.find_strict(1, db: db)`, `User.where(..., db: db)`,
  `User.create_strict(..., db: db)`. A session is opened with
  `Grant.open(uri) { |db| }`. There is no `database AppDb` declaration.
  `in:`, `on:`, `using:` and `in_db:` were weighed. The first three are SQL
  keywords, and `in_db:` is longer.
* **A record keeps its session** (`user.save`, `user.team` with no argument).
  `save(db: other)` overrides it, and `copy(db: other)` inserts a copy
  elsewhere.
* **One connection per web worker** for the global database. web runs a
  fixed set of worker tasks, each serving requests in turn, so this obeys
  SPEC 5.1. An account file is opened per request.
* **The core follows Campfire**
  (`once-campfire-rust/crates/db`, `once-campfire-ris/rils/record/database.ri`):
  * `db.write { |tx| }` with `BEGIN IMMEDIATE`;
  * a lone `save` opens its own write;
  * request reads share one deferred read transaction.
* **`after_commit` is in scope now, as a flat queue on the transaction.** Each
  item holds the model, the key and the method. After COMMIT, Grant reads the
  record again and calls the method. Rollback drops the items. This replaces
  "option C first".
* **SQLite only.** Turso, libSQL and HC-tree stay out of scope.
* **Entry point, final:** `User[db].find_strict(1)`, `User[db].where(...)`,
  `User[tx].create_strict(...)`. This replaces the `db:` argument above. `User.in(db)`,
  `db[User]` and `db.users` were weighed. `with ... yield` is not supported
  by ris.
* **No `_strict` methods.** `find` is strict, as in Rails: it answers
  `RecordNotFound`. `find_by` and `first` answer `nil`. `save`, `create` and
  `update` answer `RecordInvalid` when validation fails. Errors are separate
  types implementing `Error`, so `case` tells them apart and `!`
  propagates them. This replaces the `_strict` rule of `doc/NAMING.md` for
  the new Grant. `!` stays out of names (iyi III.1.7).
* **Name: Ricord** (ris + record). The namespace is `Ricord::` and the module is
  `github.com/domify/ricord`. It is not a port of Crystal Grant: the
  vocabulary comes from Rails, the write core from Campfire, and the code is
  new. Grant is credited as an inspiration.
* **Columns are declared one way: `col :name, :type, **options`**, in Rails
  schema vocabulary (from `doc/RAILS-DSL.md` on `native-iyi`).
  * A reference is `col :account_id, belongs_to: :account`: column, index,
    foreign key and reader.
  * Bundles that belong together use `cols`: `cols :timestamps`.
  * `has_many`/`has_one` are separate lines because they add no column.
* **Group loading instead of strict loading.** Reading an association on one
  record loads it for every record read by the same query or `each` batch, in
  one `IN (...)` query (as `goldiloader` does). This replaces `NotLoaded`.
* **Settled when the draft was compared with this brief (2026-11-06):**
  * `after_commit` is built in M2, with the callbacks. This replaces M4.
  * An unknown column in `where` fails at compile time.
  * A lone `save` opens and commits its own write.
  * A text setter appends to the store's text buffer. The buffer grows until
    the store ends, which is accepted for a store that lives one request or one
    `each` batch.

## Decided during review (2026-11-06)

* Engine: Turso first (in-process, libturso behind the ris sqlite driver), SQLite later,
  PostgreSQL later. Rejected: SQLite first, PostgreSQL first.
* E1: `create_sql` from models (tables, indexes, foreign keys, checks); `ALTER` later.
* E2: no `save(db: other)`/`copy(db: other)` in v1.
* E3: group loading for `belongs_to`/`has_one`; `has_many` uses `includes`.
* E4: Rails after-commit callback names; no `durable` option; durable work goes to a later job
  package with the ActiveJob API (job row in the same transaction, RisBoard notice, startup sweep).
* F1: shared read transaction per request, ended before a write and by `db.release`; `request`
  rolls back a transaction left open.
* F5: do the work inside the block; single values return; lists through caller-owned arrays.
* F6: `after_destroy_commit` methods are class methods taking `(db, id)`.
* F7: one store per `each` batch.
* F8: all after-commit items run and log; the caller gets `AfterCommitError` with the record id.
* F9: `Ricord.open` sets `journal_mode=wal`, `busy_timeout=5000`, `foreign_keys=on`.
* F11: `:json` is `Ricord::Json` (`settings[:theme]`, `json_field`); `:binary` is `Ricord::Blob`;
  `:decimal` is a compile error until `Ricord::Decimal`; ct-ruby money stays `:bigint` cents.
* F12: `each` pages by keyset on order columns plus id; `offset` with `each` is refused.
* F13: changing a scoped column answers `ScopeError`.
* Future: `track_changes` change log (PaperTrail and Turbo broadcasts), Turso CDC as a base.
