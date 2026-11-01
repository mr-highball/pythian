# NS-6_scalar-fixture_01 — Preserve Unicode bytes in the native JSON test oracle

[Tasks](README.md) · [Native build reuse](NS-6_native-reuse_01.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 1/10
**Status:** In progress
**Owner:** Big Boss (single agent)

**Description:**

Make the existing JSON reader/writer fixtures construct their intended raw UTF-8 input and
expected values on Windows as well as pas2js. Primary attribution: NS-6. Keep all
codec/invalid-data/cancellation assertions and the real host code page. Do not
change a production parser or globally force a UTF-8 environment to hide the
fixture's own implicit string conversion.

**Acceptance Criteria:**

- AC1: Preserve the full-rebuild and reused-build baseline failures. Demonstrate
  the invalid data belongs to the expected fixture value before codec comparison.
- AC2: Construct already encoded scalar fixtures explicitly, retaining existing
  assertions. Native full/reused builds and actual pas2js pass the same cases;
  complete CI qualifies the changed fixture with the native-build repair.

**Blockers**

- None; production Unicode project/HTTP acceptance remains separately recorded.

**Dev Notes:**

- 2026-11-01, Big Boss: full Windows build stops at json.text CheckStrings229.
  Both reused and fresh forced `-B` builds fail identically at CompareScalarText's
  expected/right operand. The diagnostic records host code page1252: combining
  U+0301 encodes CC81 alone, but `'e' + ScalarText($301)` becomes invalid65B4.
  Quoting U+10000 silently substitutes two question marks. Adjacent scalar-only
  concatenation is valid; the mixed literal expression is the reproduced failure.
  Evidence: E/native-reuse-20261101-boss full-build01, forced-baseline and
  scalar-diagnostic logs. Keep the failure, repair only fixture composition and
  retain every case. AC1 closes; no effort is accepted before full qualification.
- 2026-11-01, Big Boss: full-build02 then exposes the identical mixed-literal
  issue in the writer fixture. Both tests now reuse one test-only encoded-parts
  helper. Cold/warm native reader5859/writer656 and actual pas2js reader5642/
  writer174 pass with all assertions retained and native clean heaps. Production
  codecs and the host code page are unchanged. Full-build03/CI remain open.
- 2026-11-01, Big Boss: the original writer also fails under forced full rebuild
  at its mixed fixture's AppendQuoted call; writer-forced-baseline retains the
  complete source/build/exit217 trace. The diagnostic and both original failures
  close AC1 without attributing this pre-existing issue to compiler reuse.
