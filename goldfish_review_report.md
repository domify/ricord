# Goldfish Annotated Review Report

**Target:** `doc/DESIGN.md` (FeatureRange 1-907; detailed-plan items are
noted where a fix reaches them).
**Sources:**
* `zoom_out_report.md` (Z*, C*): stage 5;
* `comprehension_report.md` (U1-U18): stage 6;
* `critic_report.md` (design-1-*, structural-1-*, style-1-*): stage 7.

Findings that two or more reports raise are merged. The other ids are listed
under "Also".

## ESCALATE: these need the author's decision

The reviewers argue that each of these items is out of scope (YAGNI) for the
first version. Each one touches a decision the author made in conversation,
so the agent does not change them on its own.

### [E1] Z5 `egm-zoom-out`: Major. Schema metadata for migrations

* **Affected Scope:** 111-121, 181, 1155-1156
* **Discrepancy:** `SCHEMA`, `index`, `foreign_key`, `check_constraint` and the
  index and foreign key that `belongs_to:` adds only feed migrations, and
  migrations are a non-goal.
* ***AI Suggestion:*** ESCALATE.
* ***Justification:*** The author chose the `col` vocabulary because it can
  feed migrations later. Two choices:
  * **(a) Keep everything.**
  * **(b) Parse everything, emit less.** `col` and its options are parsed and
    checked, because getter types need `null:` and `default:`. `SCHEMA` holds
    them. The `index`, `foreign_key` and `check_constraint` lines, and the
    index and foreign key of `belongs_to:`, are accepted and stored in
    `SCHEMA`, but nothing emits them until migrations exist.
* ***Proposed Edit (if b):*** The Goals and M1 macro bullets say "stored in
  `SCHEMA`; emitted by the later migrations".

### [E2] Z6 / design-1-9 `egm-zoom-out`, `egm-design`: Major. Cross-database writes

* **Affected Scope:** 93-96, 443-448, 1371-1374
* **Discrepancy:** CUJ 6 needs only `Membership[account_db].create`. It needs
  neither `save(db: other)` (and its refusal rule) nor `copy(db: other)`. The
  "same database" identity is also undefined.
* ***AI Suggestion:*** ESCALATE. The agent proposes dropping both from v1.
* ***Proposed Edit:*** Remove `save(db:)` and `copy(db:)` from Goals, the
  Technical Plan and M4, and list them under Future Improvements. CUJ 6 stays
  as it is: a create through another session, which needs no special API.

### [E3] Z7 `egm-zoom-out`: Major. Group loading for `has_many`

* **Affected Scope:** 153-160, 549-562, 1328-1354
* **Discrepancy:** Group loading for `has_many` needs `links`/`link_ranges` and
  an "empty loaded" state. No CUJ needs it, and `includes` covers it.
* ***AI Suggestion:*** ESCALATE. The agent proposes group loading for
  `belongs_to` and `has_one` only in v1, and `includes` for `has_many`.
* ***Proposed Edit:*** Narrow the Goal and the M3 readers. `has_many` group
  loading goes under Future Improvements, to be revisited if the ct port shows
  `has_many` N+1 queries.

### [E4] C3 `egm-inventive-catalyst`: Major. An optional durable after-commit

* **Affected Scope:** 466-468, 774-791
* **Discrepancy:** A crash between COMMIT and the after-commit run loses the
  work. The reviewer proposes `after_commit :m, durable: true`, backed by an
  outbox row.
* ***AI Suggestion:*** ESCALATE. The agent proposes recording the loss in the
  new Risks section and `durable: true` under Future Improvements, without
  building it now.

## PROPOSE FIX: blockers

### [F1] design-1-1 + Z8 + U9: Blocker. The shared read transaction conflicts with `BEGIN IMMEDIATE`

* **Affected Scope:** 272-273, 356, 402-425, 1380-1382
* **Discrepancy:**
  * **Nested `BEGIN`:** SQLite refuses a `BEGIN` while a transaction is open,
    so CUJ 1 (read, then save) fails.
  * **No release:** Campfire's `release` and the panic rollback in `enter` are
    missing. A parked request pins a WAL snapshot.
* ***AI Suggestion:*** PROPOSE FIX.
* ***Justification:*** The shared read transaction is an optimisation, and no
  measurement shows it is needed.
* ***Proposed Edit:***
  * **What `request` is:** "a child session on the same connection with a fresh
    store". It holds no transaction.
  * **Reads:** each read runs in SQLite autocommit.
  * **The shared read transaction:** moved to Future Improvements, with what it
    needs: release before I/O, the rollback in `enter`, and ending it before
    `BEGIN IMMEDIATE`.
  * **The `reading` flag:** removed.

### [F2] design-1-2 + structural (blocker): Blocker. No Risks & Mitigations section

* ***AI Suggestion:*** PROPOSE FIX.
* ***Proposed Edit:*** Add `## Risks and Mitigations` before the NFRs. Each risk
  gets an impact and a mitigation, or "accepted":
  * a panicked write leaves its transaction open: the next write rolls it back;
  * store growth on text rewrite: accepted, because the store lives for one
    request or one batch;
  * raw SQL is scoped on the main table only: on SQLite the file per account
    isolates;
  * write contention on one account file: `busy_timeout` and WAL, see F9;
  * descriptor and open cost with many account files: one open per request,
    measured in M4;
  * schema drift across account files: comes with migrations, and is accepted
    until then;
  * a crash loses after-commit work: accepted, see E4;
  * a long `dependent: :destroy` holds the write lock: use `:delete_all` for big
    trees (design-1-10);
  * the compiler changes under the pin: `.ris-version` and probes run first;
  * cross-file references cannot have foreign keys (design-1-14): accepted.

### [F3] structural-1-1: Blocker. "Rejected by author" with no link

* ***AI Suggestion:*** PROPOSE FIX, after a CONTEST of half the finding.
* ***Justification:*** The EGM draft skill tells the drafter to write "Rejected
  by author: [technical rationale]" (egm-draft SKILL, Step 4.3). The ban covers
  attributing a rejection to a maintainer without a link. The reviewer is right
  about one thing: the record behind the decisions, `concepts_brief.md`, is
  untracked.
* ***Proposed Edit:*** Move `concepts_brief.md` to `doc/BRAINSTORM.md`, commit
  it with the design, and have every "Rejected by author" cite
  `doc/BRAINSTORM.md`. Each reason already leads with its trade-off, so keep it
  that way.

## PROPOSE FIX: majors

| Id | Finding | Proposed edit |
|---|---|---|
| **F4** Z2/U1 | `Value` holds `String` in M1 but `String::Span` in the plan | M1 uses `String::Span` in the slot and `String` only at getters and setters |
| **F5** C2/U2 | CUJ 7 relies on `copy_to(owner)` | CUJ 7 writes into a caller-owned `String::Builder` and `Array(String::Span)`, through `pluck(:name, into: builder, spans)`, so it works today. `copy_to(Program.tape)` stays for one-shot tools |
| **F6** Z1/U3 | after-commit carries a destroyed record's values | `on: :destroy` receives only the key, as Campfire does. The method is a class method `def self.cleanup(tx, id)` |
| **F7** C1/U4 | streaming `each` vs load groups | One batch store per page of `batch_size` holds the records, their group and the preloads. Memory is bounded per batch. CUJ 5 and the memory test say "per batch", and a `test/refused` case keeps a record past its batch |
| **F8** design-1-6 | after-commit dispatch and its errors | **Dispatch:** the macro generates `self.__after_commit(tx, key, method)` per model, and the queue item holds a non-capturing proc to it. An M0 probe checks that ris allows this. If not, the fallback is an application list `Ricord.models(Court, Room)`. **Errors:** a new error `Ricord::AfterCommitError` means "committed; after-commit failed", and `db.write` and a lone `save` return it. **Nesting:** items queued by after-commit work run in the same drain, up to depth 8 |
| **F9** design-1-7 | pragmas never set | `Ricord.open` appends `journal_mode=wal`, `busy_timeout=5000` and `foreign_keys=on` to the URI, unless the URI sets them. The sqlite driver reads pragmas from the URI (`sqlite/core.ri:621-656`) |
| **F10** design-1-3 | CUJ 1 skips `request` | CUJ 1 uses `global.request { \|db\| }`. A note says the per-request account file needs no `request` |
| **F11** design-1-4 | `Value` lacks decimal, binary and json | v1 stores `:decimal`, `:json` and `:binary` as text spans, and the getter answers `String` (exact text, or bytes for binary). A `Decimal` type is future work |
| **F12** design-1-5 | `each` vs `order`, `limit`, `offset` | `each` pages by keyset on (order columns, primary key). `limit` caps the total, and `offset` with `each` is a compile error |
| **F13** design-1-8 | scope overwrite | Saving a record whose scoped column changed answers `ScopeError` (a new error type) |
| **F14** Z3/U5 | Grant and Ricord names mixed | Undo the rename where text describes today's Grant (`Grant::Base`, `Grant::Connections`, `Grant HEAD`). Savepoints become `ricord_<n>`, and "Grant issues SQL" becomes "Ricord" |
| **F15** Z4 | statement log in M1 vs M4 | Move the log to M1 |
| **F16** U6 | `!` undefined | One sentence at its first use: "postfix `!` returns the error from the enclosing function (iyi III.1.2); it is not part of a name" |
| **F17** U7 | terms undefined | Add a `## Glossary`: tape, owner, `@[OnTape]`, round, `Program.tape`, iyi, ris1-3, `DBValue`/`DBError`, `String::Builder`/`String::Span`, `RIS_TAPE_STATS`, minitest, EGM. Each SPEC number cited gets a one-line gloss |
| **F18** U8 | db versions | One sentence: v0.2 removed pools and made connections block-scoped, and v0.3.1 (pinned) changed only `read_tape` |
| **F19** style-1-1/U10 | non-goal title | Retitle it "Isolating accounts inside one shared SQLite file" |
| **F20** structural-1-2/U14 | alternative letters | Re-letter A-P in order, and move N and O inside the Alternatives section |
| **F21** structural-1-3 | milestones undefined in range | Add a six-row milestone table to the Overview |
| **F22** structural-1-4 | headings | Promote "Additional Resources" and "Future Improvements" to H2 |
| **F23** structural-1-5/N5 | Open Questions mixes in answers | Move the answered items to `### Verified constraints` in the Technical Plan. Probes cite their scratch files as manual runs, which M0 turns into tests |
| **F24** style-1-2 | caveat in the Problem | "Not checked: `tape_model.ri` is replaced in M1" |
| **F25** style-1-3/U17 | "documented" says no place | Point to `doc/GUIDE.md`, section "Isolation" |
| **F26** style-1-4 | `save` bullet duplicated | Merge the two |
| **F27** style-1-5 | cost claims unsupported | "weeks" → "the 25,000 lines of Base, most of which cannot be written under SPEC 1.1/3.2/5.1"; "double" → the list of what differs; the Turso claims cite the July 2026 Register article and Turso's March 2026 post |
| **F28** C4 | the SlicePool alternative was not weighed | Add Alternative Q: "records own slices from a store-owned SlicePool", not probed, with flat columns kept for one-pass rows |

## DECLINE or small fixes (nits)

* **Applied as one-line fixes:**
  * U11/N1: the probe "four things", adding the `Tx` as `db:`;
  * U12: the fixture is "Modify";
  * U13: line 1046 and M1's DESIGN.md step;
  * U15: goal sentences for M2-M5;
  * U16: why after-commit runs in a write;
  * U18: write depth vs savepoint counter;
  * design-1-11: cite the code commit before `221bd212`;
  * design-1-12: `bin/test` asserts a non-zero exit and the `# expect:` text;
  * design-1-13 and N3: the 240-byte cap includes the prefix, and a cut ends in
    `…`;
  * design-1-14: covered in F2;
  * design-1-15: the `Array#run` note;
  * design-1-16: covered in F2;
  * style-1-6 to style-1-11 and style-1-14: wording;
  * style-1-13: cite the method name instead of `:664`;
  * N7: `batch_size` is a tunable default;
  * C6: covered in F10.
* **DECLINE:**
  * structural-1-6/7/8/9/11/13 (formatting), done only where an edit touches
    those lines anyway;
  * structural-1-10 (citations of a spec that will be rewritten): M5 rewrites
    `RIS_GRANT_SPEC`, so the number stays;
  * structural-1-12 (lead with the user problem): kept as written;
  * N4 (add store fields per milestone): kept as one list;
  * N6 (code-like wording in Goals): moved only where F4 touches it;
  * style-1-12 ("answers"): replaced by "returns" throughout.

## Decisions from the interactive walkthrough (2026-11-06)

* **E1 = (a):** Ricord generates `create_sql` from models: tables, indexes,
  foreign keys and checks. `ALTER` stays with the later migrations.
* **E2 = (b):** no `save(db: other)` or `copy(db: other)` in v1.
* **E3 = (b):** group loading covers `belongs_to` and `has_one`. `has_many`
  uses `includes`.
* **E4:**
  * **Ricord v1:** Rails callback names (`after_commit`,
    `after_create_commit`, `after_update_commit`, `after_destroy_commit`,
    `after_save_commit`, `after_rollback`). There is no `durable` option.
  * **A later job package:**
    * the ActiveJob API: `job`, `perform_later`, `perform_now`,
      `set(wait:/wait_until:)`, `queue_as`, `retry_on`, `discard_on`;
    * records passed as model and id (GlobalID);
    * the job row written in the same transaction, in the account's file;
    * a RisBoard notice after COMMIT, and a sweep at startup.

    ct-ruby already does this on PostgreSQL (Solid Queue in the same
    database, `enqueue_after_transaction_commit = :never`).
* **F1 = (a):** the shared read transaction stays.
  * A write first ends the read transaction with `COMMIT`. The next read opens
    a new one.
  * `db.release` ends it before a request waits, called by the web
    integration or the app.
  * `request` rolls back a transaction a panicked request left open.
* **F5 (doc fix):** the rule is to do the work inside the block.
  * **What leaves the block:** single values (numbers, text, tuples) leave as
    the block's result.
  * **Lists:** a caller-owned array or builder, through `concat` or `into:`.
    These helpers go in an appendix.
  * **Records:** never leave.

  Probes: `concat` of Int64 into an outer array works; assigning a
  block-made array to an outer variable is refused; returning a String works.
* **F6 = (a):** `after_destroy_commit` methods are class methods that receive
  `(db, id)`.
* **F7 = (a):** one store per `each` batch, holding the records, their group
  and the preloads.
* **F8 = (a):**
  * every after-commit item runs, and each error is logged (as Campfire does);
  * the caller gets `Ricord::AfterCommitError`, which carries the record id and
    the first error, so it can tell that the data was saved.
* **F9 = (a):** `Ricord.open` sets `journal_mode=wal`, `busy_timeout=5000` and
  `foreign_keys=on` unless the URI sets them.
* **Engine: Turso first, SQLite later.** This replaces "SQLite only".
  * **The M0 probe:** build `libturso`, link the ris sqlite driver against it,
    run the driver tests and Ricord's M0 probes, and try `numeric(P,S)` and
    `BEGIN CONCURRENT`.
  * **The fallback:** if the C API has gaps, record them and decide whether to
    write a Turso driver or start on SQLite with the same design.
  * **The cost:** account files become Turso files. SQLite tools may not read
    them once `numeric` or MVCC is used.
