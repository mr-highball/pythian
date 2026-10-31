# NS-4_joint-context_01 — Preserve joint harmonic and rhythmic context in instrumental material

[Active tasks](../README.md) · [Goal](../../GOAL.md) · [Milestones](../../MILESTONES.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 4/10
**Status:** Accepted
**Owner:** Big Boss (single agent)

**Description:**

Accepted pitch motifs combined with authored accompaniment expose an actual
coupling gap in the current independent harmony/rhythm provider preparation.
Retain a joint musical-context provider and project its choices into the real
harmonic/rhythmic passes, keeping independent instrumental roles and synthesis.
This is musical adaptation in Pythian, not a demonstrated generic WFC defect.
It is a concrete prerequisite of [experimental learning AC3](../NS-3_experimental-learning_01.md).

Primary attribution: NS-4. Effort estimates implementation complexity, not
musical quality or scientific confidence. No effort is accepted for the failed
prototype, additional tests or this task's creation.

**Accepted outcome — 2026-10-30, Big Boss SOLO.** The primary
[pitch-pattern contract](../../../src/pythian.music.pattern.pas), shared
[joint context](../../../adapters/wfc/pythian.wfc.musical.context.pas) and
[instrumental runtime](../../../adapters/wfc/pythian.wfc.instrumental.pas)
deliver AC1–3. An actual paired harmony/rhythm pass constrains the following
named-voice graph; percussion follows its accepted rhythm. The controlled motif
has six synthesized parts and seventeen real passes in three conditional groups.
No cross-group backtracking, separated mixed-WAV instruments, Studio choice editor
or recording-style learning acceptance is claimed.

Stable FPC 3.2.2 Win32/Win64 and actual pas2js pass 205 motif/context checks and
16 portable pattern checks. Three selected seeds solve within the existing
512/32 search budgets. Provider contract validation, exact token replay, clocks,
unknown/silent distinctions, contradictory hard masks, cancellation and prior-plan
preservation pass. Existing instrumental (74472), percussion (1119), provider UTF-8
(340) and native provider-progress (269669) checks pass, with clean native heaps.
The extracted core package runs the pattern fixture, and the extracted full
package runs the actual pas2js context consumer. These are scoped consumer results,
not a claim that every broader package regression has finished.

The maintained native caller renders the C/unknown/silence/D motif and its corrected
C-sharp/D-sharp version into different actual synthesized WAVs, each 320166 stereo
frames at 44100 Hz. The unchanged authored 64-cell caller matches a fresh build of
the preceding revision and a separate-process replay byte for byte:
SHA256 2073c04a8e6715fbcc159f8cb5ac662b933d75a03df823cd7b35cfc1ebb55f0c.
Evidence is under musical-material-20261030-boss in the dedicated E-drive roots.
This is implementation acceptance; musical preference remains for the operator.

**Acceptance Criteria:**

- AC1: A shared Pythian musical context model retains joint harmonic/rhythmic
  vocabulary and sequence relationships. Its actual context pass supplies recorded
  pinned inputs to both following passes, without silently removing accepted
  material or pinning every part. Conditional graph groups are explicit.
- AC2: The discovered accepted/corrected motif fixture generates actual six-part
  instrumental plans across selected seeds within explicit bounded search.
  Preserve unknown/silent distinctions, deterministic replay, valid note clocks,
  cancellation/failure preservation and the existing authored starter result.
- AC3: The ordinary instrumental runtime can consume the joint model and report
  its actual dimensions, vocabulary, model identity and dependency edges. Validate
  relevant native and actual pas2js consumers. Primary musical behavior stays here;
  source synthesis/core-only use remains independent of WFC.

**Blockers**

- [Instrumental runtime — DONE](NS-4_instrumental-runtime_01.md)

**Dev Notes:**

- 2026-10-30, Big Boss: Reproduction is tests/pythian.tests.material.instrumental.lpr;
  evidence is under musical-material-20261030-boss in the dedicated E-drive roots.
  Quantized C/unknown/silence/D material reaches provider construction, but free
  coupled generation exhausts pass negotiation at harmony-voice with both32
  and1024 pass backtracks. Preserve both failed runs. Do not repeat larger limits.
- The initial wrap-boundary experiment was rejected by the finite graph; authored
  motif repetition with open boundaries preserves finite-time semantics. It does
  not claim observed continuity across unknown spans. The bounded search failure
  remains and motivates this explicit joint-context task.
- Return to experimental learning AC2–4 after this prerequisite. Its current
  nonclosing prototype batch counts as one; changing task does not reset it.
- 2026-10-30, Big Boss: The accepted joint-context implementation closes real
  AC1–3; consecutive nonclosing batches return to zero because of that closure.
  Open finite models use four explicitly authored known-run repetitions. The
  new context pass preserves paired relationships without pinning role notes.
  Its pinned-input lineage and separate solve report remain visible.
- Repairs retained in the same evidence folder: the first fixture incorrectly
  requested provider tokens from proof passes; it now skips those passes. Native
  UTF-8 out-parameter handling uses local String values, and pas2js observer
  factories use explicit calls. The separate native/file-I/O provider-progress
  fixture fails a test-side Move on pas2js and remains native evidence; the actual
  portable consumers pass. No unrelated file-I/O rewrite was selected.
- The older percussion WAV was not a valid byte-preservation baseline: it has
  different drum choices. The fresh preceding-revision build under matched flags
  and current replay establish the actual unchanged authored control instead.
- Studio acceptance/correction and source-bound comparison remain in the parent
  task; coarse corpus learning, graph editing, styles and long form keep their
  existing tasks. No generic WFC gap or dependency-source change is demonstrated.
