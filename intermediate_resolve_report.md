Status: resolved (2026-11-07)

# Goldfish Annotated Review Report: Stage 8 resolution

**Target:** `doc/DESIGN.md` (full file, 1-1207)
**Source:** `intermediate_zoom_out_report.md` (findings 1-12)

## ESCALATE: these need the author's decision

### [Issue 6] `egm-zoom-out` - Severity: Major. Scope inheritance machinery
* **Affected Scope:** 132-135, 509-521, 785, 1110-1117, 1121-1123
* **Discrepancy Description:** Per-record `scopes`, a scope-pair table, join and
  subquery conditions, scoped bulk writes and `ScopeError` are heavy for a
  convenience, since isolation comes from the file per account.
* ***AI Suggestion:*** ESCALATE.
* ***Justification:*** Scope inheritance is a goal the author set
  (`doc/BRAINSTORM.md:210`, F13 at `:388`), from experience with
  `activerecord-multi-tenant`. Cutting it is the author's call. Options:
  * **(a) Keep it all.**
  * **(b) v1 = association foreign-key condition + `create`/`build` defaults.**
    Defer joins/subqueries, scoped bulk writes, `scopes` slots and `ScopeError`
    to Future Improvements.
* ***Proposed Edit (if b):*** Goals 132-135, Technical Plan 509-521, store
  fields, errors table, M3 items 1-3 and `scope_test` shrink to (b).

### [Issue 1] `egm-zoom-out` - Severity: Major. Turso first adds a build chain
* **Affected Scope:** 34-36, 152-154, 174-178, 579-582, 668-675, 756-758; M0 9-11, 18
* ***AI Suggestion:*** ESCALATE (engine order) + PROPOSE FIX (two gaps).
* ***Justification:*** "Turso first" is an author decision recorded in the
  walkthrough (`goldfish_review_report.md`, "Engine") and `doc/BRAINSTORM.md:371`.
  Options:
  * **(a) Keep Turso first.**
  * **(b) Build M1-M4 on libsqlite3, run the Turso probe as a parallel
    non-blocking job, switch the default when it passes.**
  The two gaps are valid either way: Alternative H has no technical reason for
  rejection, and the file-compatibility cost (agreed in the walkthrough) is
  missing from Risks.
* ***Proposed Edit (always):***
  * Risks: add "**Account files are Turso files:** `sqlite3` tools and
    Litestream may not read them once `numeric` or MVCC is used. v1 uses
    neither; the M0 probe checks that `sqlite3` reads a Turso-written file."
  * Alternative H reason: the author's technical reason (needed from you:
    e.g. `BEGIN CONCURRENT` for many writers, CDC for `track_changes`).

### [Issue 2] `egm-zoom-out` - Severity: Major. Two dialects for one SQL dialect
* **Affected Scope:** 325, 574-582, 982-986
* ***AI Suggestion:*** ESCALATE, tied to Issue 1.
* ***Justification:*** The critique is technically right: both "dialects"
  differ only in features v1 does not use. But naming the engine in the type
  follows the author's Turso-first choice.
* ***Proposed Edit (if accepted):*** One `Ricord::Dialect::Sqlite` (SQLite SQL
  dialect); the engine (libturso or libsqlite3) is a link-time setting
  (`RICORD_ENGINE`). Diagram line 325, Dialect section 574-582 and M1 item 4
  change accordingly. The trait stays for PostgreSQL.

## CONTEST

### [Issue 3] `egm-zoom-out` - Severity: Major. `:json` and `:binary` past F11
* **Affected Scope:** 179-180, 476-484; M1 8-9; M2 `json_field`; M0 14
* ***AI Suggestion:*** CONTEST.
* ***Justification:*** The reviewer's premise is wrong. F11 as recorded in
  `doc/BRAINSTORM.md:385` is "`:json` is `Ricord::Json` (`settings[:theme]`,
  `json_field`); `:binary` is `Ricord::Blob`", not "String getters". The design
  matches it. (If you now prefer `String` in v1, say so and it becomes a fix.)

## PROPOSE FIX: majors

### [Issue 4] `egm-zoom-out` - Severity: Major. Nothing enforces `db.release`
* **Affected Scope:** 233-235, 377-388, 761-762, 998-999, 1049-1050, 1161
* ***AI Suggestion:*** PROPOSE FIX (keeps F1 = a).
* ***Justification:*** F1 kept the shared read; the reviewer's structural
  release is compatible with it.
* ***Proposed Edit:***
  * Reads section, "Before waiting": "`request` ends the read transaction when
    its block ends, and the web adapter calls `db.release` before writing the
    response, so an app calls it only before its own external I/O. With
    `log: true`, a read transaction held longer than 100 ms is logged at warn
    level with the statements it covered."
  * Risks 761-762: mitigation names the adapter, `request` and the warn log.
  * M1 item 6 and `read_tx_test`: add "`request` releases on exit; a long hold
    is logged".
  * M5 item 1: the adapter calls `release`; handlers no longer do.

### [Issue 5] `egm-zoom-out` - Severity: Major. `after_rollback` unspecified
* **Affected Scope:** 119-120, 423, 437, 1081
* ***AI Suggestion:*** PROPOSE FIX (keeps E4, which named `after_rollback`).
* ***Proposed Edit:*** After-commit section, "On rollback": "`after_rollback`
  methods run after the outermost `ROLLBACK`, outside any write, once per
  queued item, in queue order. A `ROLLBACK TO` (a nested write) only drops the
  items queued at that level. Like `after_destroy_commit`, an `after_rollback`
  method is a class method `def self.m(db : Ricord::Session, id : Int64 |
  Nil)`: the row may not exist, and `id` is nil for a rolled-back create."
  M2 item 2 and its test get the same rule.

## PROPOSE FIX: nits

### [Issue 7] Store fields - PROPOSE FIX
* Store list (445-457) and M1 item 3: keep `links`, drop `link_ranges` if
  `belongs_to`/`has_one` need one slot each (one link per record and
  association: `links` indexed by record and association number); add the
  scope-pair table (if Issue 6 = a).

### [Issue 8] Turso foreign keys - PROPOSE FIX
* M0 item 11: add "`foreign_keys=on` with `on_delete: :cascade` and `:restrict`
  enforced".

### [Issue 9] Destroy dispatch signature - PROPOSE FIX
* Line 429-430 and M2: `def self.cleanup_files(db : Ricord::Tx, id : Int64)`,
  since each item runs in its own write.

### [Issue 10] M0 tag commit - PROPOSE FIX
* M0 item 1: "Git tag `grant-base-final` on `main` at `012c71b3`, the last
  code change".

### [Issue 11] "Answers" wording - PROPOSE FIX
* Replace "answers" (meaning returns) with "returns" throughout; remove the
  glossary entry.

### [Issue 12] Repeated weeds - PROPOSE FIX
* Errors section 544-546: drop the 240-byte and `…` details; keep them in M1
  item 2.

## Decisions (2026-11-07)

* **1+2:** both engines. `Ricord::Sqlite` (default, required CI job) and `Ricord::Turso`
  (thin layer over it, libturso v0.8.3, non-blocking CI until M4); engine chosen at link time.
  New M0 item 11a changes the sqlite driver for libturso. Alternatives R1 and R2 added.
* **3:** contest accepted; `Ricord::Json` and `Ricord::Blob` stay.
* **6 = (a):** scope inheritance stays in full.
* **4, 5, 7-12:** applied as proposed.
