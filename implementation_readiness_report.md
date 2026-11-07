Status: closed without convergence (2026-11-07)

# Goldfish Annotated Review Report: Stage 9 (Implementation Readiness), round 1

**Target:** `doc/DESIGN.md`, DetailedRange 875-1252
**Reviewers:** `egm-implementation-readiness` (IR), `egm-codebase-details` (CD),
`egm-style` (ST): all completed.
Merged findings list every source id. Elephant checks: `.github/workflows/test.yml`
exists; `port/` has 28 tracked files; `test/grant_tape_model_test.ri` imports
`grant/errors` and `test/spec_helper`; `grant/tape_model.ri` imports
`grant/adapter/*`; the sqlite driver hard-codes `@[Link("sqlite3")]` (core.ri:134).

## ESCALATE: these need the author's decision

### [E1] IR-4, CD-4: Major. How the engine is chosen at link time
* **Scope:** M0 items 9, 10, 11a; Verification.
* The driver has `@[Link("sqlite3")]` fixed. Neither the plan nor this
  conversation decided how ris switches it. Options:
  * **(a)** a compile flag in the driver: `{% if flag?(:turso) %} @[Link("turso")] {% else %} @[Link("sqlite3")] {% end %}`,
    and the same flag guards `create_function`, `bind_zeroblob` and `mutexed?`.
    `bin/test` passes `-Dturso` when `RICORD_ENGINE=turso`. (Needs: does ris
    support `flag?` in macros and on `@[Link]`?)
  * **(b)** a symlink: `bin/build-turso` installs `libturso.so` as
    `libsqlite3.so` in `vendor/turso/lib`, and `IYI_LIBRARY_PATH` picks it.
    The missing-symbol guards then need a runtime check (`sqlite3_libversion`)
    instead, and the unresolved symbols still break linking. So (b) works only
    if those calls are removed or stubbed.
* Recommendation: (a), if ris has compile flags.

### [E2] IR-9, ST-3: Major. The memory bound in `memory_test`
* **Scope:** M4 item 3; M1/M3 goals.
* "Under a fixed bound" is not testable. Proposed rule: after a 10,000-row
  `each` with batch size 1,000, peak tape use (from `RIS_TAPE_STATS`) is at most
  2× the peak of a single 1,000-row batch, and the worker's tape use after 1,000
  requests differs from after 100 by under 5 %. Accept the numbers or name others.

### [E3] IR-6: Major. The rename's order and location
* **Scope:** M0 item 2.
* Does the M0 commit happen in `rispacks/grant`, with the folder and GitHub repo
  renamed after it, or after the move? Proposed: commit in place; the folder
  and repo rename (and `~/apps/ct` paths) follow as a separate step at the end of M0.

## CONTEST

### [C1] CD-3: Blocker. `.github/workflows/test.yml` "does not exist"
* It exists (`ls .github/workflows` → `test.yml`). The valid part goes into F8:
  the workflow still uses `RIS_REF` and runs SQLite and PostgreSQL.

### [C2] CD-14 (part): `design_draft.md` "Delete"
* It is not in the tree; the item becomes "already absent, nothing to do".
  Applied as a fix (F12), not a contest of the finding.

## PROPOSE FIX: blockers

### [F1] IR-1, CD-1, CD-2, CD-7: M0 cannot pass `bin/test`
* The three kept tape tests import `grant/base`, `grant/errors`,
  `grant/adapter/*` and `test/spec_helper`, all deleted in M0.
* **Edit:** M0 deletes the three tape tests too (they stay in the tag
  `grant-base-final`, and M1 `test/model_test.ri` covers the same reads).
  `grant/tape_model.ri` is deleted in M0 (the tag keeps it as reference).
  `test/spec_helper.ri` becomes Create in M1. Item 3 says `grant.ri` is
  deleted in M0; `ricord.ri` replaces it (item 18). M0's `bin/test` runs only
  the probes and refused fixtures.
  Every top-level path gets a disposition: `lib/` (vendored Crystal shards)
  Delete, `build/` Delete (and in `.gitignore`), `examples/` other than
  `tape_web` Delete.

### [F2] IR-2: after-commit dispatch left open
* **Edit:** M2 item 2 specifies both variants:
  * proc: `CommitItem` has `dispatch : Proc(Tx, Int64, Int32, Nil | Error)`,
    filled with `->Court.__after_commit(Tx, Int64, Int32)`;
  * fallback: `CommitItem` has `model : Int32` (`MODEL_ID`), and
    `Ricord.models(Court, Room)` in the application generates
    `Ricord.__dispatch(model, tx, key, method)` as a `case` over `MODEL_ID`;
    the application calls it once at the top level of its main file.
  M0 item 15 records which one passed in `.ris-version`'s notes (see F7).

### [F3] IR-3: store and error structures underspecified
* **Edit:** M1 item 3 lists types: `values : Array(Value)`,
  `changed : Array(Bool)`, `flags : Array(UInt8)` (bit 0 persisted, bit 1
  destroyed, bit 2 loaded-from-group, bits 3-7 loaded associations by index
  < 5, the rest in `links`), `scopes : Array(Int32)` (index into
  `scope_pairs`, -1 none), `scope_pairs : Array({String, Value})` with a
  `scope_starts : Array(Int32)`, `groups : Array(Int32)`,
  `links : Array(Int32)` and `link_ranges : Array(Int32)` (start, length per
  record and association). Helpers: `slot(index, col) : Value`,
  `set_slot(index, col, value)`, `flag?(index, bit) : Bool`, `set_flag`.
  M1 item 2 lists each error's fields: `table`, `operation`, `message`
  (≤240 bytes), plus `id : Int64 | Nil` (`RecordNotFound`, `AfterCommitError`),
  `column` (`ScopeError`), `callback` (`CallbackError`), `code` (`DatabaseError`).

## PROPOSE FIX: majors

### [F4] CD-5, IR-4 (part): `mutexed?` must be guarded, not only its test
* **Edit:** item 11a: the method `mutexed?` is compiled only for libsqlite3
  (it returns false on libturso), not only skipped in the test.

### [F5] CD-6: `CommitItem` used in M1 before M2 defines it
* **Edit:** M1 item 6 creates `ricord/commit_queue.ri` with the flat
  `CommitItem` struct; M2 item 2 fills in the run logic.

### [F6] CD-8: `examples/tape_web/ris.mod` breaks in M0
* **Edit:** M0 excludes `examples/` from `bin/test` until M5, and item 7
  removes the example's pg `replace` line and renames its require to
  `github.com/priit/ricord`.

### [F7] ST-2, IR-Nit, CD-13: `.ris-version` format and the compiler path
* **Edit:** item 8 defines key=value lines: `ris_path=~/contribute/ris1`
  (ris1, ris2 or ris3, never `~/contribute/ris`), `ris_commit=`,
  `turso_version=v0.8.3`, `turso_commit=`, `dispatch=proc|models`.
  `bin/test` reads `ris_path` instead of its current default. Item 10 writes the
  Turso lines.

### [F8] ST-4, CD-3 (valid part): Turso CI not blocking, and the workflow
* **Edit:** item 18 names `.github/workflows/test.yml` (Modify): replace
  `RIS_REF` with `.ris-version`, drop PostgreSQL, add a SQLite job (required) and
  a Turso job (`continue-on-error: true`). M4 gets an item "make the Turso job
  required". Verification says the same.

### [F9] CD-9: Turso savepoint semantics not probed
* **Edit:** probe 11 adds: an error inside a nested write followed by
  `ROLLBACK TO` keeps the outer write usable (COMPAT.md says a dropped write makes
  the transaction rollback-only); `SAVEPOINT` while a statement is active
  returns busy. Risks: "On Turso, a failed nested write may force the whole
  write to roll back; `write_test` runs on both engines and records the gap."

### [F10] IR-7, IR-8, IR-10, CD-11, CD-12: missing signatures and references
* **Edit:**
  * M1 item 8: return types reference the Technical Plan's "Return types" table
    by name.
  * M1 item 6: the log hook is `Session#statements : Array(String)` when
    `log: true`; the warn threshold is the constant `Ricord::READ_HOLD_WARN = 100.milliseconds`.
  * M3/M4: a load group is all records read by one query or one `each` batch
    (at most `batch_size`); `to_json(into:)` and `joins(:assoc)` get one line each.
  * M0 item 7: sqlite pinned at v0.1.0, aliases `as db`/`as sqlite`; db v0.3.1's
    `Db.open` (db/core.ri:290) is the call, written `Db.open`, not `Db::Db.open`.
  * M5: the example uses `Factory.with_handler(config)` (web/web/server.ri:46).

### [F11] ST-1, CD-10: tag wording
* **Edit:** "Tag commit `012c71b3`, the last commit with `Grant::Base` code, as
  `grant-base-final`." `port/` (28 tracked files) is kept by the tag; untracked
  logs in it are not, and the item says so.

### [F12] ST-5 and nits
* AGENTS.md bullet as a list (ST-5); drop the duplicate done rule (ST nit);
  full sentences at 912 and 962; drop "It checks four things:"; name
  `Ricord::Dialect` at 1027; paths for `RIS_GRANT_SPEC.md`; expand "iyi
  III.1.7"; README "under 80 lines"; remove "*Drafted with EGM*"; `design_draft.md`
  marked already absent; `RICORD_SPEC.md` via `git mv`; signatures for
  `copy_to(store)` and `keyset_after(columns, values)`.

## DECLINE

* None.

## Decisions (2026-11-07)

* **E1 (replaced):** the engine is chosen per URI at run time (`sqlite3://`, `turso://`); one
  program can use both. libturso is built static with its symbols renamed to `turso_*`; the
  sqlite driver gets two bindings from one macro and two schemes (v0.2.0).
* **E2:** applied as proposed (2× one batch; within 5 % after 1,000 vs 100 requests); the
  author may change the numbers.
* **E3:** applied as proposed (M0 commits in `rispacks/grant`; item 19 renames afterwards).
* **C1, C2:** contested / already absent.
* **F1-F12:** applied.

Round 1 is not clean (Blockers raised). The loop continues with round 2 on request.

## Round 2 (2026-11-07, reviewers via `claude-info`, Opus low)

Reports: scratchpad `rounds/r2_*.md`. Not clean: 2 Blockers (wrong `Db.open` and `LOG`
citations), about 15 Majors. All fixed in the document:

* db citations (`db/db/db.ri:37`, `db/db/core.ri:43`); driver `ris.mod` to db v0.3.1.
* Tag: the parent of the M0 deletion commit.
* `commit_queue.ri` Modify in M2; `CommitItem` gets `depth`, nil key -1, kind mapping, a
  rollback-capable dispatch signature and the depth-limit behaviour.
* libturso build recipe (nm → rename map → objcopy, link flags); **decided fallback:**
  single-engine `-Dturso` build if the static rename fails.
* Driver refactor: `sqlite_lib` macro, `SQLite3Driver(L)`, `L::FULL`, two `register_driver`.
* REGEXP parity check in probe 11.
* `Session#request` moved to M1.
* Full `Ricord::Dialect` signature block; `Ricord::Turso` forwards to `Ricord::Sqlite`.
* Store: `models`, `starts`, `link_starts`; scope pairs by column index; text never reclaimed.
* Query API signature table; `MODEL_ID` by declaration order.
* Validation/callback syntax and messages; `json_field` types and error behaviour.
* Measurable M3/M4 goals; web change stays in the example app.
* `ris fmt --check` / `ris check` named; style nits.

## Author decision (2026-11-07): old test scenarios

* The 357 old test files are still deleted in M0 (they call `Grant::Base`), but their scenarios
  are ported: M0 writes `doc/TEST_PORT.md` (port/defer/drop per file, target test and
  milestone); M1-M4 are not done while they have open `port` rows.

## Round 3 (2026-11-07, `claude-info`, Opus low)

Reports: scratchpad `rounds/r3_*.md`. Not clean: 2 Blockers (the `model` macro given only as a
feature list; query state vs. the store), about 15 Majors. Fixed in the document:

* Query state: `wheres`/`binds`/`orders` in the store as an append-only linked node list; a
  query holds its last node, so copies stay independent; `or_where` semantics.
* `model` expansion sketch for a two-column model; typed `where` keywords; `SCHEMA.create_sql`.
* `sql.ri` signatures; full `ColumnOptions`; `begin_write` is the one source of `BEGIN IMMEDIATE`.
* Errors: trait `Ricord::Failure` vs. union `Ricord::Error`; `Rollback` role; messages; `from`.
* Session signatures and a read/write transaction state table.
* One dispatch signature for both variants; missing `Ricord.models` is a build error;
  "write depth" vs. "chain depth" named; M2 item 3 split into bullets.
* M3: group-load and `has_many`/`includes` SQL, link filling, scope propagation, `dependent:` modes.
* M4: nullable order columns refused for `each`; `offset` with `each` refused by type.
* M0: libturso keeps backup bindings (`dump` errors on Turso) and binds `create_function_v2`;
  all `sqlite3_*` symbol classes renamed, checked with `nm`; new probe 16a (lib macro, generic
  over a lib module, escape fixture) with a two-class fallback; db v0.1.1 → v0.3.1 stated; CI
  resolves the compiler by `ris_commit`; `TEST_ADAPTERS` loop; `bin/test` runs fmt/check.
* Style: duplicate lists removed, memory bound stated once, item template nits.

## Round 4 (2026-11-07, `claude-info`, Opus low)

Reports: scratchpad `rounds/r4_*.md`. Not clean: 2 Blockers (the `Query`/offset type split;
`DBError` has no result code), about 15 Majors. Fixed:

* `Court::OffsetQuery` defined in M1 item 8 (methods and return types); M4 refers to it.
* `DatabaseError.from` reads `code` from `::Sqlite::SQLite3Error`, -1 otherwise; raw SQL errors
  use `table = ""`.
* Driver: full `LibSQLite3.` → `L.` sweep, type references, `REGEXP_FN` alias; empty `Bytes`
  unchanged on SQLite; `-Dturso` fallback mode specified; sqlite v0.2.0 pinned, 11a first.
* CI fetches `rislang/ris` at `ris_commit`; all PostgreSQL remnants in `bin/test` named;
  example `ris.mod` given in full; `doc/BRAINSTORM.md` kept; `docs/` removed; link check.
* Where-node SQL templates; order nodes own columns only; `read_row` by `COLUMNS` position.
* Session paragraph as bullets; state table cell fixed; `commit_queue.ri` Create in M1.
* Dispatch maps key/kind to each user signature; chain limit 0-7.
* Zero values per type; unset non-null column sends NULL.
* Scope column mapping decided at compile time.
* Memory goal measured by `VmHWM`/`VmRSS` (RIS_TAPE_STATS has no peak counter).
* `TEST_PORT.md` header, `done` marker, `bin/test` check.

Round 5 is the last round under the cap; the loop cannot converge (two clean rounds) before it.

## Round 5 (2026-11-07, `claude-info`, Opus low): cap reached

Reports: scratchpad `rounds/r5_*.md`. Not clean: 4 Blockers (`REGEXP_FN`/callback types
misplaced; wrong `SQLite3Error` path; `Value` had no BLOB form; no home for the association
"loaded" bit), about 15 Majors. All verified against the code and fixed:

* Callback types hoisted from the lib block (`core.ri:143-145`), `REGEXP_FN` re-typed
  (`:204-209`); `create_function_v2` callback shape; lib-export rule (`core.ri:6`) and probe 16a.
* `import sqlite/errors::{SQLite3Error}`; open failures pass the driver's `DBError` through.
* `Ricord::ByteSpan` and store `bytes`; `bind` takes the dialect and uses `write_time`.
* `link_ranges` start -1 = not loaded; `ErrorEntry`, `QueryState` structs; session `dialect`.
* `LibTurso` carries `ldflags: "-lpthread -ldl -lm"` (ris adds no flags itself).
* `bin/test`: every PostgreSQL range, `RIS` from `.ris-version`, per-slot `RICORD_DATABASE_URL`.
* build-turso paths and `nm -u` check; fallback mode via `Ricord::TURSO_ONLY` and
  `turso_mode=single`; dispatch variant via `-Ddispatch_models`.
* After-commit write opened once, by `run_after_commit`; full validation messages.
* Multi-hop join scope mapping; M4 goal as three criteria, method in `memory_test`.
* `TEST_PORT.md` literal layout; style nits.

**Loop result:** 5 rounds, cap reached without two consecutive clean rounds. Blocker counts by
round: 5, 2, 2, 2, 4. Recent blockers were deeper detail (types, citations), not design
direction. Further rounds are the author's call.

## Round 6 (2026-11-07, past the cap at the author's request)

Not clean: 5 Blockers (driver `Statement`/`ResultSet` not generic; `driver_name` hard-coded;
test URL contradiction; `Tx`/`Session` type mismatch in dispatch; no `write`/`Tx` signatures),
about 15 Majors. All verified and fixed: all four driver classes take `L`, `L::NAME`; macro
expansion and both calls written out; `create_function_v2` and Turso backup bindings dropped;
in-memory URIs via the existing `filename`; driver release gate; `Ricord::Db = Session | Tx`,
`Tx` fields, `write` signature (returns the failure, incl. `Rollback`); shared `TxState`;
`QueryState` single field list incl. `includes`/`joins`; `Ricord::Skip`; string binds stored as
spans; time read/write path via the dialect; chain-depth propagation and loop order; user
callback signatures; `bin/test` remnants, refused build command, probe order, fallback skips;
tag holds the design only; group-load chunking; timestamps; JSON setters.

## Round 7 (2026-11-07): paused, not applied

Reports: scratchpad `rounds/r7_*.md`. 3 Blockers (the `fallback:` skip does not match how
`ris test --json` reports skips; CI cannot resolve the `replace ../db`/`../sqlite` paths or build
libturso; M0 probes and fixtures use Ricord code that M1 creates), about 20 Majors. The loop is
paused for the author's decision: blocker counts per round 5, 2, 2, 2, 4, 5, 3, each round new.

### Round 7 fixes (author chose: fix blockers and key majors, then stop)

* No run-time skips: in `turso_mode=single` `bin/test` leaves `two_engines_test` out; probes
  run with `ris test --json`; empty test set allowed in M0.
* CI: sibling checkouts at their tags, binutils and rustup, `vendor/turso/lib` cached by
  `turso_commit`.
* M0 probes and fixtures use local stand-ins (`ProbeStore`, `ProbeRecord`); M1 rewrites them
  and recaptures `# expect:`; an undefined-name refusal never counts.
* Link order: separate `@[Link(ldflags:)]` so system libraries follow `-lturso`; probe 11
  checks the link line.
* Full `CommitItem` and the dispatch flag in M1; one write-depth definition; one user
  callback signature table; `after_rollback` runs on savepoint rollback too, discarded after
  COMMIT.
* Store `joins`; raw SQL bind types; M4 signature table; test cases for the M2/M4 tests;
  `bin/test` Modify items in M2 and M5.

**Review closed (2026-11-07)** after 7 rounds without convergence. Remaining detail (citation
drift, minor types) is left to the M0 probes and M1 code.
