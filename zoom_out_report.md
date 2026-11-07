# Goldfish Review Report (Stage 5, Initial Zoom Out)

**Target:** `doc/DESIGN.md` (lines 1-1510; FeatureRange 1-907, DetailedRange 908-1510)

## Reviewer Status

| Reviewer | Status |
| --- | --- |
| `egm-zoom-out` | completed (partial cross-check: it verified only web/server.ri and Campfire database.ri) |
| `egm-inventive-catalyst` | completed (partial cross-check: it did not read TAPE_API.md, db/core.ri, sqlite/core.ri or RIS_GRANT_SPEC.md) |

Neither reviewer checked the design's db/core.ri line citations (:264, :664) or its RIS_GRANT_SPEC 5.12/8.9 references.

Severity count: 🔴 0 Blocker (one catalyst finding is marked "near Blocker"), 🟡 8 zoom-out Major and 5 catalyst Major, 🟢 8 shared or zoom-out Nits and 2 catalyst-only Nits.

---

## Zoom-out and shared findings

### 🟡 Major

#### Z1. After-commit queue is not flat for destroyed records (both reviewers)
* **Affected Scope:** 134-138, 453-461, 1265-1267
* **Discrepancy:** `CommitItem` has only the model id, key, kind and method index. Line 458-459 says a destroyed record runs "with the values it had, copied into the item's store". That gives each item its own store, and no field for it is listed. Re-reading by id cannot work after the DELETE.
* **Recommendation:** pick one rule and state it in both places. Option one: `on: :destroy` gets only the key, as Campfire does. Option two: copy the slots into one session-level commit store before the DELETE. The item then holds an offset into it, and the store is cut back on rollback (catalyst).

#### Z2. `Value` is defined two ways (both reviewers)
* **Affected Scope:** 476-477 vs 1061-1062
* **Discrepancy:** The architecture defines `String::Span` in the slot, but M1 defines `String`. The design itself says a `String` slot is refused (217) and that the span form is what the probe verified (222-227).
* **Recommendation:** M1 follows line 477. Allow `String` only at the getter/setter boundary. If needed, use two types: a stored slot type and a user-facing type.

#### Z3. Old and new project names are mixed (both reviewers)
* **Affected Scope:** 12, 44, 56, 172, 420, 424, 770, 1046, 1135
* **Discrepancy:** The doc uses `Ricord::Base` and `Ricord::Connections` for today's Grant types (M0 deletes `grant/base.ri`, 942). It also says "Grant issues the SQL" and uses savepoints named `grant_<n>`. `AGENTS.md` still names `design_draft.md`.
* **Recommendation:** use `Grant::*` for what exists and `Ricord::*` for what is proposed. Rename savepoints to `ricord_<n>`. Fix 1046 and 1235 to match the current file layout (doc/DESIGN.md already exists).

#### Z4. Statement log is needed in M1 but delivered in M4
* **Affected Scope:** 373, 1119, 1200, 1383
* **Discrepancy:** `crud_test` (M1) checks SQL text through a statement log, and `log` is an M1 field. The log itself is an M4 item.
* **Recommendation:** move the statement log into M1, since CUJ 2's query count in M3 also needs it. Otherwise drop the SQL-text checks from M1.

#### Z5. Schema metadata serves migrations, which are a non-goal (YAGNI)
* **Affected Scope:** 111-114, 119-121, 181, 1155-1156
* **Discrepancy:** `SCHEMA`, `index`, `foreign_key`, `check_constraint`, and `belongs_to:` index/FK generation with `on_delete:`/`to_table:` exist only to feed future migrations.
* **Recommendation:** for now, `col` produces only getter types and column lists. Reject or ignore the schema-only options until a migration design exists.

#### Z6. Cross-database writes are speculative (YAGNI)
* **Affected Scope:** 93-96, 443-448, 1371-1374
* **Discrepancy:** CUJ 6 (323-334) needs neither `save(db: other)` with its refusal rule nor `copy(db: other)`.
* **Recommendation:** drop both until a port needs them.

#### Z7. Group loading for `has_many` adds a second preload path
* **Affected Scope:** 153-160, 549-562, 1328-1332, 1352-1354
* **Discrepancy:** It needs per-record `groups`, `links`/`link_ranges` and an empty-loaded vs unloaded state. No CUJ needs this, and it duplicates `includes`.
* **Recommendation:** limit group loading to `belongs_to` and `has_one`. Revisit if ct-ruby shows `has_many` N+1 queries.

#### Z8. The request's shared read transaction comes before any shown need, and it has no release point (both reviewers, different angles)
* **Affected Scope:** 356, 402-406, 1380-1382, 1396
* **Discrepancy:** Zoom-out: the deferred shared read transaction (the `reading` flag and the upgrade on first write) is an unproven optimisation. Catalyst: Campfire's source has `release` before the request parks and an `enter` rollback of a transaction a panic left open (database.ri 235-254). Ricord has neither, so a parked request pins a WAL snapshot.
* **Recommendation:** for now, keep `request` as "child session with a fresh store". If the shared read stays, port `release` (called before Ricord yields to I/O) and the `enter` rollback, and document that reads after a release see a newer snapshot.

### 🟢 Nit

* **N1. (both)** Probe `session_ref_test` says "four things" but lists three (1014-1018). The fourth is probably the `Tx` passed as `db:` (618).
* **N2. (both)** Alternatives N and O come after the "Drafted with EGM" footer (1484-1510). P sits between L and M (804). Move all three into Alternatives Considered, in letter order.
* **N3. (both)** The 240-byte error message limit is too low-level for a design (572, 1072-1073). State the reason (flat struct) and the truncation rule (keep the table and operation, cut the DBError text with a marker).
* **N4.** M1 adds the `scopes`, `links` and `link_ranges` store fields (1081), but they are first used in M3. Add each field in the milestone that uses it.
* **N5.** Open Questions (200-255) mixes more than ten settled items with the two that are open. Move the settled ones to Technical Plan as "verified constraints".
* **N6.** The Goals wording reads like code, for example the Int32 to Int64 bind conversion (108-110). Move it to the Technical Plan.
* **N7.** Nothing justifies the `batch_size` default of 1000 (512, 1364). Call it a tunable default, or tie it to the memory test bound.
* **N8.** `RIS_GRANT_SPEC.md` keeps the old name.

---

## Inventive Catalyst findings

### 🟡 Major

#### C1. Streaming and group loading contradict each other (near Blocker)
* **Affected Scope:** 155-163, 282, 314-321, 508-514, 553-556, 854, 1331-1332, 1364-1365
* **Contradiction:** A load group is "one `each` batch", but every `each` round frees its own store. The preloaded associations either die after round 1 (N+1 comes back) or live in a longer store (memory is no longer bounded). CUJ 2 and CUJ 5 cannot both hold as written.
* **Resolution (Segmentation):** use a batch store per `batch_size` page for the records, the group and the preloads, plus a round scratch for what the block makes. Memory is then bounded by `batch_size`, which matches the NFR at 854. CUJ 5 and the M4 memory test should say "per batch". Liabilities: a rule for which store a setter's text goes into, and a `test/refused` case for a record kept past its batch.

#### C2. `copy_to(owner)` is relied on and also said not to work
* **Affected Scope:** 142, 195-196, 216-221, 336-343, 1008-1009
* **Contradiction:** The Goal and CUJ 7 need `copy_to` into an owner declared outside the block. Open Questions says `copy_to` works only with `Program.tape`, and new owner kinds are a non-goal.
* **Resolution (Inversion, SPEC 1.9):** the caller passes a writer, for example `pluck_into(:name, builder, spans)` or `each` with a caller-owned builder. CUJ 7 then works on today's compiler. Liabilities: each projection gets two API forms.

#### C3. After-commit failures are only reported, and the outbox was rejected as all or nothing
* **Affected Scope:** 466-468, 774-791, 1268-1270
* **Resolution (Beforehand Cushioning):** keep the in-memory queue as the default. Add an opt-in `after_commit :m, durable: true` that writes an outbox row in the same transaction and deletes it when the method succeeds. A failed row is left as a dead letter to drain later. Liabilities: the method must be idempotent, one extra INSERT and DELETE per durable item, and an outbox table convention in every account file.

#### C4. The SlicePool alternative was never weighed
* **Affected Scope:** 470-473, 753-761
* **Discrepancy:** Alternative I cites SPEC 2.2 as a hard refusal, but the same SPEC sentence sanctions SlicePool.
* **Resolution:** add a short alternative or probe for "records own slices from a store-owned SlicePool", even if it loses to flat columns.

#### C5. Request read transaction release (merged into Z8 above)

### 🟢 Nit

* **C6.** Text rewrites only ever grow the store (502-504). Add a note, or a debug assertion, that a long-lived global session must only be used inside `request`.
* Catalyst Nits 7-11 (the Value type, Grant names, the probe count, the misplaced alternatives, the 240-byte limit) are merged into Z2, Z3, N1, N2 and N3.

---

**Verdict (both reviewers):** revise before approval. Fix the internal contradictions first: Z1, Z2, Z3, Z4, C1 and C2. Z5-Z7 and Z8 are scope cuts that would shrink M1, M3 and M4.
