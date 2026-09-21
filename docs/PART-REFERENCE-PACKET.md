# Using the external part-reference packet

[Evaluation](PART-EVALUATION.md) · [Preparation](PART-PREPARATION.md) ·
[File operator](EVALUATION-OPERATOR.md) · [Task](TODO/NS-3_parts_01.md)

The two-family packet combines bounded WAV sources, source-local annotations,
explicit unknowns and reproducible native scoring cases. It supplies reference
preparation evidence; it does not contain an accepted mixture learner. Source
assets and generated manifests remain under ignored `build/`.

The accepted batch-26 container has 217 files / 29,908,178 bytes, manifest SHA256
`1f0fd839398b144d2796c8ad6abd47216c60e5bebb44b1ab20bff94e7d4ae546`.
Exact replay, preservation and all sixteen relocated CLI cases pass on checked
stable Win64. This accepts packet assembly; missing acoustic annotations keep
the full reference task open.

## Contents and supported meaning

`build/role-two-family-packet/qa-a/` contains `development/`, `evaluation/`,
the frozen family decision, `SCENARIOS.md`, `case-inventory.json`, reconstruction
instructions and the top manifest. Each family retains ten stems, its exact
derived mix, complete source notices, waveform/score evidence, source and
preparation identities, annotations, case bindings and reports. Historical
development inventory flags remain unchanged; the top scenario ledger records
the current qualification and coverage without rewriting past evidence.

The development side contains seven cases: bass copy/omit, chordal copy/omit,
lead copy/omit and an uncertain full-mixture contribution case. The reserved
side contains nine: bass copy/omit, sustained-chordal copy/omit, chordal-stabs
copy/omit, lead copy/omit and an unknown full-mixture case. Cases use relative
local paths and can be scored after moving the complete container elsewhere.

Known development evidence is one bass interval, two triad centers and four
lead centers. The reserved side currently has one bass center. Reserved
chordal/lead complete sets, note intervals and rests remain unknown. An empty
positive-label list produces an unknown grid, never a rest grid or a perfect
score. The scenario ledger explicitly retains missing external crossings,
same-pitch overlap, quiet-part ownership and acoustic boundary coverage.

These are reference-derived copy/omit scripts, not trained predictors. All
accuracy and independence verdicts remain false. Successful execution means
the case and report are valid. Zero known reference denominator cannot establish
accuracy. Reference-only exposure of the evaluation family is separate from
tuning; future model-training overlap remains unknown.

## Native scoring

Build the maintained `tools/pythian.evaluate.lpr` with the supported checked FPC
toolchain, `-Fusrc -Futools` and isolated output directories, as described by the
[file operator](EVALUATION-OPERATOR.md). From any working directory, run:

```text
pythian.evaluate PACKET/development/bass-copy-case.json
pythian.evaluate PACKET/development/chordal-copy-case.json
pythian.evaluate PACKET/development/lead-copy-case.json
pythian.evaluate PACKET/development/mix-contribution-case.json
pythian.evaluate PACKET/evaluation/bass-copy-case.json
pythian.evaluate PACKET/evaluation/chordal-copy-case.json
pythian.evaluate PACKET/evaluation/chordal-stabs-copy-case.json
pythian.evaluate PACKET/evaluation/lead-copy-case.json
pythian.evaluate PACKET/evaluation/mix-unknown-case.json
```

Use the corresponding `-omit-case.json` paths for the seven omission controls.
The packet README lists all sixteen commands. Compare reports with the bundled
`*-report.json` files; the CLI's terminal line ending is presentation only.
The consumer verifies bound source, preparation, annotation, scoring, prediction
and lineage identities before evaluating. Do not edit a frozen case to make a
failed reference or independence gate pass.

## Reconstructing the private packet

Reconstruction requires the recorded source cache and frozen preparation/review
inputs. A clean library checkout does not include these external assets. Follow
the [source preparation contract](PART-PREPARATION.md) for source binding, fixed
gain, quantization, exact-sum construction and failure preservation. Export the
fixed first 30 seconds plus 250-ms halo through the bound native worksheet tools.
The assembly sources and their policies record all accepted input hashes.

Compile the private Pascal assemblers with checked stable Win64, repository
`src/` and `tools/` search paths, and separate unit/executable output directories.
The development and reserved assemblers take one fresh output child beneath
their respective `build/role-center-reference/` and
`build/role-evaluation-packet/` roots. The container assembler takes the exact
accepted evaluation manifest SHA256 and a fresh child beneath
`build/role-two-family-packet/`:

```text
assemble EVALUATION_MANIFEST_SHA256 build/role-two-family-packet/NEW
```

It binds the accepted development manifest, copies and verifies both complete
subpackets, checks all case dependencies and publishes the top manifest last.
The source-specific preparation and assembly programs remain ignored evidence
utilities; maintained library APIs and the scoring consumer are the reusable
interface. Full raw spectra remain in their separately bound private caches;
their manifests and annotation decisions accompany the packet. Reconstruction
uses those caches; relocated scoring requires only the complete case packet.

Use fresh output directories. A failure preserves inputs and accepted outputs;
an incomplete directory without a completion manifest is not a packet. Replay
must reproduce every artifact and manifest byte. Packet integrity, annotation
adequacy and learner accuracy are separate acceptance decisions.
