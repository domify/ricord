# Goldfish Review Report: Stage 8 Intermediate Zoom Out

**Target:** `/home/priit/contribute/rispacks/grant/doc/DESIGN.md` (full file, 1-1207; FeatureRange 1-840, DetailedRange 841-1207)

## Reviewer Status

| Reviewer | Status |
| --- | --- |
| `egm-zoom-out` | completed (first attempt) |

The reviewer did not re-read the GoldfishContext sources in this pass, so no file:line citation in the design was re-checked against code.

## Earlier Zoom-Out Findings: Status

- **Resolved:**
  - Z1 (424-429)
  - Z2 (447-448, 963-964)
  - Z4 (586-588, 999)
  - Z6 (160, 816)
  - Z7 (136-139)
  - C1 (492-496)
  - C2 (826-837)
  - N1, N2, N5 and N7
  - C4, as Alternative R
- **Kept by author decision (E1 = a):** Z5. `create_sql` now has users (tests and new account files).
- **Kept with mitigations (F1 = a):** Z8. The remaining cost is covered in finding 4.
- **Partly regressed:** Z3. See the M0 tag nit.

## Prioritized Findings (Blockers -> Major -> Nits)

There are no Blockers.

### 🟡 1. Turso first adds a build chain while v1 uses no Turso features - Severity: Major
* **Reviewer Lens:** `egm-zoom-out`
* **Affected Scope:** Lines 34-36, 152-154, 174-178, 579-582, 668-675, 756-758; M0 items 9-11 and 18 (893-913, 949-954)
* **Discrepancy Description**: Turso brings a Rust/cargo build of libturso (`bin/build-turso`, `vendor/turso.md`), a CI build step, a `RICORD_ENGINE` switch, a gating probe and a fallback decision. v1 uses neither `numeric(P,S)` nor `BEGIN CONCURRENT` (177-178, 581, 758), and money is stored as `:bigint` (485). Alternative H is rejected without a technical reason (674-675). The "SQLite tools may not read Turso files" cost is missing from Risks (752-776).
* **Rationale & Recommendation**: Run M1-M4 on libsqlite3, which the driver already passes. Run the Turso probe as a parallel, non-blocking job, and switch the default when it passes. At the least, add the file-compatibility risk and give a technical reason for rejecting Alternative H.

### 🟡 2. Two dialects for one SQL dialect - Severity: Major
* **Reviewer Lens:** `egm-zoom-out`
* **Affected Scope:** Lines 325, 574-582, 982-986
* **Discrepancy Description**: `Dialect::Turso` and `Dialect::Sqlite` share the driver, quoting, placeholders, `RETURNING`, `BEGIN IMMEDIATE` and the time format. The only proposed differences are features v1 does not use.
* **Rationale & Recommendation**: Use one `Dialect::Sqlite` and make the engine a link-time setting. Keep the trait for a future PostgreSQL dialect.

### 🟡 3. `:json` and `:binary` grew past the F11 decision - Severity: Major
* **Reviewer Lens:** `egm-zoom-out`
* **Affected Scope:** Lines 179-180, 476-484; M1 items 8-9 (1021-1028); M2 `json_field` (1089); M0 item 14 (928-931)
* **Discrepancy Description**: F11 decided that json and binary are text spans with `String` getters. The design now adds:
  - a `Ricord::Json` wrapper with `[]` by both String and Symbol
  - a `json_field` accessor DSL
  - a `Ricord::Blob` type with four methods and a refused-print fixture
  - a `std/json` probe as an Open Question

  No CUJ uses any of them.
* **Rationale & Recommendation**: Return `String` in v1 and move these to Future Improvements. This also removes an M0 probe and an Open Question.

### 🟡 4. The shared read transaction pushes a correctness duty onto every caller - Severity: Major
* **Reviewer Lens:** `egm-zoom-out`
* **Affected Scope:** Lines 233-235, 377-388, 761-762, 998-999, 1049-1050, 1161
* **Discrepancy Description**: The design adds a `reading` flag, an implicit COMMIT before each write, and a manual `db.release` that must be called before I/O. Nothing enforces the release call. A forgotten call silently pins the WAL snapshot (the risk at 761). Only the M5 example calls it, and the optimisation is unmeasured.
* **Rationale & Recommendation**: Make the release structural: `request` releases on exit, the web adapter calls it, and a debug assertion or log flags a read held too long. Otherwise use autocommit reads in v1 and defer the shared read.

### 🟡 5. `after_rollback` is new, has no CUJ, and is unspecified - Severity: Major
* **Reviewer Lens:** `egm-zoom-out`
* **Affected Scope:** Lines 119-120, 423, 437, 1081
* **Discrepancy Description**: The design does not say what the callback receives. The queue holds keys only, and after a rolled-back create the key no longer exists. It also does not say when the callback runs: inside or outside a write, or per savepoint rollback.
* **Rationale & Recommendation**: Drop it from v1, or specify its arguments and its timing at the outer ROLLBACK versus ROLLBACK TO.

### 🟡 6. Scope inheritance machinery is heavy for a "convenience" - Severity: Major
* **Reviewer Lens:** `egm-zoom-out`
* **Affected Scope:** Lines 132-135, 509-521, 785, 1110-1117, 1121-1123
* **Discrepancy Description**: With one file per account, isolation does not depend on scope (785). The design still adds:
  - per-record `scopes` slots
  - a scope-pair table in the store
  - parent conditions injected into joins and subqueries
  - scoped bulk writes
  - a `ScopeError` type
* **Rationale & Recommendation**: In v1, scope should mean the association's foreign-key condition plus `create` defaults. Defer the rest.

### 🟢 7. Store fields - Severity: Nit
* **Reviewer Lens:** `egm-zoom-out`
* **Affected Scope:** Lines 453-456, 976-977 vs 1110
* **Discrepancy Description**: `links` and `link_ranges` remain even though has_many group loading was cut. The scope-pair table (M3) is missing from the store field list at 445-457.
* **Rationale & Recommendation**: Check whether the range array is still needed, and add the scope-pair table to the store field list.

### 🟢 8. Turso foreign-key enforcement - Severity: Nit
* **Reviewer Lens:** `egm-zoom-out`
* **Affected Scope:** Lines 361-363, 911, 1051-1052
* **Discrepancy Description**: `schema_test` asserts foreign-key behaviour, but the M0 engine probe does not check `foreign_keys=on` / `on_delete`. Current Turso support for these was not verified.
* **Rationale & Recommendation**: Add foreign-key enforcement to the M0 engine probe.

### 🟢 9. Destroy dispatch signature - Severity: Nit
* **Reviewer Lens:** `egm-zoom-out`
* **Affected Scope:** Lines 429-430
* **Discrepancy Description**: The class method is typed `db : Ricord::Session`, but the dispatch passes `tx`.
* **Rationale & Recommendation**: Pick one type, likely `Tx` or `Session | Tx`.

### 🟢 10. M0 tag commit - Severity: Nit
* **Reviewer Lens:** `egm-zoom-out`
* **Affected Scope:** Line 853 vs 49
* **Discrepancy Description**: `221bd212` is the doc commit on `ris-tape-port`, not `main`. Line 49 names `012c71b3` as the last code change.
* **Rationale & Recommendation**: Cite the code commit, as design-1-11 asked.

### 🟢 11. "Answers" wording - Severity: Nit
* **Reviewer Lens:** `egm-zoom-out`
* **Affected Scope:** Line 213
* **Discrepancy Description**: The style-1-12 decision was to replace "answers" with "returns". Instead the doc keeps "answers" and adds a glossary entry for it.
* **Rationale & Recommendation**: Apply the replacement, or record the decision as declined.

### 🟢 12. Repeated weeds - Severity: Nit
* **Reviewer Lens:** `egm-zoom-out`
* **Affected Scope:** Lines 544-546, 970-971
* **Discrepancy Description**: The 240-byte limit and `…` truncation details appear twice.
* **Rationale & Recommendation**: Keep them once, in M1.

## Verdict

**Revise before approval.**

- The earlier contradictions and regressions are mostly fixed.
- The main concern now is scope growth from the stage 6-7 additions (findings 1-3, 5 and 6).
- The shared read transaction is accepted complexity with nothing enforcing it (finding 4).
- A simpler path would shrink M0-M3 without blocking any CUJ:
  - SQLite as the working engine, with the Turso probe in parallel
  - `String` for json and binary
  - scope limited to associations
