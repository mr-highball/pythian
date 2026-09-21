# Musical precursor boundaries

[Home](../README.md) · [Extraction inventory](PROVENANCE.md) · [Work](WORK.md)

This review covers the complete WFC score, MIDI import/export/stream transport,
form, monophonic sequence/training/projection and score/composition text units,
ensemble and independent-voice training, graph, pass and stream units, the sequence-domain
analyzer, and Phanes's music types, dimension
widget and audio browser entry point. It uses the pinned revisions in the
[project profile](../PROJECT.md#dependencies). Source review alone does not prove
runtime behavior; linked consumer evidence identifies the executed contracts.
The subsequent [reference removal audit](REFERENCE-REMOVAL.md) passed; Phanes's
temporary submodule is removed, while WFC remains the companion.

## Form planning

`wfc_music_form.pas` supplies a finite caller-owned catalog of harmonies, gestures
and exact realizations. Its grammar cycles question, answer, contrast and return
phrases, with special treatment of the final phrase. It assigns harmonic functions,
motif identities and half/authentic cadence requirements. This grammar is authored
policy; it is not learned from WAV observations.

The actual WFC graph negotiates form, harmonic intent and realization passes.
Harmony transitions restrict motion of corresponding sorted chord slots;
realization transitions restrict the previous exit pitch to the next entry pitch.
Those slots are not independently tracked contrapuntal voices. Gestures declare
attack counts, eligible roles and cadences. The acoustic consumer must verify
that its realization actually has the declared anchors and content.

The cursor retains a detached catalog and the preceding harmony/realization,
allocating one phrase graph per call. Failed search is terminal for that cursor;
already returned phrases are not repaired. Semantic validation checks detached
bar records against the grammar and catalog in addition to checking signatures.
A caller-supplied frontier is a boundary witness, not authenticated history.

Keep this planner in WFC and consume its real API when those explicit musical
policies are wanted. Pythian's clocks, notes, voice bindings and passage renderer
provide timing and sound. A WAV form adapter still needs supported bar boundaries,
harmonic-function labels, motifs, and verified entry/exit anchors. Current acoustic
palette indices and duration classes do not supply those facts. Do not synthesize
such labels from cluster numbers or present this authored grammar as learned form.

## Independent voices

`wfc_music_voices_training.pas` creates ordinary detached training documents for
shared harmony, an ordered rhythm-action vector and each selected voice. Each
voice emits the existing singleton ensemble-frame format, including full chords
and velocities. Harmony is the union of sounding pitch classes. Voice/track
provenance stays outside learned tokens. All roles use common excerpts: edges
may crop rests but must not cut a sounding span in any selected voice. Aggregate
sample, token, encoded-content and visit budgets are checked before retaining
the complete bundle. Copy methods return independently owned documents.

`wfc_music_voices_graph.pas` builds separate learned passes rather than enumerating
a Cartesian product of voice vocabularies. Each voice projects to harmony and its
rhythm action; explicit pitch ranges and pair-gap/rest policies constrain it.
Allowed-harmony mode requires a subset. Exact mode additionally requires every
declared pitch class to have a supplying voice; a canonical lowest-index supplier
avoids equivalent proof assignments. Capture independently checks original latent
boundaries, state paths, emissions, caller domains, assembled frames, harmony,
rhythm, ranges, pairs and coverage witnesses before publishing a detached result.

`wfc_music_voices_stream.pas` borrows immutable models, copies graph configuration
vectors and retains an exact predecessor state for each model. Sparse future
constraints intersect domains and expire after their cells are produced. One
bounded segment graph is solved and independently captured per call. A hook may
add constraints; changing its seed/shape or violating original global constraints
is rejected. Progress is published only after validation and allocation succeed.
Search failure is terminal, distinct from the retryable Pythian sequence-stream
contract. A segment may begin with holds and cannot be rendered as an unrelated
standalone score. Segment size contributes to solving and seed progression, so
free generation is not promised to remain identical when segment size changes.

Retain all three units in the WFC companion. The stream's `CopyFrames` already
assembles `TWfcMusicEnsembleFrames`, the input accepted by Pythian's existing
`AdmitWfcEnsembleFrame` bridge. The native chord renderer supplies held phase and
delayed release; the incremental clock supplies exact timing. The subsequent
[independent-voice consumer](INDEPENDENT-VOICES.md) now derives each capacity from
the entire singleton-frame vocabulary, retains renderer/clock state between
segments, and keeps borrowed models alive. It exercises the actual training
bundle, independent graph, exact-harmony capture and stream, with all-preview-PCM
parity and a separate native stereo synthesis render. Its finite authored
harmony/rhythm guide is explicit; this is not WAV-to-voice transcription.
The existing [ensemble consumer](ENSEMBLE-STREAMS.md) retains its combined-model
contract and recorded parity evidence.

## Sequence analysis

`wfc_sequence_analyze.pas` is exact symbolic domain analysis, not audio analysis.
It admits extent-specific start/end/BOS conditions and token constraints, computes
forward/backward state reachability, and for wrapped extents includes the closing
transition. It returns feasible states, emitted tokens and summed observation
weights at each position, distinguishing an empty domain, missing path and
missing cycle. Weights are observed-state counts, not calibrated probabilities
of a musical interpretation. Storage grows with length times state count; native
index overflow checks are not a practical application work budget. Keep this
algorithm with WFC and impose workload limits in a consumer if used for WAV locks.

## Phanes application controls

`phanes.music.types.pas` contains the ten authored style presets, four lane
identities and fixed 32-beat section schema. Its style-weight fallback, weighted
preset tempo, explicit 60..160 BPM override and first-maximum dominant style are
application selection policies. Native notes, exact clocks and synthesis voices
cover the reusable execution concepts without adopting those preset identities.

`phanes.audio.dimension.pas` owns DOM controls, node layout, pointer/keyboard
interaction, style weights, manual/automatic tempo and playback-status display.
Its beat pulse displays supplied playback statistics; it does not analyze sound
or infer beats. `phanes.audio.browser.lpr` only calls `StartAudioUI`. Both remain
browser application responsibilities and contribute no additional core DSP.

## Score model and MIDI projection

The complete `wfc_music.pas` owns immutable symbolic scores: valid unique UTF-8
track/voice IDs, a positive timeline, integral measure boundaries, explicit
rest/note/chord spans and a complete contiguous partition for every voice.
Adjacent rests must merge; chord pitches are strictly increasing and sounding
velocities are 1..127. It copies tone arrays on input and output. Reduced rational
quarter-note helpers and exact tick conversion serve symbolic score coordinates;
their Integer arithmetic and overflow rejection are not the native audio clock.

Keep this richer score model in the companion. Native `pythian.music` and
`pythian.time` already supply detached note gates and exact playback timing, with
explicit source indices. Native gates can overlap and need not form complete
measures or contain explicit rests. Source meter, IDs, arbitrary octave-step
systems and notation stay in the WFC score. Future typed context providers must
carry supported meter/key evidence explicitly; a note projection cannot recover
discarded notation, and no score duplication is needed for native synthesis.

The complete `wfc_music_midi_import.pas` preflights format-0/1 PPQ records and
canonical byte/event budgets before timeline allocation. Global ordering is
tick/track/event; pairing is global channel/pitch with note-on track provenance.
Same-key overlaps, missing partners and zero-duration notes reject. It counts
explicitly ignored performance/SysEx/metadata, always rejects unsupported routing
metadata, validates meter notation, detects conflicting same-tick timing and
reports defaults, redundant/terminal timing and measure padding.

Import then assigns each note to the first available monophonic lane of its
source track/channel, creates deterministic synthetic IDs, inserts all rests,
and pads or rejects an incomplete ending according to policy. A silent positive
source gets one synthetic voice. Lane identity is interval allocation, not an
inferred bass/melody role. Keep lane construction, meter admission and measure
padding with WFC's complete-score contract. Native `pythian.midi.notes` already
extracts the shared global ordering/pairing/tempo behavior, while preserving exact
source extent and offering explicit FIFO/dangling-note options. It reports and
omits zero-length notes and harmless meter/key metadata instead of imposing WFC
score validity. These are documented deliberate differences, not import parity.

The complete `wfc_music_midi.pas` exports 12-step scores into a single track,
mapping voice index directly to one of 16 channels. It orders tempo before meter,
then note-offs before note-ons, with source ordinal breaking remaining ties.
Meter bytes, score validation and automatic voice-index mapping remain companion
policy. Native [note export](MIDI-EXPORT.md) now extracts the reusable ordered
note/tempo timeline using explicit channel bindings and the native byte stream.
It additionally rejects equal-pitch channel collisions and bridges long deltas
that the precursor whole-score exporter rejects. Complete bytes agree with the
actual companion export after removing only meters absent from native note data.

## MIDI stream transport

The complete `wfc_midi_stream.pas` is reviewed and its reusable transport is
extracted into native `pythian.midi.stream`. The counter retains scalar sizing
and replay evidence, then a forward writer emits format-0 PPQ data in bounded
blocks, inserting empty text events for delays beyond a single MIDI delta.
The caller supplies deterministic event replay and owns the sink. No score,
learner, instrument or playback policy moved into the core.

Complete bytes, counts and signatures match the actual WFC writer on both
installed compilers; canonical bytes also match the native whole-file codec.
Native construction explicitly rejects a plan not produced by a completed
counter. [MIDI streams](MIDI-STREAMS.md) records ownership, memory limits,
failure behavior and the native consumer. This closes only this transport unit;
the remaining text/training/pass and ensemble support dispositions stay open.

## Ensemble MIDI transport

`wfc_music_ensemble_midi.pas` has a complete source review and its reusable
incremental frame-to-event path is now extracted. The event cursor retains
only active and pending ensemble frames. Explicit unique channels map 1..16
voices; each sounding voice has 1..128 sorted unique MIDI pitches with velocities
1..127. Holds require identical active pitches and velocities and emit no seam
events. Rest/attack closes prior tones; all offs precede all ons in voice/pitch
order. Initial and explicit frame-start tempo/meter changes precede note events,
including repeated timing values. EndInput closes remaining tones at the exact
accepted end; empty input still emits initial timing and EOT at zero.

Its counter/stream wrappers use the previously extracted two-pass MIDI transport.
Configuration and plans are detached, frame lengths are positive and total ticks
fit the precursor's exact-integer envelope. The stream returns bounded blocks
without a score/timeline; invalid admission is retryable, processing/replay failure
is terminal, and cancellation discards pending output. Plan signatures remain
diagnostic FNV32, not authenticated generation checkpoints.

Native `pythian.midi.chord` now feeds `pythian.midi.stream` from the shared
`pythian.chord` data vocabulary. `ProjectWfcChordFrame` supplies detached WFC
conversion shared with audio admission. Actual companion bytes/counts/signatures,
full-channel chords, wide counting, ownership/failure and audio regression checks
pass on both installed compilers. The independent-voice consumer now streams MIDI
from frames and matches the actual full-score exporter, retaining declared meter.
[Chord MIDI](CHORD-MIDI.md) records the contract and evidence. This closes the
transport extraction without replacing the companion's learning or score model.
Meter emission is explicit input, not inference or the future context provider.

## Monophonic cells, training and pass projections

The complete `wfc_music_sequence.pas` defines canonical versioned ASCII tokens
for melody, rhythm and single-pitch-class harmony. Melody holds carry pitch and
velocity, but decoding one token only validates that cell. Whole-voice rebuilding
separately requires an attack before each run of matching holds, merges adjacent
rests and preserves repeated attacks. Projection requires a complete, quantum-aligned
monophonic score voice; chords reject. Pitch is a nonnegative Integer, not limited
to MIDI's 0..127, and harmony carries its explicit octave-step system. Its learning
helper encodes cells and calls the real sequence learner; it adds no musical
transition validation. Consumers must distinguish valid tokens, learned paths and
renderable note sequences. Whole-array projection has no practical work budget
beyond Integer checks, so bounded callers must admit the requested extent first.

The complete `wfc_music_training.pas` produces one independent sequence sample per
named, selected voice excerpt, preserving sample order and caller metadata. It
preflights selection/order/cell/token limits, total span visits and encoded
metadata/name sizes. Selected sounding spans must fit entirely within their
excerpt and align to the quantum; silence may be cropped at excerpt edges.
Every projection first extracts monophonic melody cells, so chords also reject
when only rhythm or harmony is requested. Rhythm keeps actions; harmony keeps
pitch classes and the score's octave-step system. This API does not separate
voices from mixed audio or learn relationships between separately selected voices.
Use the already reviewed independent-voice bundle for full chords and aligned
role-specific samples, and retain source/excerpt/run boundaries for WAV learning.

The complete `wfc_music_graph.pas` creates real WFC projection rules. Rhythm must
match each melody action exactly. A sounding melody permits its matching harmony
pitch class; a melody rest permits any valid harmony token, including sounding
harmony. Every harmony token must use the declared step system, and every melody
token needs an allowed projection. Named rhythm and harmony dependencies are
conjunctive at each cell, with alternatives inside each map. These are symbolic
compatibility rules, not evidence that every admitted combination was observed
together. Model vocabulary cross-products require caller workload limits. The
unit creates no key, tempo or role provider and supplies no soft blend policy.

Retain all three units in the WFC companion. Native notes, chord frames, clocks
and renderers already supply the shared execution primitives. Pythian's activity
adapter uses actual rhythm tokens with independently learned recording samples;
its cells denote analysis hops, not inferred beats. The generic layer adapter
provides bounded simultaneous projections and validates captured relationships.
No duplicated symbolic token codec, learner or solver is needed in the core.
This complete source disposition extends the earlier function-level inventory;
existing [activity](ACTIVITY.md) and [layer](LAYERS.md) runtime evidence retains
its documented scope and does not prove all of these precursor functions.

## Score and composition text

The complete `wfc_music_text.pas` serializes the companion's score contract as
`wfcmusic=1`: timing, tracks/voices, meters, tempos and explicit rest/note/chord
spans. Decoding requires ordered, contiguous record indices and exact field
counts, checks declared record counts against available lines before allocation,
constructs a validated score and requires byte-identical canonical re-encoding.
The format uses the shared WFC text codec for escaped identifiers. It materializes
the whole text, lines and score; record-count checks are not an application byte
or memory budget. It is score interchange, not a native streaming audio format.

The complete `wfc_music_passes_text.pas` serializes `wfcmusicpass=1` with seed,
quantum, cell count, three public token arrays, an eight-hex-digit composition
signature and an embedded canonical score. It preflights token record capacity,
reconstructs through `CreateWfcMusicComposition`, checks the public-data signature
and requires canonical re-encoding. The inspected constructor explicitly sets
`FHasLatentCapture` false. No model, observation count, latent state path, source
corpus, dependency graph or blend lineage is saved. A valid decoded composition
is therefore neither a learned style profile nor a generation-resume checkpoint;
its public-data signature does not establish training provenance.

Keep both serializers with their WFC-owned data contracts. Pythian's native
WAV/MIDI codecs and acoustic archives already serve different interchange needs.
Future style persistence must retain per-layer model/evidence and lineage, while
resumable generation separately needs validated model-bound continuation state.
The serializer review alone did not close the pipeline review; its complete
disposition now follows below. No parser-hardening claim is made by this review.

## Ensemble vocabulary, training and graph

The complete `wfc_music_ensemble.pas` supplies detached ordered voice frames,
rhythm-action vectors and sorted unique pitch-class sets. Each sounding voice
contains a complete sorted chord with velocities; pitch order is not an inferred
voice-leading identity. Canonical token decoders check available encoded data
before allocating declared counts. Individual and bulk codecs validate cells,
while timeline validation separately requires fixed voice arity, no initial
holds and identical held pitches/velocities. Projection/rebuilding preserves
independent attacks, merges rests and carries template notation/timing. Harmony
is the sorted, deduplicated union of all sounding pitch classes, with no inferred
chord name or key. Integer overflow checks do not supply an application work cap.

The complete `wfc_music_ensemble_training.pas` keeps a caller-selected ordered,
distinct voice vector across every common excerpt, including silent slots.
Each excerpt becomes an independent sample; original IDs and role meaning remain
caller provenance. All selected voices must admit the same quantum-aligned
boundaries, which may crop silence but cannot cut any sounding span. Projections
retain complete frames, ordered rhythm vectors or exact pitch-class sets. The
builder preflights source/selection visits, frame and expanded voice/tone counts,
history work and encoded content before complete token-array allocation. It walks
selected spans with cursors and does not first expand the whole source score.
This preserves joint events for combined-model learning; it is not independent
per-voice model learning or a mixed-WAV source separator.

The complete `wfc_music_ensemble_graph.pas` validates all observed start states
and every structural latent edge for legal hold continuation, caching checked
public-frame pairs. A corpus can contain valid individual frames yet produce an
invalid low-context model. Rhythm projections match the complete ordered action
vector. Exact harmony requires equality of sounding pitch-class sets; allowed
harmony requires only a subset. Silence therefore matches only an empty set in
exact mode, but any compatible set in allowed mode. Each ensemble token needs
an admitted projection, and rhythm/harmony dependencies are conjunctive. State
pair scans, public-pair storage and vocabulary cross-products need caller budgets.

Retain these symbolic codecs, training and constraints in WFC. The native
`pythian.chord` vocabulary, renderer and MIDI cursor already provide reusable
sound/transport behavior. The existing [frame bridge](CHORD-MIDI.md) and
[ensemble consumer](ENSEMBLE-STREAMS.md) cover conversion, model capacities and
actual streamed PCM; their evidence does not imply every training API was run.

## Finite pass pipelines and selective regeneration

The complete `wfc_music_passes.pas` owns a finite three-pass graph: harmony and
rhythm provide constraints to one monophonic melody. It borrows immutable models,
copies a one-voice score template, uses whole open sequences and captures baseline
domains. Public locks mark changed layers. Selective regeneration includes
requested roots, their dependent melody and any dirty layer outside that closure;
clearing a lock restores baseline domains. The seed setter only changes the graph
seed; it does not mark every layer dirty in this monophonic wrapper.

The complete `wfc_music_ensemble_passes.pas` similarly owns harmony/rhythm plus a
combined ensemble model, with whole or prefix extent and exact or allowed harmony.
It retains initial constraints in its copied domain baseline. All layers initially
start dirty; changing its seed marks all layers dirty. `LockVoiceCells` filters
complete ensemble tokens by one slot's exact action, chord pitches and velocities,
leaving other slots free within the learned vocabulary. It validates the complete
request before applying restrictions. An otherwise valid voice cell missing from
the vocabulary creates an empty domain, rather than inventing a new ensemble token.
Selective negotiation cannot reopen a clean provider outside its active closure;
the caller must select a provider root when that repair is intended.

Both wrappers use WFC's existing solve/negotiation transactions. Their commit hook
prepares an owned composition while entry/RNG rollback remains available. Capture
checks latent paths, emissions, caller domains, temporal holds, rhythm/harmony,
reconstructed score and public-data signature before publication. The ensemble
wrapper also checks score intervals independently of reconstruction and can run
a borrowed observational application validator inside that transaction. A failed
finite attempt publishes no composition; it does not terminally disable the owner.
Public-artifact compositions lack latent capture and fail pipeline validation.
Models are fixed construction inputs, not hot-swappable style profiles.

Keep both finite owners in WFC. They already offer useful selective regeneration;
Pythian need not duplicate them to provide synthesis. Pythian's generic layer API
still needs semantic identities, typed context, time scopes and an explicit
selective-regeneration interface. These specialized three-pass owners must not
be described as a general key/tempo/bass/voice hierarchy or a style blending API.

At the pinned revision, both unmodified companion pipeline fixtures were rebuilt
with assertions, range, overflow and I/O checks on FPC 3.2.2 and 3.3.1 i386-win32.
The monophonic fixture passed 48 checks and the ensemble fixture 99 on each.
Inspected assertions cover provider reuse, dirty closure, voice-only locking,
contradictory constraints, negotiated provider repair and rollback. Logs are under
`build/support-review-stable/` and `build/support-review-trunk/`, named
`wfc_music_passes_test-{build,run}.log` and
`wfc_music_ensemble_passes_test-{build,run}.log`. This is actual companion evidence;
it does not claim a new Pythian selective-regeneration API or other-platform parity.

## Ensemble stream lifecycle

The complete `wfc_music_ensemble_stream.pas` borrows a validated immutable model
triple and retains the predecessor state/token of each layer, exact wide ticks,
projection bindings and sparse future constraints. Every synchronous `Next`
constructs one finite graph with the original model-bound entry boundaries;
only the final segment may require an observed end. Independent capture checks
those boundaries, paths, emissions, domains, global constraints and musical
relationships. Hooks may narrow domains and observe candidates, but cannot erase
stored global restrictions or publish application progress before acceptance.

Segment construction and remaining-constraint allocation precede frontier/count
publication. Search failure or an exception during `Next` is terminal, unlike a
failed finite-pipeline attempt. Cancellation yields no further segment. Previously
returned segments remain detached and are not repaired. Future constraints may be
intersected or cleared only before their cells are produced; duplicate calls add
separate conjunctive restrictions. No public restore operation exists, and copied
frontiers or diagnostic FNV signatures are not portable authenticated checkpoints.

Keep this generation cursor with WFC and feed yielded frames to one persistent
native renderer/clock. A continued segment may begin with holds and is not a
standalone score. Retained history is bounded, but explicit constraints and model
vocabularies still consume caller-controlled storage; Integer checks alone are
not audio deadlines. Segment size changes seed progression and search partitions,
so unconstrained output is not promised invariant under different chunk sizes.
The [existing consumer](ENSEMBLE-STREAMS.md) verifies complete PCM for a fixed
plan realized through segments. This full review extends that earlier scoped
evidence without claiming a new stream implementation.

## Phanes MIDI corpus helper

The complete `tools/phanes.tools.midi.pas` now has a reconciled disposition across
all three public functions and their private helpers. `ReadMidi` accepts format
0/1 PPQ, pairs equal-pitch notes FIFO within each track, closes dangling gates at
that track's end, skips percussion channel 9 and requires twelve positive gates.
Metadata is skipped, including tempo; this is corpus gate extraction, not exact
playback timing. Native SMF/note admission already supplies explicit, counted
policies with global channel/pitch pairing and tempo retention. Those differences
are intentional. `ScoreIdentity` normalizes earliest onset, minimum pitch and PPQ,
sorts/deduplicates rows and omits velocity; it remains curation policy rather than
exact source identity. `ExtractSamples` supplies the already extracted capped
duration histogram and tonic/fifth-biased tonal fit. Its forced scale degrees,
three 32-beat windows, high/low-note selection, sixteenth masks and density bins
remain application feature recipes. No additional core audio behavior remains
to extract from this unit; [provenance](PROVENANCE.md) retains the earlier runtime
note/tonal evidence and deliberately different native policies.

<a id="inventory-still-to-close"></a>

## Completed source inventory

The formerly open six-unit list is now closed by the complete dispositions above.
The [main inventory](PROVENANCE.md#current-extraction-inventory) accounts for the
pinned WFC music/MIDI source units and the identified Phanes audio/music sources
and corpus helpers. General WFC solving stays in the retained companion; Phanes's
scene, geometry, asset-catalog and browser host infrastructure is outside audio
extraction. Source review and function-level runtime evidence retain distinct scopes.

The subsequent [removal audit](REFERENCE-REMOVAL.md) reconciles this inventory,
retained notices and independent 52-unit packaged consumers, including the latest
chord MIDI path. Phanes's temporary reference is now removed. No further audio
behavior was identified for extraction from these six WFC support units or the
reconciled Phanes MIDI helper. Synthesis expansion, WAV musical learning and
delivery retain their outstanding scope in the work record.
