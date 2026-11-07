# Goldfish Review Report

**Target:** `/home/priit/contribute/rispacks/grant/doc/DESIGN.md` (lines 1-907, before "## Detailed Implementation Plan")
**Stage:** 7 (Critic Review), round 1

## Reviewer Status

| Reviewer | Status |
| --- | --- |
| `egm-design` | completed |
| `egm-structural` | completed |
| `egm-style` | completed |

Severity breakdown after deduplication: 🔴 3, 🟡 17, 🟢 22.
Findings from earlier stages are left out. Where two or more reviewers found the same issue, it is listed once under the first id, with the other lenses under "Also".

Coverage notes:
- `egm-structural` did not open the context files.
- `egm-design` only spot-checked web/server.ri, db/core.ri and sqlite/core.ri.

## Prioritized Findings (Blockers -> Major -> Nits)

### 🔴 design-1-1 The shared read transaction conflicts with BEGIN IMMEDIATE
* **Reviewer Lens:** `egm-design`
* **Affected Scope:** lines 272-273, 356, 406, 410-425, 863-864
* **Discrepancy Description:** A request's reads share one deferred read transaction, and every write (even a lone `save`) runs `BEGIN IMMEDIATE`. SQLite refuses a `BEGIN` inside an open transaction. Upgrading a deferred read in WAL mode can fail with SQLITE_BUSY_SNAPSHOT. CUJ 1 (read, then save) hits this.
* **Rationale & Recommendation:** Say what happens to the read transaction when a write starts: end it first, use a SAVEPOINT, or drop the shared read. Add a probe at 614-618.

### 🔴 design-1-2 There is no Risks & Mitigations section
* **Reviewer Lens:** `egm-design`. Also: `egm-structural` (blocker)
* **Affected Scope:** whole document. Scattered risks are at 417-418, 501-504, 546-547, 848-870.
* **Discrepancy Description:** The standard requires this section. Scattered risks: a panicked write leaves its transaction open; the store grows when a record is rewritten; raw SQL is scoped on the main table only; busy_timeout under contention. Missing risks:
  - descriptor and open cost with thousands of account files;
  - schema drift across per-account files;
  - write contention on one account file;
  - a crash loses after-commit work (the outbox gain at 783 is given up without saying so);
  - the compiler changing under a pinned commit.
* **Rationale & Recommendation:** Add an H2 section. Give each risk its impact and either a mitigation or an explicit acceptance.

### 🔴 structural-1-1 Rejections are attributed to the author with no link
* **Reviewer Lens:** `egm-structural`. Also: `egm-design` (major), `egm-style` (nit: repetitive wording)
* **Affected Scope:** lines 630, 641, 664, 683, 706, 726, 739, 750, 788, 801, 820, 839
* **Discrepancy Description:** The Alternatives Rule forbids attributing a rejection to a maintainer without a linked issue, discussion or PR. A and G rest on unlinked decisions ("first user does not need", "moves to one SQLite file").
* **Rationale & Recommendation:** Lead each reason with the trade-off and drop "Rejected by author", or link a stable record. The untracked concepts_brief.md is not stable.

### 🟡 design-1-3 CUJ 1 bypasses the request scope
* **Reviewer Lens:** `egm-design`
* **Affected Scope:** 262-277 compared with 402-406 and 850-853
* **Discrepancy Description:** CUJ 1 uses `global` directly, not `global.request { }`. Records then pile up in the worker's store, which breaks the NFR against per-request memory growth (RIS_GRANT_SPEC 8.9). Nothing enforces the scope.
* **Rationale & Recommendation:** Show `global.request` in CUJ 1. Make loading without a request scope impossible, or add a growth test.

### 🟡 design-1-4 The Value union cannot hold decimal, binary or json
* **Reviewer Lens:** `egm-design`
* **Affected Scope:** 103-105 compared with 476-478
* **Discrepancy Description:** There is no bytes or decimal variant. Storing decimal as Float64 loses precision on money columns.
* **Rationale & Recommendation:** Give the storage form and getter type for each declared type, or move the unsupported types to non-goals.

### 🟡 design-1-5 Streaming `each` by primary key conflicts with `order`, `limit` and `offset`
* **Reviewer Lens:** `egm-design`
* **Affected Scope:** 129-131, 512-513
* **Rationale & Recommendation:** Define how they combine. Options: keyset pagination on (order columns, pk), refuse the combination, or document that order is ignored.

### 🟡 design-1-6 After-commit dispatch and semantics are undefined
* **Reviewer Lens:** `egm-design`
* **Affected Scope:** 134-138, 452-468, 583-589, 680-681, 234
* **Discrepancy Description:**
  - (a) The mapping from model id and method index to code across modules is unnamed and unverified.
  - (b) Items queued by after-commit work: whether they run in the same drain, and whether recursion is bounded, is not said.
  - (c) An after-commit error looks the same as a rolled-back write. The `db.write` return type is not given, and the error is missing from the errors table.
  - (d) For a lone `save`, when items run and what `save` returns if one fails is not said.
* **Rationale & Recommendation:** Name the dispatch mechanism and probe it. Add a distinct "committed, after-commit failed" error or result shape.

### 🟡 design-1-7 busy_timeout, WAL and foreign_keys are never set
* **Reviewer Lens:** `egm-design`
* **Affected Scope:** 113, 863-864 (see sqlite/core.ri:621-656)
* **Discrepancy Description:** SQLite's default busy_timeout is 0, so contention fails at once. Without WAL, a writer blocks readers. Foreign keys are off by default, so `on_delete:` silently does nothing.
* **Rationale & Recommendation:** List the pragmas that `Ricord.open` applies.

### 🟡 design-1-8 Scope inheritance can silently overwrite an update
* **Reviewer Lens:** `egm-design`
* **Affected Scope:** 543-544
* **Discrepancy Description:** Take `court.update(account_id: other)` on a record reached through `account.courts`. The design does not say whether the scope overwrites or re-scopes the record.
* **Rationale & Recommendation:** Decide whether a scope conflict is an error or allowed, and add a test.

### 🟡 design-1-9 "Different database" identity is undefined
* **Reviewer Lens:** `egm-design`
* **Affected Scope:** 443-447
* **Rationale & Recommendation:** Define database identity (normalized URI or file path) and how two sessions on the same file compare.

### 🟡 design-1-10 The atomic `dependent: :destroy` cascade is unbounded
* **Reviewer Lens:** `egm-design`
* **Affected Scope:** 304-312, 563-567
* **Discrepancy Description:** A large account holds the write lock for the whole cascade.
* **Rationale & Recommendation:** State the expected size, or recommend `:delete_all` for large trees.

### 🟡 structural-1-2 Alternative letters skip and are out of order
* **Reviewer Lens:** `egm-structural`. Also: `egm-design`, `egm-style` (nit)
* **Affected Scope:** 622-844, with a cross-reference at 425 ("Alternative J")
* **Discrepancy Description:** The letters run A-L, then P (804), then M (823). N and O are missing.
* **Rationale & Recommendation:** Re-letter in order, or say why letters were retired.

### 🟡 structural-1-3 Milestones are referenced but not defined in range
* **Reviewer Lens:** `egm-structural`. Also: `egm-style` (nit)
* **Affected Scope:** 31, 179, 874
* **Rationale & Recommendation:** Add a short milestone summary, or a forward reference to the plan section.

### 🟡 structural-1-4 Heading hierarchy
* **Reviewer Lens:** `egm-structural`
* **Affected Scope:** 848, 872, 887
* **Discrepancy Description:** "Additional Resources" and "Future Improvements" are H3 headings under the NFR H2.
* **Rationale & Recommendation:** Promote them to H2, or put them under an Appendix H2.

### 🟡 structural-1-5 Open Questions mixes answered findings with open items
* **Reviewer Lens:** `egm-structural`. Also: `egm-style` (probe provenance)
* **Affected Scope:** 200-255
* **Discrepancy Description:** Only 202-211 are open. Lines 213-255 are probe results and design facts. Style adds that the probe claims (213-227) give no file or commit, while 614-618 list the probes as future work.
* **Rationale & Recommendation:** Move the answered items to a Findings/Constraints subsection. Cite each probe's file and compiler commit, or mark it as an unrecorded manual run.

### 🟡 style-1-1 A Non-Goal title says the opposite of its body
* **Reviewer Lens:** `egm-style`. Also: `egm-structural`
* **Affected Scope:** 190-194
* **Rationale & Recommendation:** Retitle it "Isolating accounts inside one shared SQLite file".

### 🟡 style-1-2 An open caveat sits in the Problem section
* **Reviewer Lens:** `egm-style`. Also: `egm-design`
* **Affected Scope:** 67-68
* **Discrepancy Description:** "Whether that already reads freed text has to be checked."
* **Rationale & Recommendation:** Move it to Open Questions with an owner and a test, or state the probe result.

### 🟡 style-1-3 "This is documented." does not say where
* **Reviewer Lens:** `egm-style`
* **Affected Scope:** 333-334, 547
* **Rationale & Recommendation:** Name the document and section.

### 🟡 style-1-4 The `save` bullet is duplicated
* **Reviewer Lens:** `egm-style`. Also: `egm-structural` (nit)
* **Affected Scope:** 430-442
* **Rationale & Recommendation:** Merge the RecordInvalid and `doc/NAMING.md` note into step 2 of the first bullet.

### 🟡 style-1-5 Cost and maturity claims lack evidence
* **Reviewer Lens:** `egm-style`
* **Affected Scope:** 629 ("weeks of work"), 735 ("about double"), 747-748 (Turso beta, experimental)
* **Rationale & Recommendation:** Give the basis or the sources with dates, or drop the claims.

### 🟢 design-1-11 Line 38 calls 221bd212 "Grant's HEAD"
* **Reviewer Lens:** `egm-design`
* **Affected Scope:** 38
* **Discrepancy Description:** That commit is this design's own doc change.
* **Rationale & Recommendation:** Cite the last code commit or a tag.

### 🟢 design-1-12 The compile-fail test assertion method is unspecified
* **Reviewer Lens:** `egm-design`
* **Affected Scope:** 145, 617
* **Rationale & Recommendation:** Say how `bin/test` asserts an expected compile failure: exit code, message match, or both.

### 🟢 design-1-13 The 240-byte error cap
* **Reviewer Lens:** `egm-design`
* **Affected Scope:** 572, 580
* **Rationale & Recommendation:** Say whether the cap includes the prefix and how truncation is marked.

### 🟢 design-1-14 Cross-file references are unchecked
* **Reviewer Lens:** `egm-design`
* **Affected Scope:** 323-334
* **Discrepancy Description:** No foreign key can enforce `Membership.user_id`.
* **Rationale & Recommendation:** State that cross-file references are unchecked.

### 🟢 design-1-15 The `Array#run` prelude dependency of `copy_to` is unexplained
* **Reviewer Lens:** `egm-design`
* **Affected Scope:** 197

### 🟢 design-1-16 The per-request file-open cost is vague
* **Reviewer Lens:** `egm-design`. Also: `egm-style`
* **Affected Scope:** 400-401
* **Discrepancy Description:** Each open also runs pragmas and possibly a schema check.
* **Rationale & Recommendation:** Give a rough cost, or state the decision it supports.

### 🟢 structural-1-6 Alternatives use inconsistent templates
* **Reviewer Lens:** `egm-structural`
* **Affected Scope:** C (646-669); D, F, K, P; I (759) and J (770) are unattributed

### 🟢 structural-1-7 Missing blank lines before lists and fences
* **Reviewer Lens:** `egm-structural`
* **Affected Scope:** 674-675, 715-716, 755-756, 776-777, 795-796, 805-806, 826-827

### 🟢 structural-1-8 Escaped pipes in the table
* **Reviewer Lens:** `egm-structural`
* **Affected Scope:** 585-589

### 🟢 structural-1-9 References are unlinked and use mixed path styles
* **Reviewer Lens:** `egm-structural`
* **Affected Scope:** 874-885, and SPEC citations such as 47, 218, 385, 628

### 🟢 structural-1-10 Citations point to a spec that will be rewritten
* **Reviewer Lens:** `egm-structural`
* **Affected Scope:** 468, 853 compared with 874
* **Rationale & Recommendation:** Restate the requirement inline, or pin the revision the section numbers refer to.

### 🟢 structural-1-11 Over-long line
* **Reviewer Lens:** `egm-structural`
* **Affected Scope:** 295 (about 95 characters)

### 🟢 structural-1-12 User impact comes after the technical causes
* **Reviewer Lens:** `egm-structural`
* **Affected Scope:** 36-79
* **Rationale & Recommendation:** Lead with the user problem.

### 🟢 structural-1-13 Horizontal rules are used inconsistently
* **Reviewer Lens:** `egm-structural`
* **Affected Scope:** 846, 906

### 🟢 style-1-6 "Bad experience" is subjective
* **Reviewer Lens:** `egm-style`
* **Affected Scope:** 75
* **Rationale & Recommendation:** "In Rails, account isolation leaked rows."

### 🟢 style-1-7 "Real Rails ergonomics" is subjective
* **Reviewer Lens:** `egm-style`
* **Affected Scope:** 660
* **Rationale & Recommendation:** "Keeps `User.find(1)` with no argument."

### 🟢 style-1-8 "Fragile" is subjective
* **Reviewer Lens:** `egm-style`
* **Affected Scope:** 800
* **Rationale & Recommendation:** State the failure mode.

### 🟢 style-1-9 "The simplest" is unsupported
* **Reviewer Lens:** `egm-style`
* **Affected Scope:** 815
* **Rationale & Recommendation:** "Needs no preload logic."

### 🟢 style-1-10 The "tests rot" metaphor
* **Reviewer Lens:** `egm-style`
* **Affected Scope:** 639-640
* **Rationale & Recommendation:** Replace it with the literal effect.

### 🟢 style-1-11 "Ported here first" is unclear
* **Reviewer Lens:** `egm-style`
* **Affected Scope:** 12

### 🟢 style-1-12 The "answers" convention for "returns" is not explained
* **Reviewer Lens:** `egm-style`
* **Affected Scope:** 389, 551, 586-589
* **Rationale & Recommendation:** Define it once, or use "returns".

### 🟢 style-1-13 Stale citation `db/core.ri:664`
* **Reviewer Lens:** `egm-style`
* **Affected Scope:** 250
* **Discrepancy Description:** The call is at line 666 and the class at 712.
* **Rationale & Recommendation:** Update the line number, or cite the method name only.

### 🟢 style-1-14 "Always bound parameters" is absolute
* **Reviewer Lens:** `egm-style`
* **Affected Scope:** 856-857 compared with 130
* **Discrepancy Description:** Line 130 allows raw SQL in `where`.
* **Rationale & Recommendation:** Narrow the claim to the query API, and say raw SQL fragments are the caller's responsibility.
