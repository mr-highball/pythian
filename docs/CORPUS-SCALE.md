# Corpus workload preparation

[Corpus identity](CORPUS-EVALUATION.md) · [Native observations](NATIVE-INFERENCE.md) ·
[Raw scale task](TODO/NS-5_scale_03.md) ·
[Semantic scale task](TODO/NS-5_scale_01.md)

The 2026-09-25 task-flow split assigns source-bound multi-recording Pascal raw
observation assembly and its actual measured workload to `NS-5_scale_03`.
`NS-5_scale_01` retains admitted events, semantic learning and complete
pipeline qualification. The credit total and all original scope are unchanged;
neither task is accepted by this split. The schedule and source packet below
predate the split and are prospective until executed with the accepted
Pascal-only producer.

The prospective development workload contains the full native WAV-C conversion
and the complete Pixel Sprinter and Opening Theme identity-pilot recordings.
Its original-coordinate union is
`395311368/48000 + 1512000/44100 + 3969000/44100` seconds:
8359.939214285714 seconds, approximately 2.3222053373 hours. Ceiling resampling
does not add original coverage. Excerpts, gain variants and repeated observations
add no unique time.

These are three recording inputs, all previously exposed development material.
WAV-C is one conservative recording group with unresolved internal song boundaries;
this declaration does not turn it into independent songs or verified style coverage.
The two pilot groups retain their accepted identity evidence. Original/prepared
hashes, conversion reports and source-clock mappings remain mandatory. The full
native WAV-C conversion is not one of the quarantined clipped legacy excerpts.

## Prospective execution limits

The former pinned observation adapter emitted raw pitch salience and AC RMS;
it did not admit notes. Its 100-observation/second schedule projected five jobs,
835995 observations and 1217208720 payload bytes plus headers/checksums. This
schedule and payload are provisional for the required Pascal-only producer and
must be requalified with that producer before execution. All prepared
inputs are 16000-Hz stereo; the original inputs are 48000-Hz stereo for WAV-C and
44100-Hz stereo for the pilot. Channel zero is selected explicitly.

WAV-C requires three adjacent processing scopes because each job permits at most
one hour. Every scope retains the full source's waveform-support bounds. The two
pilot recordings require one job each. Each successful job hashes the complete
source twice: during initialization and again after observations, before sink
completion. The three WAV-C jobs therefore require six complete source hashes;
the two pilot jobs require two each, for ten across the observation schedule.
Producer identity, notice and complete output-artifact checks are additional
work. The second source hash belongs to verification and the total job budget,
not the cold-setup measurement. The former runtime's hour result included both
hashes; it is historical evidence only.
Neither job boundaries nor delivery batches are musical run boundaries.

| Stage or resource | Predeclared ceiling |
| --- | --- |
| Cold setup per job | 30 seconds |
| Whole observation job | 30 seconds plus scope duration |
| Five observation jobs combined | 8510 seconds |
| Fresh preparation, including source/output identity checks | 1800 seconds, reported separately from cache reuse |
| Aggregation and verification | 900 seconds |
| Semantic learning and reload | 300 seconds |
| Complete pipeline | 14400 seconds |
| Aggregate live private memory, serialized jobs | 2 GiB |
| Additional working storage / raw cache | 8 GiB / 2 GiB |
| Semantic saved artifact | 32 MiB |
| Runtime observing stall / hard cancellation | 5 seconds / 2 seconds |

These are prospective ceilings, not measured corpus results. Aggregation and
learning cannot be qualified until their admission, event-density and dependency-work
contracts are fixed. If those contracts do not fit, reject the workload and revise
the declared design before measurement; do not raise a limit after failure.

The former TensorFlow C runtime's one-hour observation result remains historical
scoped evidence for that retired strategy:
360000 observations, 524160407 artifact bytes, 2420266 milliseconds total,
20313 milliseconds cold setup and 103051264 peak private bytes. It does not
qualify the required Pascal-only producer or establish the other recordings/scopes
or semantic training. Existing conversion
measurements are separately scoped and do not establish a fresh whole-pipeline run.

## Missing admission and capacity boundaries

[Recorded phrase admission](TODO/NS-3_notes_03.md) owns the missing bridge from
the requalified Pascal-only observations to admitted pitch/kind/duration, unknown intervals and
saved actual WFC learning. The semantic container validates supplied typed evidence;
it does not execute an extraction policy. Rejected frame admission, reference
annotations supplied as predictions, arbitrary manual clocks or authored tokens
cannot fill this stage. The measured onset/intensity path is a distinct supported
representation, not an implicit conversion from raw salience.

The current whole-array learner first rejects a WAV file above 256000044 bytes,
before reading frames or allocating its complete clip. It also permits at most
64000000 scalar samples: at 16000-Hz stereo, 2000 seconds. The checked FPC 3.2.2
Win32 `pythian.learn INPUT.wav OUTPUT_PREFIX` command rejected the full prepared
WAV-C (527081868 bytes, 131770456 stereo frames; output SHA-256
`1efecef983467b81e87c9f1a92954ee0f3c9d001a801db06a7aa2fa2c8da5afc`)
with exit 1 and `WAVE source file exceeds learner size envelope`. The fresh
output prefix received no files. This demonstrates the byte preflight for this
source, not whole-array training, journal-to-semantic learning or a measured
multi-recording workload. Analysis permits
65536 frames and 2000000000 work units; saved styles permit 65536 cells and 32 MiB.
The corpus source count is 32; journal training has 4096 segments; semantic styles
have 256 runs; actual WFC sequence learning permits 4096 samples and 1024 states.
All applicable limits must hold without increasing private caps. Bounded journal
reading exists, but its acoustic palette does not supply missing musical admission.
Future segmentation must retain exact original ranges and unknown/run semantics.

The scale task remains open with no completion credit. Preparation identifies
usable material and rejection boundaries; it does not yet provide executable
whole-pipeline commands or measurements. The ignored qualification packet retains
exact local identities, proposed raw-stage commands and the missing-stage ledger.

Review correction 2026-09-21: the initial preparation counted one source hash per
job. Source inspection confirmed the second full hash before sink completion;
the counts above supersede that estimate. No benchmark, budget or acceptance
result changes in this documentation correction.
