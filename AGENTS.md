# Grant for ris

Do not pollute commit messages with co authored by Agents.

Wrap documentation lines at 100 characters maximum.

Read `port/HINTS.md` first, then `doc/NAMING.md`; search `doc/PORTING.md` (the historical port
journal) for the area at hand.

Grant is an ORM written for ris and its tape, not a 1:1 port of Crystal Grant: tape-backed records
cannot keep the `Grant::Base` inheritance and macro DSL shape. Design for ris and the tape
(`@[OnTape]` rows, `Tape::Array` results, heap only where identity and writes need it). Keep the
public API as close to Grant as the tape allows (`where`, `order`, `find`, `save`, `create`,
`has_many`, `belongs_to`, ...). `crystal-upstream/` is reference only; never edit it and do not
compile the Crystal suite.

The user API stays the same: prefer changing what a method does inside over adding a parallel
method (no `pluck_tape` beside `pluck`). When a user-visible change is unavoidable (a renamed or
removed method, a new return type, a call that must now run inside `tape do`), record it in
`doc/API_CHANGES.md` in the same commit: what changed, why, and what a Grant user updates, with a
before/after example. Someone moving an app to ris Grant reads that file to learn what to change.

SQLite and PostgreSQL are in scope. Every test runs under both `CURRENT_ADAPTER=sqlite` and
`CURRENT_ADAPTER=pg` (PostgreSQL 17 in the `grant-pg` docker container on 127.0.0.1:5433);
keep adapter branches (`if CURRENT_ADAPTER == "pg"`, `adapter.postgres?`) as runtime branches.
`bin/test [FILE...]` runs them; `TEST_ADAPTERS=sqlite` limits a run. Never weaken, delete or skip
assertions just to make tests pass; adapt only call shapes a design change forces.

Error types implement `Error`; failures are returned error union members, rescues become union
checks, and transactions roll back on error block results. Rollback itself is an error value.

Apply `doc/NAMING.md`: a failing `foo!` becomes `foo_strict`, returning `T | Error`; callers use
postfix `!` or `.or_panic`. In-place relation `foo!` becomes `foo_in_place`. Keyword names receive
documented aliases, starting with `import_records` for `import`.

Commit with a descriptive message and no attribution trailers. Shared-core signature changes are
allowed, provided every affected test is updated in the same commit. Always use
`/home/priit/contribute/ris/bin/ris` unless `RIS` explicitly overrides it, and set
`IYI_CACHE_DIR=$PWD/.ris-cache`.
