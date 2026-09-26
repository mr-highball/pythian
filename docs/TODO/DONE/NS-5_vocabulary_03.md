# NS-5_vocabulary_03 — Balance admitted-pitch contributions by work group

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-5)

**Description:**

Add a bounded source-balanced WFC training comparison over the existing
source-bound admitted-pitch journal. Make work-group token contribution
explicit while preserving source, annotation, frame, run, unknown and silence
evidence. This is a reusable training-control prerequisite; it does not claim
genre representativeness or automatic note inference.

North star: NS-5. Outcome owner: WAV-04-VOCABULARY.
Completion credit: 1 goal percentage point (0.20 overall points).
Credit is earned only when every acceptance criterion and the task-flow
completion requirements pass.

Accepted 2026-09-25: the maintained Pascal
[group-balance planner](../../../adapters/wfc/pythian.wfc.admitted.pitch.balance.pas)
and [weighted admitted-pitch learner](../../../adapters/wfc/pythian.wfc.admitted.pitch.pas)
rebuild actual WFC models from the unchanged accepted journal. The frozen
three-recording, two-work-group development packet has 28 admitted tokens and
25 runs. Integer group weights 4 and 3 balance admitted token mass at 48/48;
weighted run starts remain 48/39 and repeated-section identity stays unknown.
The all-ones model/evidence hashes remain exact. Checked FPC 3.2.2 Win32/Win64
fixtures and the exact-journal integration reproduce the same plan, changed
model, source/policy/weight evidence and seed-731 two-token solve with zero
leaks. The focused [fixture](../../../tests/pythian.tests.wfc.admitted.pitch.balance.lpr)
checks foreign identity, impossible ratio and weighted-capacity rejection;
the accepted journal fixture retains malformed codec/failure controls. Salty
Boi's focused QA found no blocker. Exact commands, hashes and the pre-score
identity-literal correction are retained privately in
`build/admitted-balance/RESULT.md`. This earns **+1 NS-5 / +0.20 overall**;
NS-5 is **30%** and total completion **70.05%**. It does not qualify a genre,
automatic note inference, full corpus representativeness or musical quality.

**Bounded input and policy:**

- Use the accepted source-bound admitted-pitch journal path. Verify the exact
  journal identity specified in the private frozen evidence at
  `build/admitted-balance/POLICY.md` before any comparison; retain each source,
  annotation, work-group, recording, frame and run identity.
- The current development packet contains three recordings from two URMP work
  groups. Report that scope exactly. Do not claim genre coverage, independent
  accuracy, or correctness of the published note annotations from this
  comparison.
- Count admitted pitch and explicit-silence spans once as WFC tokens. Unknown
  and uncovered intervals contribute no tokens and remain run boundaries.
  Report raw included frames, source extent, token count and run count
  separately by recording and work group. Repeated-section accounting is
  unknown in this packet and must remain explicitly unknown.
- Apply the frozen deterministic integer work-group weight selection rule,
  including its 1..64 weight bounds, 110% maximum/minimum token-mass ratio,
  65,536 weighted-token work cap and 4,096 weighted-run cap. Do not change
  sources, spans, groups, ratio, weights or limits after the comparison begins.

**Current code boundary:**

The accepted journal is
[pythian.wfc.admitted.pitch.journal](../../../adapters/wfc/pythian.wfc.admitted.pitch.journal.pas);
the current source-bound learner is
[pythian.wfc.admitted.pitch](../../../adapters/wfc/pythian.wfc.admitted.pitch.pas),
and its lower-level weighted learner is
[pythian.wfc.pitch](../../../adapters/wfc/pythian.wfc.pitch.pas). The earlier
admitted learner assigned weight one to each independent run, while the lower
learner weights whole samples. The accepted extension preserves the journal
format and all-ones model bytes, and binds a separate balance policy and
weights in the comparison evidence.

The owned implementation is
[pythian.wfc.admitted.pitch.balance](../../../adapters/wfc/pythian.wfc.admitted.pitch.balance.pas)
with its focused fixture at
[pythian.tests.wfc.admitted.pitch.balance](../../../tests/pythian.tests.wfc.admitted.pitch.balance.lpr).

**Acceptance Criteria:**

- Produce the unweighted all-ones rebuild and the frozen group-balanced rebuild
  from exactly the same journal and WFC order. Show raw and weighted token and
  run contributions separately by recording and group, along with the selected
  weight vector and work/capacity totals.
- Train actual maintained WFC models with independent source/run boundaries.
  Require distinct saved model bytes, record the source, model, policy and
  weights in evidence, reload the balanced model, and demonstrate bounded
  fixed-seed token generation. This is a contribution-control demonstration,
  not a claim of improved musical quality.
- Reload the canonical journal and reproduce the balanced model, evidence and
  report deterministically on checked Win32 and Win64 targets with zero leaks.
- Verify malformed or foreign journal rejection, impossible-balance and
  capacity rejection, and failure preservation without modifying the accepted
  journal encoding or all-ones model bytes.
- Stop at the first frozen input, balance, identity, replay, work or capacity
  gate failure. Do not tune or substitute the source packet to rescue a result.

**Blockers**

- [NS-5_scale_04.md](NS-5_scale_04.md) — accepted canonical contribution
  journal and deterministic rebuild.
- [NS-3_notes_06.md](NS-3_notes_06.md) — source-bound admitted-note
  evidence and unknown/run boundaries.

**Dev Notes:**

- The contribution journal and admitted-pitch learner already provided
  bounded, source-identified inputs and actual WFC training. This task added a
  distinct group-token-mass policy comparison without a second journal. The
  downstream [NS-5_vocabulary_01](../NS-5_vocabulary_01.md) task retains
  broader representative vocabulary and balanced/unbalanced acceptance.
- The first private source gate stopped before journal decode because the
  copied expected SHA-256 literal was truncated. The unchanged accepted file
  matched its full published 64-character hash on both targets. Correcting
  only that literal before the first model score repaired the preflight; the
  failed unhandled private run does not carry a zero-leak claim. The final
  checked runs report zero leaks. No balance threshold or source changed.
