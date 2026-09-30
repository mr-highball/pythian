# NS-5_corpus_05 — Accept user-defined WAV corpus intake

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-5)

**Description:**

Completion credit: 4 goal percentage points (0.80 overall points).
Current basis: [2026-09-29 outcome rebase](../../REBALANCE-2026-09-29.md#current-credit-basis).
Earlier point/split narratives below are historical; acceptance evidence and failures remain valid.

Make the existing corpus identity, partition and source-range mechanisms usable by a caller supplying an arbitrary style name and WAV recordings. This owns reusable intake; it does not infer a genre or award learning accuracy.

North star: NS-5. Outcome owner: CORPUS-SETUP.
Historical allocation: 3 goal percentage points (0.60 overall points).
Credit is earned only when every acceptance criterion and prerequisite passes.
Primary attribution is the delivered outcome above; consuming other goals earns no duplicate credit.

Execution status: accepted 2026-09-30 after all five criteria and the accepted
identity prerequisite passed independent Salty Boi QA. The supported intake
scope includes unchanged supported original WAVs and verified same-clock
crop/uniform gain; unsupported parent mappings reject. No many-hour or musical
acceptance claim. Qualification at that scale remains in corpus_06.

**Acceptance Criteria:**

- AC1: Expose a maintained Pascal API and native consumer taking caller-owned style IDs, WAV paths, work/recording groups, partitions and optional song ranges. Run the same code for two unrelated caller labels and an unnamed profile; no style-name dispatch, private paths or built-in genre table may be required.
- AC2: Validate WAV bytes/geometry, parent and prepared-source coordinates, notices/acquisition provenance, group identity and prior exposure. Reject invalid ranges, contradictory partitions and missing required declarations before publishing; unknown identity remains development-only.
- AC3: Count unique source duration without duplicate or overlapping ranges inflating it. Preserve preparation/headroom checks and explicit unknown song boundaries. Two excerpts or masters of one work cannot become independent evaluation groups.
- AC4: Save/reload the current corpus contract and feed its admitted training partition to an existing maintained learner. Demonstrate changed source rejection, deterministic replay and no transition across declared song/unknown boundaries.
- AC5: Deliver a small redistributable or reproducibly acquired example plus a caller guide using only the existing verified Pascal toolchains. Keep private media outside tracked files; document unsupported WAV/resource cases and atomic failure behavior.

**Blockers**

- [NS-5_corpus_01.md](NS-5_corpus_01.md)

**Dev Notes:**

- 2026-09-30 final independent QA accepted AC1–5 and prerequisite corpus_01.
  Salty Boi rebuilt stable FPC 3.2.2 checked Win32/Win64: each passed 22
  portable core and 41 actual file/learner checks, valid/malformed native CLI
  checks and zero-leak final runtime logs. Core API compiled using only
  `-Fusrc`. Actual order-2 learning retained two song segments, three
  observations, two BOS/start and two end counts; every state count matched
  independent within-song enumeration. Unknown spans and preceding flux
  context stayed outside the admitted song windows. Saved contract relearning
  and seeded saved-model generation replayed exactly within each target.
  Cross-target manifest/model bytes matched; only 34 full-precision palette
  center coordinates differed, maximum 7.5299153780186527E-16. This measured
  floating-point limit is public, not rounded away. Notices, scoped privacy,
  dependency boundaries, local links and build registration passed.
  Ignored independent evidence: `build/qa-corpus-card/`.
- Acceptance adds 4 NS-5 points / 0.80 overall: NS-5 10→14%, overall
  45.50→46.30, open/DONE 47/31→46/32. Evaluation_01 accepted its AC1 contract
  only and remains open with zero task credit. This is one criterion-closing
  implementation batch, with 0 failed implementation QA submissions; prior
  stopped scientific investigations and counters are unchanged.

- 2026-09-30 implementation batch 1 (Ticket Guy Neo, operational lead;
  Big Boss architectural oversight): delivered the portable detached
  [intake plan](../../../src/pythian.corpus.intake.pas), strict current native
  reader/admission/learner, first-party Pascal-generated example and
  [caller guide](../../CORPUS-INTAKE.md). Acceptance remains pending independent
  Salty Boi QA; no completion credit is assigned by this implementation note.
  The same code admits two unrelated labels and an unnamed profile over the
  same fixture bytes; this proves label neutrality, not independent corpora.
- Candidate evidence covers AC1–5: exact source/preparation hashes, actual
  WAV geometry/headroom and crop/gain parent checks; unique original-frame
  interval union, family/partition/exposure guards, retained unknown spans;
  current contract reload and existing journal/palette/WFC learning; actual
  order-2 model-state observations, song start/end resets and exclusion of
  out-of-song flux context; deterministic saved-model seeded generation and
  saved-contract relearning; invalid admission leaves no candidate outputs,
  existing valid files and another publisher's staging remain intact.
  Generated artifacts and local toolchain roots remain ignored under
  `build/corpus-intake/`.
- Approved supported scope is unchanged supported original WAVs plus verified
  same-clock/channel exact-frame crop and uniform gain. Resample/downmix/
  timewarp parent mappings reject; derivatives must not be relabelled as
  independent originals. Earlier preparation evidence stays in its original
  ledger. This is intake, not a converter, inferred musical acceptance or a
  many-hour result. Complete outside-work/master/exposure evidence remains a
  caller obligation; hashes cannot discover concealed relationships.
- Batch stop: hand off after both intake and the bounded evaluation_01 card
  contract are ready, then close only fully accepted criteria after QA. A
  genuine parser/contract/resource defect returns to its exclusive owner;
  two failed implementation QA submissions transfer directly to Big Boss.
  Current submitted QA failures: 0. Prior stopped scientific counters are
  unchanged.

- 2026-09-29 reassessment: Replaces the reusable intake portion of retired corpus_02/03/04. Their combined six unearned points become corpus_05 (3) plus corpus_06 (3); all coverage/independence obligations remain in corpus_06.
- [Rebalance record](../../REBALANCE-2026-09-29.md) owns the old-to-new scope and credit map.
