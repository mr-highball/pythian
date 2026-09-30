# Caller-defined corpus intake

[Project](../PROJECT.md) · [Corpus evaluation](CORPUS-EVALUATION.md) ·
[Accepted intake](TODO/DONE/NS-5_corpus_05.md) · [Style cards](STYLE-CARDS.md)

The portable [intake API](../src/pythian.corpus.intake.pas) accepts an opaque
caller style ID, work/recording families, WAV declarations, partitions and
optional song ranges. Empty style IDs are valid unnamed profiles. They do not
mean unknown source identity: unverified families remain development-only.
There is no built-in genre table or style-name dispatch.

The native [consumer](../tools/pythian.tools.corpus.intake.pas) verifies actual
files and feeds only admitted training songs to the existing feature-journal,
acoustic-palette and WFC sequence learner. This is raw acoustic learning;
tokens are not inferred notes, style accuracy, calibrated confidence or an
accepted learned musical profile.

## Run the redistributable example

Use an existing verified FPC toolchain. The normal [build](../tools/build.ps1)
registers the portable test independently and the full-product native example,
consumer and file/learner checks in its WFC section. For a focused build,
create ignored output/unit directories and compile these targets with checked
flags `-B -Sa -Cr -Co -Ci -gl`, `-Fusrc`, and separate `-FU`/`-FE` directories:

- `tests/pythian.tests.corpus.intake.lpr` needs only portable core units.
- `tools/pythian.corpus.intake.cli.lpr`,
  `examples/pythian.example.corpus.intake.lpr` and
  `tests/pythian.tests.corpus.intake.files.lpr` additionally need `-Futools`,
  `-Fuadapters/wfc` and `-Fuvendor/wfc/src`.

Run the compiled example with an ignored directory, for example
`build/corpus-intake/example`. It generates two original PCM16 WAVs and three
manifests, `example-0.json`, `example-1.json`, `example-2.json`. Their caller
labels are unrelated strings and an empty string over identical source bytes;
this proves label neutrality, not three independent corpora. The first-party
waveforms and complete MIT notice come from the maintained Pascal example.
One source has two authored song regions separated by an explicitly unknown
span. The other source is a separate work in development.

The compiled CLI accepts:

```text
roundtrip MANIFEST
verify MANIFEST [--history PREVIOUS_LEDGER]
learn MANIFEST FRESH_OUTPUT_PREFIX [--history PREVIOUS_LEDGER]
```

`roundtrip` validates declarations and prints canonical current JSON. It does
not authenticate files. `verify` checks all registered WAV bytes, geometry,
headroom and supported parent mappings before printing an audit. `learn`
also verifies sources, selects training songs, learns and publishes
`PREFIX.json`, `PREFIX.wfcs`, and `PREFIX.audit.json`. The audit binds the
manifest/model hashes and retains palette centers and analysis options;
retain all three artifacts together. WFC tokens reference palette centers by
the existing `AcousticToken` mapping. Replaying the same source-bound contract
produces the same model and audit. Paths are rebased relative to the emitted
manifest directory, so publishing to another directory preserves admission.
Exact relearning/audit replay is checked within each target. The example's
manifest and WFC model are also byte-identical on checked Win32/Win64;
floating palette centers retain the underlying FFT results, whose last bits
may differ across architectures. The audit makes no general cross-architecture
floating-point bit-identity promise. Saved-model fixed-seed token generation
does not relearn those centers.

## Current declarations and coordinates

The only accepted format is `kind: "pythian-corpus-intake"`, `version: 1`,
`coordinate_units: "source_frames"`. Unknown fields, duplicate fields,
future versions, fractional integer fields, excessive nesting/counts and
invalid UTF-8/text reject. `ranges: []` means no optional explicit ranges:
the API expands one whole-source range for each source. Each expansion keeps
the supplied `single_song_id`/`song_evidence` pair, or remains unknown when
both are empty. It never infers a verified single song from a WAV file.

Families declare `id`, `work_id`, `identity_evidence`, `partition`,
`verified`, `previously_used` and `prior_exposure`. Register related takes,
masters and excerpts under one work family. Source declarations carry IDs,
paths, SHA-256, recording IDs, family indices, source sample rate/channel/frame
geometry, acquisition, complete license notices and preparation policy/hash,
acceptance and peak ceiling. Song declarations are exact caller evidence,
not automatic boundary detection. All first/end coordinates are zero-based
Int64 sample-frame offsets, with exclusive ends, never interleaved sample
indices or seconds. Families cannot cross partitions; previously used or
training/development-exposed families cannot become untouched evaluation.

Original WAVs have `parent: -1`, `parent_first_frame: 0`,
`parent_end_frame: frame_count`, and `parent_gain: 1`. A prepared derivative
references an earlier registered parent and uses its frame clock. Supported
mapping is an exact-frame crop and positive uniform gain up to 16, retaining
the same rate and channel layout. Native admission verifies the decoded
sample relation, allowing at most `(1 + gain) / 32768` quantization error for
PCM16 re-encoding. The preparation-policy digest binds the policy bytes to
their declaration; it does not independently establish approval or provenance.

Resampling, downmixing, channel rearrangement, time warps and other parent
transformations are unsupported and reject. Intake does not convert audio.
Use unchanged supported original WAVs or the supported prepared route. A
resampled derivative must not be relabelled as an independent original to
bypass mapping checks. Earlier prepared-corpus evidence retains its original
ledger and scope; this contract does not automatically import it.

Ranges declare source index, `first_frame`, `end_frame`, song ID/boundary
evidence and explicit multiplicity 1..64. Both song text fields empty means
unknown. Unknown spans remain in duration reports but are excluded from
training. Known training ranges overlapping declared unknown spans reject.
Entirely unknown training input rejects. Each known song becomes a separate
learner segment. Measurement windows must fit entirely inside the range;
for a nonzero start the first selected feature also excludes preceding flux
context outside the song. Short ranges with no complete context-contained
window reject. Storage batches never become artificial song boundaries.

Coverage unions intervals in original recording coordinates, across
registered crops/masters, regardless of duplicates or weights. It reports
only selected ranges; unselected source time is not corpus coverage. Unknown
time has its own union. Exact duplicate training rows coalesce once; other
overlaps reject instead of silently weighting repeated audio. Declared
verified group counts are family counts, not asset or master counts.

Hashes establish byte identity, not musical independence. Callers must provide
honest work/master relationships, identity/boundary evidence, complete notices
and exposure from outside this manifest. A retained complete identity ledger
can be supplied with `--history`: known work/recording/hash associations cannot
change family/partition, erase exposure, or rewrite exact-source preparation
and original coordinates. Concealed aliases or an omitted outside ledger
cannot be discovered from these declarations.

## Bounds and failed publication

The portable contract supports at most 32 sources/families, 4096 ranges,
4096-byte text values and exact frame coordinates through 2^53-1. The native
current JSON limit is 4 MiB with nesting at most eight. Actual WAV admission
uses the existing decoder envelope: supported little-endian RIFF/RF64
PCM8/16/24/32 or IEEE float32, mono/stereo, at most 256000044 encoded bytes
and 64000000 interleaved samples per source. Nonfinite samples reject; every
source must satisfy its declared peak ceiling strictly below unity.

This native learner uses in-memory journals with the existing aggregate
65536-feature and 2000000000 FFT-work ceilings, shared training geometry,
and existing palette/WFC count/state limits. Analysis uses the existing
default window 4096, hop 1024 and silence RMS 0.0001. It makes no many-hour
claim and does not raise those bounds to satisfy a test. Admission/analysis
preparation is sequential and single-use; source modification during borrowed
use is unsupported. Files stay open denying writes where supported, and hashes
are rechecked before publication.

Publication requires a fresh output prefix. Invalid admission or learning
does not touch an existing valid result. Fully computed candidates are saved
in a reserved sibling `.publishing` directory and the staged manifest is
reloaded before publishing. The audit is moved last as the completion marker.
Caught publication failures roll back files moved by that invocation.
This is not a multi-file atomic replacement or power-loss transaction:
interruption can leave incomplete files/staging for caller inspection.
Another publisher's existing staging is preserved. Keep generated media,
private manifests, logs and artifacts under ignored `build/`; publish no
private media or local paths in repository evidence.
