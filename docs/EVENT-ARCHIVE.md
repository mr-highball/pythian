# Persisted recorded-event learning

[Home](../README.md) · [Shared events](EVENT-CORPUS.md) ·
[Corpus envelope](../src/pythian.corpus.archive.pas) · [Layered style](LAYERED-STYLE.md) · [Work](WORK.md)

`pythian.wfc.event.archive` saves and admits reusable recorded-event learning.
The native measured-corpus envelope remains unchanged; an opaque attachment uses
the distinct `pythian.wfc.recorded.events.v1` contract. Existing acoustic-only and
joint-activity archives retain their own attachment contracts.

## Saved contents and ownership

`EncodeRecordedEventCorpus(Corpus, Learning, Policy)` stores the measured corpus,
its exact source identities/attribution, ordered source inputs, accepted interval
bounds, run/exclusion indices, onset-start flags, duration quantum, exact binary64
palette centers and canonical text of the actual trained WFC model. Nonempty
bounded UTF-8 policy text describes the caller's prior interval admission.

Before saving, every source identity must match the learning object's source
table. Interval descriptors and token assignments are reconstructed against the
supplied corpus and saved centers, and the model is independently admitted.
The original corpus and learning object remain caller-owned and unchanged.

`DecodeRecordedEventCorpus(Bytes, out Learning, out Policy)` returns a separate
caller-owned measured corpus and learning object. Either may be freed independently
after loading. Failure releases partial objects and leaves learning nil and policy
empty. `TRecordedEventLearning.CreateFromModel` provides the same admission for
in-memory callers and clones the supplied model; `CopyInputs` returns detached
arrays, including nested bounds/run/flag arrays.

## Admission without relearning

Loading validates the native envelope's SHA256 and internal corpus measurements,
then reconstructs interval descriptors from the stored analysis windows. It assigns
tokens against the saved event centers; it does not rerun FFT, palette clustering,
onset/pulse tracking or WFC learning.

`ValidateAcousticEventModel` independently checks:

- Canonical event vocabulary within the saved palette and no unobserved tokens.
- Open boundary mode, supported order 1..4, exact sample count and each run length.
- Every admitted observation's history and emitted token in the saved state set.
- Exact observation, start and end counts for every state.

Sorted observed keys use bounded binary searches instead of allocating a dense
alphabet-to-the-power-of-order table. At most four base-1025 digits fit in QWord
under WFC's 1024-state limit. Original song/run boundaries participate in admission,
so a structurally valid model of different observations still rejects.

The policy is retained as provenance; its text is not executed or treated as
proof of onset/beat accuracy. Stored intervals are explicit accepted definitions.
The digest detects corruption and binds bytes; it is not a signature or proof
of source authenticity. External WAV hashes are verified again before rendering.

## Encoding

The attachment begins with little-endian `EVT1`, recorded-event and token-contract
versions, duration quantum, input count and palette count. Length-prefixed policy
text precedes the exact little-endian binary64 centers. Each source input stores
its corpus index, interval count, first bound and triples of end bound, run index
plus one, and a 0/1 onset flag. Zero in the run field means exclusion. Canonical
length-prefixed WFC model text ends the payload; trailing bytes reject.

The existing envelope caps archives at 32 MiB and attachments at 16 MiB. Policy
text is limited to 4096 bytes. Source, interval, run, palette and learning budgets
retain the [shared-event limits](EVENT-CORPUS.md#library-contract). Counts and
remaining byte extents are checked before allocating their arrays; nonfinite
centers, invalid flags, unknown versions and malformed model text reject.

## Native use

Fresh `pythian.event.merge` generation now also writes `OUTPUT.wav.pyac`.
It contains reusable learning, independently of the generated fragment sequence.

```text
pythian.event.merge --load INPUT.pyac OUTPUT.wav SEED EVENTS SOURCE.wav [SOURCE.wav ...]
```

Supply every admitted source recording exactly once, in any order. No onset reports
are needed. The operator loads the saved model/centers/intervals, binds exact WAV
hashes, runs actual WFC generation, and reconstructs recorded members. It writes
WAV, model text, JSON evidence and a byte-identical copy of the input learning
archive. JSON identifies saved loading and the retained admission policy.

Input paths are protected for all four outputs; invalid source binding fails
before writes. The four output writes are sequential, not an atomic transaction.
The same seed and generation options replay the fresh-learning WAV/model when
source audio is unchanged. Different requested fragments reuse the same learning.

## Evidence and remaining work

Checked FPC 3.2.2 and 3.3.1 i386-win32 fixtures cover orders 1..4, exact centers,
models, members, canonical archive replay and detached ownership. A truncated
archive rejects. Attachments with a valid outer digest still reject invalid onset
flags, changed admitted observations, changed exclusion/run admission and trailing
bytes. A structurally valid WFC model trained from different observations rejects.

The two-recording pulse corpus from the [shared-event checkpoint](EVENT-CORPUS.md)
saves and reloads 191 members in 12 independent runs, with 71 tokens / 145 states.
Generation with seed 731 produces 64 events / 1207709 stereo frames on both
compilers. Reversed WAV arguments reproduce the original WAV/model exactly, and
the independent output checker verifies every PCM sample. Both compilers emit
identical archive bytes; save/load replay preserves those bytes too.

Logs: `build/event-archive-{stable,trunk}/` and
`build/event-archive-replay.log`. The reference archive SHA256 is
`3e533335b7355f594d4a006128d139ab7ac38b84ac408d21a90cb55814cc9b37`.
Duplicate-source rejection preserves all four existing outputs
(`build/event-archive-stable/rejection.log`). The standard build includes the
archive fixture and saved-event operator smoke. This checkpoint is focused
native evidence; no new platform, full-suite or source-package claim follows.

This archive retains a shared event model. It does not supply per-layer style
profiles, explicit evidence weights, learned voice separation or generation-resume
state. The reference output still selects one contributing recording; saving and
reloading it does not establish audible two-song blending. Those remain distinct
requirements under the accepted layered architecture.

The subsequent [source-package refresh](PACKAGING.md#current-source-packages)
ships these APIs and a standalone two-recording save/load example. Extracted
consumers pass on both compilers; the real pulse-archive operator/checker also
replays against extracted library sources without workspace library paths.
