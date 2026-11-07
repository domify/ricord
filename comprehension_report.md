# Comprehension report: doc/DESIGN.md

Stage 6 (Comprehension Test). Reviewer: egm-comprehension. It read the
document alone, with no document standard. FeatureRange: lines 1..907.
DetailedRange: lines 908..1510.

## What this proposes (FeatureRange, lines 1-907)

The document proposes Ricord, a new ORM in the style of Rails' ActiveRecord. It
would replace Grant, the Crystal ORM that was ported to ris earlier. Grant no
longer builds, because the current ris compiler has no heap: data lives on
block-scoped "tapes", and a db connection exists only inside its open block.
Ricord passes the session explicitly where a query starts (`Court[db]`,
`Court[tx]`). Each record is a small `@[OnTape]` struct holding the session, a
store and an index, so `save`, `destroy` and association readers need no
connection argument.

All row data lives in a flat per-session store. Values sit in slot arrays, and
all text goes into one `String::Builder` that records point into with
`String::Span`s. That store is freed when the `Ricord.open` block, a `request`
scope or an `each` round ends.

Writes are explicit `BEGIN IMMEDIATE` transactions. Nested writes become
savepoints, and after-commit work is a flat queue of (model id, key, kind,
method) items that run after COMMIT. Two more features cover access patterns.
Scope is inherited through associations (`account.courts`), and "load groups"
batch association reads to avoid N+1 queries. Account isolation comes from one
SQLite file per account; PostgreSQL comes later.

## How the existing system works, per this document

Grant's HEAD needs db v0.1.1, and db v0.2 removed the pool cache that Grant
uses. Most of Grant's code is a port of Rails' model class. It relies on
connection pools, global registries, caches and `after_commit` lists that hold
records, none of which the compiler allows. Models find their connection by
name in a global registry. The newer tape model still copies rows to the heap,
and it may return row text that has already been freed outside the query
block. The first user, ct-ruby, used `activerecord-multi-tenant` in Rails, and
that gem leaked rows across accounts on complex SQL.

## What the detailed range says (lines 908-1510)

The work is split into six milestones:

- **M0** tags the old code, renames the project to Ricord, deletes the Base
  stack and its tests, pins the compiler and packages, and adds probes and
  compile-fail fixtures.
- **M1** builds value, error, store, dialect, sql, session, tx and the `model`
  macro with CRUD, plus their tests.
- **M2** adds validations, callbacks, dirty tracking, timestamps and the
  after-commit queue.
- **M3** adds associations, inherited scope, preloading, group loading and
  `dependent:`.
- **M4** adds streaming `each`, pluck, bulk writes, joins, `Session#request` and
  writes to two databases.
- **M5** updates the example app and rewrites the documents and the contract.

A verification plan follows. Alternatives N and O come after the closing line
of the document.

## Findings

1. **Major, lines 476-477 vs 1061-1062: the `Value` type contradicts itself.**
   The Technical Plan defines `Value` with `String::Span`, while M1 defines
   `Ricord::Value` with `String`. Lines 217-218 and 2.2 say a stored `String`
   is refused, so the M1 definition looks wrong. If it is not, the reader
   cannot tell which type the store holds.

2. **Major, lines 141-142, 336-343 (CUJ 7) vs 219-221 and 1008-1009: `copy_to`
   contradicts itself.** The goals and CUJ 7 rely on `copy_to(owner)` to get
   data out of a session. The "answered" section and the M0 probe say
   `copy_to` works only with `Program.tape` as owner, and the probe expects it
   to fail. Line 196 mentions adding `Array#run` for `copy_to`. No milestone
   delivers a working `copy_to`, so CUJ 7 cannot be met as written, and no test
   covers it.

3. **Major, lines 458-459 vs 453-455 and 1265-1267: a destroyed record in the
   after-commit queue.** A destroyed record "runs with the values it had,
   copied into the item's store". But the `CommitItem` is described as flat
   (model id, key, kind, method index) and has no store. It is unclear where a
   destroyed record's values live and who owns them.

4. **Major, lines 154-159, 509-514, 556: load groups vs per-round stores.**
   `each` gives every round its own store, freed at the round's end, while a
   load group is a whole `each` batch. The text does not say whether a "round"
   is one row or one batch. If it is one row, it does not say where the
   group-loaded associations (for example the 50 teams in CUJ 2) are stored,
   or how they survive from one round to the next. The same question applies
   to `groups : Array(Int32)` (line 1332), which M3 adds but which is missing
   from the store field list at lines 476-487. `link_ranges` (line 1082) is
   missing from that list too.

5. **Major, throughout: Ricord and Grant names are mixed.**
   - Line 44 says Grant's lines "are `Ricord::Base`", but that is existing
     Grant code (presumably `Grant::Base`). The same mix-up appears at lines
     167, 172, 622, 633, 922 and 945, and in M5's "class < Ricord::Base".
   - Lines 424 and 770 say "Grant issues the SQL itself" when they mean
     Ricord.
   - Savepoints are named `grant_<n>` (lines 420, 1135).
   - Line 204 calls Campfire "the model for Grant's core", and the contract is
     still `RIS_GRANT_SPEC`.

   A fresh reader cannot reliably tell old from new.

6. **Major, lines 27, 282, 1048, 1416, 1427: the meaning of `!`.**
   `court.save!`, `find(42)!` and `u.team!` use `!`. The naming rule says `!` is
   never part of a name, and API_CHANGES maps "`find!` to `find`". The postfix
   error-propagation meaning is only hinted at, through "iyi III.1.2 `!`"
   (line 877) and line 573. Define it inline where it first appears (line 24),
   so that `save!` is not read as a Rails bang method.

7. **Major: project-specific terms are not defined.** Used but never defined:
   - "tape" and "owner", including "a named local, as SPEC 2.1 requires of an
     owner";
   - `@[OnTape]`, `Program.tape` and "round";
   - "ris1, ris2 or ris3" and "prelude gaps" (lines 195-196);
   - iyi: what it is, and how it relates to ris;
   - `DBValue` and `DBError`;
   - the semantics of `String::Span` and `String::Builder` (is `to_s[span]` a
     borrow?);
   - "untyped preload" (line 133);
   - "goldfish review" and EGM (line 883);
   - minitest (`ssh minitest`, line 1470);
   - `RIS_TAPE_STATS`;
   - "deferred read transaction".

   SPEC sections (1.1, 2.2, 3.2, 3.6, 5.1, 5.6) are cited by number only. A
   one-line gloss of each rule would let a reader follow the arguments without
   opening another repository.

8. **Major, lines 38, 58, 86: db versions.** v0.1.1, v0.2, v0.3 and v0.3.1 all
   appear. Line 58 explains the constraint using "db v0.3", while the pin is
   v0.3.1. The document does not say what changed between versions, or whether
   v0.3 and v0.3.1 are interchangeable here.

9. **Major, lines 402-406, 1380-1382 and CUJ 1: request scope vs writes.** The
   request's shared read transaction "closes at the first write". The document
   does not explain:
   - whether later reads in the same request get a new read transaction;
   - how CUJ 1's account-file session, opened per request without `request`,
     relates to it;
   - how a read transaction left open on the long-lived global session
     interacts with `BEGIN IMMEDIATE`.

10. **Major, line 193: an unclear non-goal.** "One-file account isolation on
    SQLite" reads as if it contradicts line 190, which picks one file per
    account. It seems to mean isolating several accounts inside one shared
    file. Say that directly.

11. **Nit, lines 1014-1018.** The probe says "It checks four things" but lists
    three.

12. **Nit, lines 1020-1025 vs 1218.** The fixture is created in M0, then listed
    as "(Create, Modify)" in M1. Only Modify applies.

13. **Nit, line 1235.** M1 "creates" `doc/DESIGN.md` from `design_draft.md`,
    but the target already is `doc/DESIGN.md`. Line 1046 also still names
    `design_draft.md` as the design.

14. **Nit: the Alternatives are out of order.** They run A-L, then P, then M.
    N and O sit after "*Drafted with EGM*" (lines 1484-1510), outside the
    Alternatives section and inside the DetailedRange. Move them back and
    reorder.

15. **Nit, lines 1241 and 1310 onward.** M2 to M5 have no goal sentence,
    unlike M0 and M1.

16. **Nit, line 298.** After-commit "reads the room again ... in a new write".
    The reason a read-and-call needs a write transaction is only implicit ("the
    method may write"). Say so.

17. **Nit, line 547.** "This is documented": the document does not say where.
    Name the target document (GUIDE.md?).

18. **Nit, line 1118.** The session has both a "write depth" and a "savepoint
    counter". The difference between them (nesting depth vs a monotonic name
    suffix) is not stated.
