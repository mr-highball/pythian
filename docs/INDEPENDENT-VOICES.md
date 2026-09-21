# Independent learned voices and native synthesis

[Home](../README.md) · [Ensemble streams](ENSEMBLE-STREAMS.md) ·
[Chord renderer](CHORD-STREAMS.md) · [Precursor review](PRECURSOR-BOUNDARIES.md) ·
[Work](WORK.md)

The native example learns five actual WFC models: harmony, a shared rhythm-action
vector, bass, chords and melody. Each voice has its own singleton-frame vocabulary
and learned history. Exact collective harmony, pitch ranges and pair gaps couple
the voices through WFC's independent-voice graph. No combined voice vocabulary
or replacement solver is built.

[Saved WAV onset styles](WAVE-STYLE.md) add measured rhythm behavior above this
authored voice stack. A named session selectively edits onsets through WFC while
retaining accepted key/tempo states, then rebuilds dependent voice models. This
does not claim that the recording supplied the authored pitches or voice roles.
[Measured onset dynamics](ONSET-DYNAMICS.md) additionally supplies a joint
intensity pass; per-voice domains enforce its relative velocity mapping while
preserving the existing harmonic and voice-path checks.

[Saved generation preferences](WAVE-STYLE.md#grid-preference-consumer-checkpoint--2026-09-20)
now have a verified coupled grid path through repeated blends, actual audio/MIDI
and hard-lock overrides. Reports retain each provider's requested settings.
An unsupported grid request names an individually unsatisfiable provider when
one is found; rejection preserves model rules and exits with complete cleanup.

The [reusable grid API](GRID-STYLE.md) now owns this saved pass assembly,
projections, preferences, typed masks and capture. The demo retains arrangement,
CLI/reporting and rendering policy; other callers can use the same providers
without copying those tool responsibilities.

All audible content is synthesized by Pythian. Voice training starts with an authored
symbolic arrangement, optionally guided by measured WAV performance. A saved context profile supplies generated key
and tempo providers, including profiles produced by explicit WAV admission.
This does not infer independent voice notes from mixed recordings.

## Granular musical and sound controls

`TNamedVoiceSession.SetPreferences(Name, Preferences)` stages positive relative
choice multipliers independently of `SetConstraints` hard masks. Construct entries
with `MakeLayerTokenPreference(Token, Multiplier)`; multipliers are integers
1..1024, omitted choices retain one, and nil clears preferences. The caller's
array is copied. `CopyPreferences` and the provider description return detached
arrays. Unknown tokens, duplicates, invalid multipliers, weight overflow and
excessive preparation work reject before modifying the staged control.

The solver temporarily multiplies actual WFC latent-value weights for the selected
public tokens and restores those weights after each attempt. Training observation
counts and models remain unchanged. Preferences influence choices but cannot
relax a lock, invent a missing choice or guarantee an outcome. Contradiction or
bounded search failure preserves accepted results and keeps the requested edits
staged. Selective regeneration commits preferences and masks only in its actual
dependency closure; unrelated pending controls remain pending. Provider replacement
revalidates retained preferences against the candidate model.

The public consumers expose these different dependency boundaries:

| Edit | Actual generation and sounding closure |
| --- | --- |
| Saved-grid key | Only the key pass in the grid; an authored voice consumer rebuilds its key-dependent pitch material explicitly. Unknown or unsupported changing keys reject there. |
| Saved-grid tempo/BPM | Only the tempo pass in the grid; downstream conversion retimes every note using the changed clock. Unchanged token paths do not imply unchanged audio timing. |
| Grid rhythm | Onsets and dependent intensity; in coupled mode edit the joint pitch-rhythm provider and its onsets/pitch/intensity consumers. |
| Named harmony or joint rhythm | The actual voice graph descendants, including affected roles and collective coverage proof passes. |
| Bass, chord or lead | The named role, directed pair-dependent later roles, and applicable collective proof passes. Independent role paths stay exact. Inspect the returned affected/preserved pass indices. |
| Timbre, envelope, pitch/gain/pan/cutoff trajectory | Selected instrument zones and their sounding notes/stem, then the mix. Musical providers and other role instruments do not change. |

The [grid API](GRID-STYLE.md) supplies typed key/tempo/rhythm locks and generation
preferences. Saved source blend coefficients affect training evidence separately;
neither those coefficients nor preferences are substitutes for hard locks. General
grid sessions include all pending dirty roots when regenerating; the named voice
session uses explicitly requested roots. Consumers must account for this difference.

Use [`TStyleInstrument`](../adapters/wfc/pythian.wfc.instrument.pas) to bind a role's
saved timbre and envelope independently, or preserve either authored dimension.
Its existing `Zone.Voice.Automation` accepts pitch cents (relative to note pitch),
absolute frequency Hz, gain multiplier, absolute pan and cutoff Hz. Curves use
explicit output frames relative to note-on; they continue through release and
hold their endpoint outside their defined range. They do not stretch with tempo
or gate length. Gated envelopes use a separate note-off-relative release multiplier,
starting from the held level at the actual gate. A zero-length release cuts
immediately. [Modulation](MODULATION.md) specifies bounds, interpolation and early
release, and [saved instrument controls](WAVE-STYLE.md) describes independent sound
profiles and recorded stem comparisons.

The instrument clones automation/envelopes and owns factories made from saved
timbre. Caller-supplied factories remain borrowed: keep them alive through all
plans/playback. Plans borrow the instrument's owned sound definitions, so the
instrument must also outlive playback. Zone/control arrays and input profiles may
be freed after construction. Unsupported source frequency ranges, missing profile
capabilities, invalid curve ranges or missing note bindings raise useful diagnostics;
there is no fallback timbre or silent trajectory clamp.

The maintained independent caller fixture now includes paired preference/lock
edits, unchanged training model text, exact unrelated latent states and rendered
role samples, and independent pitch/gain/pan/cutoff/timbre/envelope sample comparisons
after freeing input definitions. Final checked stable Win32/Win64 fixtures and
six demo runs pass without leaks; all 24 baseline artifacts match. QA accepted
all five criteria in [NS-4_layers_03](TODO/DONE/NS-4_layers_03.md). Commands,
source identities and the corrected no-op timbre fixture failure are retained
under `build/granular-controls/` and `build/qa-batch-04/`. Historical grid,
recorded instrument and modulation evidence retains its documented scope.

## Provider compatibility and replacement

[`pythian.wfc.provider.contracts`](../adapters/wfc/pythian.wfc.provider.contracts.pas)
declares each output's typed vocabulary, musical clock domain, PPQ, extent,
uniform grid or fixed partition, pitch basis and canonical unknown/rest policy.
Voice outputs carry a caller-declared `RoleId`; joint rhythm outputs carry the
complete ordered `RoleOrder`. The named session derives that vector from its
actual voice names. Equal vector lengths or token indices cannot substitute for
the same ordered identities. Required inputs remain explicit WFC projections;
`CopyProvider` exposes them for named voices and `CopyInputs` for mapped sessions.

`TNamedVoiceSession.CopyContract` returns detached metadata.
`TryReplaceProvider(Name, Model, Contract, Seed, Generated, Replacement, Proof)`
validates the candidate before rebuilding its actual dependent WFC graph. A
successful replacement publishes only after full independent proof; unrelated
musical latent states and unrelated pending masks remain exact. An incompatible
contract raises a diagnostic; an expected unsatisfiable candidate returns false.
Both preserve the previous accepted result and owned models. Constructors may
optionally receive one explicit contract per musical provider.

Compatibility requires the same vocabulary, named role or ordered role vector,
clock domain, PPQ, effective output boundaries, scope, pitch basis and unknown
semantics. Current pitch-bearing codecs use absolute MIDI pitches. Relative-key
pitch, nonempty key-reference conversions and acoustic palette identities are
explicitly rejected. A new token repertoire is allowed only when actual retained
constraints and projections remain valid. The native independent-voice graph
requires aligned equal cells; it rejects unequal provider layouts.

For unequal timing, `TCompatibleProviderSession` wraps the existing
[`TLearnedLayerSession`](LAYERS.md) with the same semantic admission and owned
contracts. Its explicit projections reuse uniform-grid and fixed-partition
broadcast, start-tick and whole-cell mappings, including existing gap, endpoint
and full-coverage rejection. A rhythm-to-voice projection must use the action at
that voice's declared joint-role slot. Contracts own the layout; duplicate scope
or grid arrays in generation options are rejected. This general session retains
the underlying layer API's automatic inclusion of pending dirty roots during
regeneration; the named voice API instead keeps unrelated pending edits staged.

Optional `Source` evidence retains source hash and measurement identity, original
PPQ, tempo changes, sample rate, frame offset, original tick/frame boundaries and
an explicit conversion identity. Admission checks every retained boundary through
the existing native tempo/frame mapping. Different source/output PPQ or origins
require an explicit exact rational conversion; fractional-tick or mismatched-frame
conversions reject. The original coordinates remain available from `CopyContract`.
These fields preserve a caller's measurement binding; they do not authenticate an
external file or establish inference accuracy. Empty source evidence makes no
measured-source claim.

The maintained [independent caller fixture](../tests/pythian.tests.voices.lpr)
includes successful role replacement, contradiction recovery, semantic rejection,
ordered-role permutation rejection, source conversion ownership, mapped broadcast
and replacement, and start-tick versus whole-span behavior. Final checked stable
FPC 3.2.2 Win32/Win64 fixtures pass, with no unfreed blocks. Three demo scenarios
per target retain all 24 baseline WAV/preview/MIDI/JSON artifacts exactly.
Commands and logs are under `build/provider-compatibility/`; the five-criterion
review and tested source identities are in `build/qa-batch-03/`.
[NS-4_layers_02](TODO/DONE/NS-4_layers_02.md) is accepted. This verifies explicit
provider semantics and replacement, not role inference or listening quality.

## Named independent-voice API

`TNamedVoiceSession` in
[`pythian.wfc.voices`](../adapters/wfc/pythian.wfc.voices.pas) owns clones of the
actual harmony model, ordered joint rhythm-action model and one singleton-frame
model per caller-declared voice role. Pass names are `harmony`, `rhythm` and the
supplied unique, case-sensitive role names. A name such as `bass` describes the
caller's arrangement; it does not establish source separation or inferred role
ownership. Pitches are explicitly absolute MIDI 0..127 in 12-TET, with each
role's declared range retained. Chords retain every tone and velocity; holds and
rests use the actual companion codecs and temporal admission checks.

Construct with a `TWfcMusicVoicesGraphConfig`, the role-name array and
`DefaultVoiceSessionOptions`. The graph configuration retains harmonic mode,
per-role ranges and directed voice-pair gap/rest policies. The session copies
models, role vectors and pair constraints; source models may then be freed.
`CopyModel(Name)` returns a caller-owned independent model. `CopyProvider(Name)`
returns owned typed harmony/rhythm/voice choices and the real musical projection
dependencies, with `RoleId`, `PitchIdentity` and range fields for voice providers.
These describe the definition, not pending masks or proven position feasibility.
Ordinary assignment of returned dynamic-array records still shares arrays; copy
before mutating an additional alias.

The native session wraps `BuildWfcMusicVoicesSegmentGraph`, negotiated solving and
`CaptureSolvedWfcMusicVoices` directly. It adds no replacement solver or flattened
all-voice vocabulary. Exact harmony uses the companion's collective coverage
witnesses, so independently in-palette voices cannot silently omit a required
pitch class. Full capture independently checks latent paths, temporal holds,
joint rhythm, ranges, pairs, harmony and witnesses before publishing a result.

`SetConstraints(Name, Mask)` stages a complete, detached positional mask using
typed choice tokens. Unknown roles/tokens, duplicate positions and out-of-scope
positions reject without changing the previous pending mask. An empty token list
at a position is an explicit contradiction; a nil complete mask clears that
provider's additional restrictions. `CopyConstraints` and `HasPending` expose
detached pending state. `VoiceChoiceTokens` filters a model by a typed voice cell,
action, complete chord cardinality and velocities, with optional exact pitches or
pitch classes; an empty match is never silently relaxed.

`TryGenerate` accepts the initial result. After acceptance,
`TryRegenerate(RootNames, Seed, Generated, Report, Proof)` requests the actual WFC
descendant closure of those musical roots, including affected proof passes.
Only pending masks inside that closure participate. **Unrelated pending masks
remain pending**, and unrelated accepted tokens/latent states remain exact.
This deliberately differs from the general layer session's automatic inclusion
of unrelated pending edits: callers explicitly name every root they want applied.
Voice-pair dependencies can make a lower role's edit affect higher roles; a leaf
edit cannot change its harmony/rhythm or lower-role ancestors to become feasible.
The selective report retains actual internal pass indices: harmony 0, rhythm 1,
roles 2 onward, followed by coverage witnesses. Public names map to these indices.

Expected solve failures preserve the caller's generated result, the session's
accepted result and all pending edits; active domains restore their committed
masks. The actual search report distinguishes contradiction and exhausted budgets.
Replace or clear a rejected mask and retry with an explicit seed. Invalid requests
publish no replacement. An internal capture-proof exception is an invariant
failure, not a successful solve or a reason to weaken admission. The API does not
promise hardware deadlines, persistent solver checkpoints or preservation of
internal random-stream positions across an explicit seed change.

Time is a caller-declared uniform PPQ grid: positive `TicksPerQuarter` and
`StepTicks`, 1..1024 cells and a total tick extent fitting Integer. Defaults are
32 cells, 480 PPQ, 240 ticks per cell, seed 731, observed end required, 512 solver
backtracks and 32 pass backtracks. Disable `RequireObservedEnd` only for an
explicit prefix request; all requests start at an observed model start. This API
does not infer a beat grid or support changing-duration cells inside this solve.

There are at most **eight musical layers**: two shared providers and 1..6 roles.
At most 12 additional exact-harmony proof passes correspond to observed 12-TET
classes, each with at most seven supplier values including absence. Their bound
is 12288 proof cells / 86016 cell-value alternatives, separately from the musical
state/cell budget of 262144. Model vocabularies are at most 4096 tokens each and
order at most 64. Conservative preparation admission requires
`sum(states)^2 * (max(order) + 1) <= 16777216`; source capacity inspection retains
the existing aggregate 200000-visit and 4096-tone limits. Search budgets must be
nonnegative. These are bounded offline operations and may allocate.

### Accepted native integration — 2026-09-21

The interrupted harmony/rhythm/voice descriptor draft was compared with the last
verified provider-description package. That package ended at performance choices;
the extra variants now have a real named-session consumer and explicit role/pitch
metadata. No archive format changed. The demo's authored training, arrangement,
reporting and rendering remain tool policy; reusable graph planning, capture,
ownership, masks and generic voice-choice filtering now use the companion API.

The new independent [voice fixture](../tests/pythian.tests.voices.lpr) exercises
one-role changes, exact unrelated state and pending-mask preservation, detached
models/results, chords/holds/rests, collective coverage rejection, range/pair
rejection, recovery and the eight-layer boundary. Final checked stable FPC 3.2.2
Win32/Win64 fixtures pass, with no owned compiler warnings or unfreed blocks.
The maintained build now includes this independent caller.

Prior target-matched demo executables from source `0ecfe34` are retained under
`build/semantic-voices/baseline/`. Final comparisons pass all 24 WAV, preview WAV,
MIDI and JSON identities across the ordinary demo, saved cell-style path and
changing-tempo duration path on both targets, with identical seeds/options and
frozen input artifacts. Two-target builds, commands, input hashes and replay logs
remain under `build/semantic-voices/`; the criterion audit is under
`build/qa-batch-02/`. No broad suite was repeated. This accepts
[named voice mechanics](TODO/DONE/NS-4_layers_01.md), +6 NS-4 points (+0.90 overall),
without claiming inferred roles or listening quality.

## Reusable capacity admission

`WfcIndependentVoiceCapacities(models)` in
[pythian.wfc.music](../adapters/wfc/pythian.wfc.music.pas) accepts one borrowed
sequence model per output voice. It scans the complete public vocabulary of each
model, requires exactly one voice in every token, preserves full chords and
returns detached maximum tone capacities in model order. Rest-only roles have
zero capacity; the native renderer supports an entirely silent configuration.

It shares the existing ensemble scan and checks pitch 0..127, velocity 1..127,
1..4096 model roles and total maximum tone capacity at most 4096. One aggregate
inspection budget of 200000 visits counts every decoded voice and tone across
all models. Per-model public vocabulary count is also bounded at 200000.
Invalid models or exhausted budgets publish no replacement result.
`WfcEnsembleCapacities` retains its existing combined-model behavior.

The returned capacities are directly usable by `TChordStreamRenderer`.
No WFC voice-graph type leaks into the portable core. Musical/path validation
remains with the actual companion; capacity admission is not a music validator.

## Measured duration driving dependent voices

```text
pythian.voices.demo OUTPUT.wav --style PROFILE.pys --duration-spans COUNT [--duration-lock CELL:TICKS] [--pitch-lock CELL:NOTE] --verify
```

This mode loads the current [saved duration style](PITCH.md#saved-duration-styles),
including second blends, and solves three actual WFC provider passes. By default,
key and tempo each use one prefix state from a single-valued model and explicitly
hold across 1..64 performance spans. The independent key and tempo scopes below
support changing context without changing performance-span counts. Performance retains the saved joint
pitch/kind/duration tokens and its own prefix history. A selective performance
edit preserves accepted key/tempo states before rebuilding the five dependent
harmony/rhythm/bass/chord/melody models and solving their actual WFC paths.
One-span requests use order-one dependent voice models; longer requests retain
order two. This avoids requiring an unobserved history position in a singleton
performance. Logical bar padding remains excluded from training.

The measured pitch supplies melody. Its duration supplies all three voice gates;
bass/chord pitches, velocity and timbre remain authored arrangement choices.
Unknown and silence remain distinct evidence kinds, both arranged as rests.
This is supported monophonic performance guiding accompaniment, not extraction
of bass/chords from the recording. It requires a known key at each performance
start and PPQ 480. Cell rhythm/intensity locks and coupled-cell mode do not apply.
An explicitly [onset-assisted duration style](PITCH.md#explicit-onset-assisted-duration)
can supply repeated same-pitch attacks without requiring a measured silence gap.
It uses the existing joint performance pass and rebuilds dependent voices.

WFC's score contract requires complete measures. Its logical score therefore uses
240-tick cells and trailing rests to finish a 4/4 bar; training selections exclude
those padding cells. `ProjectRetimedWfcNotes(score, quantum, lengths)` projects
exact source cell boundaries into cumulative native note timing. Only trailing
source rests may lie beyond the requested prefix; unaligned events and sounding
notes outside it reject. The owned result retains PPQ, tempo values, pitch,
velocity and track/voice identity. The original WFC score retains meter/names.
No inferred beat grid or historical format reader is introduced.

Native audio and MIDI end at the requested measured endpoint, including unknown
trailing spans, without bar padding. Per-cell lengths drive both native and WFC
streaming preview renderers; `--verify` checks exact preview PCM parity. Native
MIDI round-trip verifies the realized notes/timing; this mode does not claim MIDI
byte parity with the differently timed logical WFC score. MIDI's authored 4/4
signature is not inferred from the recording. Stereo articulation fits inside
each gate, leaving unknown/silent intervals exactly zero.

Reports retain saved provider hashes/tokens/states, measured span boundaries,
five voice models and paths, logical score/segment positions, realized segment
positions and output hashes. Retain the input PYS for complete evidence/lineage.
The ordinary offline build checks an eight-span second blend and independent
tempo selection. The optional [recorded workflow](../tools/recorded-pitch.ps1)
checks a three-span acoustic second blend and an observed duration edit. See
[the work record](WORK.md) for compiler evidence and remaining scope.

## Independent tempo scope for measured performance

```text
pythian.voices.demo OUTPUT.wav --style PROFILE.pys --duration-spans 32 --duration-tempo-cells 32 --verify
pythian.voices.demo EDIT.wav --style PROFILE.pys --duration-spans 32 --duration-tempo-cells 32 --duration-tempo-lock 3:600000 --verify
```

`--duration-tempo-cells` selects 1..1024 actual tempo-pass cells at the saved
context profile's PPQ step. Performance retains its independently selected
1..64 span count. Both providers solve their own prefix paths. Tempo cells must
cover the full generated performance; an endpoint inside the last used cell
is allowed, while an uncovered tail rejects before outputs are written.
Unused generated provider cells remain visible in the report. No observations
are repeated to enlarge a short model.

`--duration-tempo-lock CELL:US` edits the named tempo pass through actual WFC
selective regeneration. It preserves accepted key/performance latent states and
logical voice frames. Duration/pitch edits similarly preserve every accepted
tempo state. These are separate controls; a pinned value must be in the observed
vocabulary and satisfy its model path. A tempo edit changes playback time and
does not claim a different measured note duration.

The reusable `TempoClockFromTokens` adapter builds the finite output clock.
Core `TTempoMap.Intervals` partitions a requested tick range at tempo changes.
`TimeWfcEnsembleFrame` turns those parts into detached playback frames: the first
retains the learned action and later sounding parts hold the same notes. Rests
stay rests. Native and actual WFC previews consume those same timed parts; MIDI
and complete stereo rendering retain full original note gates across changes.
The five learned voice paths still have one position per performance span.

Reports distinguish original `frames`/`performance_spans` from
`playback_parts`, which include the original cell, physical-clock tick range,
tempo and continued voice frame. `tempo_cells` records values at performance
starts; it is not the complete changing playback clock. Exact provider resolution
and generated states are in `duration_tempo_step_ticks`,
`duration_tempo_cells` and `duration_providers`.

The maintained changing-context style is derived from the saved normalized
second blend. With seed 731 it generates 45 notes in 220500 frames; pinning tempo
cell 3 to 600000 us/quarter moves the change from tick 1920 to tick 720 and produces
231525 frames. The latter change occurs inside a sounding span: three voices
continue as holds and all 45 MIDI gates remain intact. Key, performance and
logical voice states are identical. The native verifier independently matches
every MIDI tempo event to its provider cell, checks each playback part, and
requires a sounding internal change in the edited fixture.

Focused stable/development Win32 playback and report artifacts match exactly.
Stable Win64 cross-loads and checks the same output. A short tempo scope preserves
all prior output files on rejection. The recorded flute/bassoon held example
retains its preceding WAV/MIDI/preview bytes. Evidence:
`build/duration-context-trunk/{checks,workflow,replay}.log`,
`build/duration-context-win64/checks.log`. Broader recorded inference remains
open. No archive layout or version changed.
The complete checked stable Win32 build also passes:
`build/duration-context/full-stable.log` and `full-status.log`.

## Independent key scope for measured performance

```text
pythian.voices.demo OUTPUT.wav --style PROFILE.pys --duration-spans 32 --duration-tempo-cells 32 --duration-key-cells 32 --duration-key-lock 8:0:major --verify
pythian.voices.demo EDIT.wav --style PROFILE.pys --duration-spans 32 --duration-tempo-cells 32 --duration-key-cells 32 --duration-key-lock 3:2:minor --verify
```

`--duration-key-cells` selects 1..1024 actual key-pass prefix states on the saved
context grid. Its count is independent of tempo cells and performance spans.
`--duration-key-lock CELL:ROOT:major|minor` selectively regenerates only key;
roots are 0..11 and minor means natural minor. The pin must satisfy the saved
model's vocabulary and path. Every accepted tempo/performance state is retained.
Default held mode still requires a single-valued key model.

`KeyChangesFromTokens` validates all generated tokens and finite coverage,
compresses equal adjacent keys, and returns detached changes for `TMusicContext`.
The operator samples this timeline at each performance-span start, requiring a
known key. Core `MapDiatonicPitch` maps the authored C-major accompaniment's
scale degrees and tonic-relative octaves into that key. It rejects chromatic
source pitches, unknown keys and results outside MIDI range. In changing-key
mode authored guide pitches are fixed, so an edit preserves their degree and
octave choices. Held mode retains its existing compatible voicing choices.

Only new attacks use the new key. A key boundary inside a sounding note neither
splits its gate nor retunes it. The measured melody keeps its absolute pitches;
it is not transposed to imply additional measured evidence. Tempo changes can
still split playback into holds under the preceding timing contract. Reports
include provider states, `duration_key_cells`, `duration_key_step_ticks`,
`key_lock`, the accompaniment policy, and each performance span's key root/mode.

The maintained fixture adds a caller-authored C-major/D-natural-minor provider
above the measured second blend. Its admission policy explicitly distinguishes
that arrangement from source-key measurements. Comparing the two pins above
changes 20 new accompaniment tones while retaining all 45 gate endpoints,
velocities, melody pitches, tempo/performance states and already sounding notes.
The combined tempo edit additionally verifies preservation of the accepted key
and logical voices. Native MIDI and actual WFC preview checks pass. Eight Win32
artifacts match stable/development compilers; stable Win64 cross-loads and checks
the same outputs. Recorded held-mode WAV/MIDI/preview bytes remain unchanged.
Evidence: `build/key-context-trunk/{checks,replay,workflow}.log` and
`build/key-context-win64/checks.log`. These controls use the current style format.
The complete maintained stable Win32 build also passes
(`build/key-context/full-stable.log`, `full-status.log`), including short-key-scope
rejection preserving all four accepted outputs. Its four combined key/tempo-edit
artifacts match development Win32 exactly.

## Example workflow

```text
pythian.voices.demo OUTPUT.wav [SEED [SEGMENT_CELLS]] [--context PROFILE.pcp] [--verify]
```

Defaults are seed 731 and five cells per segment; accepted segment size is 1..32.
The example has a fixed 64-cell, eight-bar extent, PPQ 480 and 240 ticks per cell.

Cell-style generation accepts `--style-extent whole|prefix|fragment` after its
`--style` argument. It explicitly selects actual WFC source-boundary semantics
for all provider passes. Defaults remain whole for onset styles and fragment
when measured pitch runs require it. A prefix preserves observed beginning
history without requiring a learned ending at cell 64; it may extend using
compatible learned transitions. The report records the selection. This option
does not change the five downstream voice-model whole paths or the output clock.
Duration mode retains its separate explicit prefix scopes.

1. Build two authored 32-cell phrases as a validated WFC score with bass, full
   triads and melody/rests. Common excerpt boundaries do not cut sounding notes.
2. Use `BuildWfcMusicVoicesTrainingBundle` to create five detached training
   documents. Learn each through `LearnWfcTrainingModelText`, retaining the actual
   order-2 model text. No hand-built transition table replaces learning.
3. Solve one bounded 64-cell independent-voice graph with an authored
   C–Am–F–G–C–F–G–C harmony guide and the training rhythm. Voice selections remain
   learned graph choices. The plan has observed starts/ends, exact harmony,
   explicit ranges and noncrossing pair constraints. WFC independently captures
   and validates it before use. Limits are 512 within-pass and 32 pass backtracks.
4. Realize every model's planned tokens through `TWfcMusicVoicesStream`, with
   its own 256/16 search limits. Check every segment's exact predecessor,
   latent path, emitted tokens, derived seed and agreement with the full plan.
5. Admit the assembled frames to the existing native clock/chord bridge, retaining
   held phase and delayed release between segments. At cell 35 the tempo changes
   from 500001 to 600001 microseconds per quarter, through held notes.
6. Reconstruct the complete generated score, project detached Pythian notes and
   render stereo bass, chord and melody bindings with separate envelopes, filters,
   pan and polynomial oscillator quality.

The initial locally solved streaming experiment hit a finite search failure at
segment 2 (`build/voices-stable.log`). A globally constrained phrase can require
choices beyond the current segment. The finite planning step resolves that
dependency without relaxing musical constraints or silently retrying with larger
budgets. Free generation does not inherit the example's fixed-plan guarantees.

Outputs are:

- `OUTPUT.wav`: native stereo triangle bass, filtered saw chords and square
  melody, with explicit ADSR and a 120 ms final release.
- `OUTPUT.wav.preview.wav`: the extracted mono triangle preview, with release
  inside gate endpoints and exactly the source score's duration.
- `OUTPUT.wav.mid`: native note/tempo export in one format-0 track, with bass,
  chords and melody on zero-based channels 0, 1 and 2. The native frame stream
  retains the declared initial 4/4 meter; instrument programs and synthesis
  timbres are not encoded. The complete score remains in JSON.
- `OUTPUT.wav.json`: full training score/documents/models, model hashes, generated
  score/frames, segment tokens/states/frontiers, policies, synthesis bindings and
  audio/MIDI hashes and the explicit MIDI channel per synthesis role.

The preview runs incrementally, with a release ring of 883 frames at 44100 Hz.
The finite operator tool deliberately retains the 64-cell plan, generated frames
and preview WAV in memory, then renders the complete stereo clip. It is not an
unbounded stereo synthesis consumer. Generation and verification precede file
writes; the four writes are separate and are not an atomic filesystem transaction.

## Saved context feeding the voice stack

With `--context`, the operator reloads a [saved context profile](CONTEXT-PROFILES.md),
copies its actual key/tempo models, releases the profile and solves two WFC
provider passes over the output's 64 cells. It requires exact PPQ 480 / step 240.
Both source profiles and repeatedly derived selections are accepted.

The generated key must be known and constant across the phrase. Major and
natural minor are supported. The authored C-major source is mapped by scale
degree to the selected key: minor lowers degrees 3, 6 and 7; the root shifts
the register upward by 0..11 semitones. The operator rebuilds all five dependent
training models and their harmony/rhythm guide from that mapped score. Voice
ranges move with the mapping; actual WFC collective harmony, pair gaps and
stream/path validation remain in force. The source's rhythm and phrase shape
are still authored. This is an explicit arrangement policy, not learned WAV
voice style or inferred instrument identity.

Generated tempo can vary at every cell. The same timeline drives the incremental
preview, complete stereo score and MIDI events, including tempo changes through
held notes. The original no-profile command retains its authored tempo change.

This is hierarchical coordination: two context passes settle first, then five
voice-stack passes are rebuilt and solved. There is no reverse negotiation from
voice failure to context, implicit retry, or general dependency cache. Unknown
keys, changing keys and incompatible grids reject before output writes; callers
can select a compatible provider explicitly. Key modulation needs a scoped
voice/hold policy. Independent key/tempo selection introduces no joint evidence.

The context report uses `pythian.voices.context.demo.v1` and records profile and
provider identities, both context model texts, generated tokens/latent states,
selected key and every tempo cell, alongside the existing voice proof and audio
hashes. Retain the input profile for complete source lineage. The renderer trusts
its already admitted context and does not reopen an external WAV measurement
report; [WAV admission](WAVE-CONTEXT-ADMISSION.md) describes that binding.

### Context verification

Checked FPC 3.2.2 and 3.3.1 i386-win32 runs pass:

- An authored D-natural-minor profile with two tempo values. Generated tempo
  changes at cell 36 for seed 731; source training changes at cell 35. The model
  learns local transitions, so source change positions are not output locks.
  An independent rational sum checks all generated tempo cells against the
  rendered duration, and every generated voice tone belongs to D natural minor.
- A derived profile combining the native C-major WAV's key with Pixel Sprinter's
  explicitly declared tempo (428571 microseconds per quarter). This is an audible
  use of selected WAV-derived context, with authored voice material.
- Actual companion preview PCM and MIDI byte parity, native MIDI round-trip,
  complete voice planning/stream proofs, and source-profile/audio hash binding.

Both variants emit 88 notes over 64 cells / 13 segments, with 21 continued voice
holds. D minor emits 767341 preview frames and 772633 stereo frames; the selected
WAV-context variant emits 604799 / 610091 frames, all at 44100 Hz. Their four
artifacts each compare byte-for-byte across compilers. Stable-compiler unknown,
changing-key and grid failures preserve all four existing output files. The
default command's WAV, preview, MIDI and JSON match the preceding full build.
Seven-cell realization of the D-minor plan produces ten segments and sixteen
continued holds with identical stereo, preview and MIDI bytes to five-cell
realization; its segment report intentionally differs.

Logs/artifacts: `build/context-voices-{stable,trunk}/` and
`build/context-voices-replay.log`. The maintained build now includes the context
fixture/render/check workflow. This is focused validation; full-suite/package
refresh and additional target evidence are not claimed.

## Original example verification

The [music fixture](../tests/pythian.tests.wfc.music.lpr) now checks full singleton
vocabularies containing rests followed by chords, detached capacities, rejection
of a combined-voice token and a missing model. Existing score/clock/SMF checks
also pass after the shared scan refactor.

With `--verify`, every native preview sample is compared with the actual
`TWfcMusicEnsembleAudioRenderer` fed the same generated independent-voice frames.
The complete score clock separately agrees with incremental timing. Every generated
note has a native synthesis binding and renders; no sub-frame note is omitted.
Verification also strictly decodes the native MIDI output and matches every
generated gate, pitch, velocity and assigned channel exactly once, along with
PPQ, extent and all tempo changes. Complete MIDI bytes also match the actual
WFC full-score exporter. [Chord MIDI](CHORD-MIDI.md) records the bounded frame
transport, shared native data and current 793-byte output. The earlier
[finite-note export](MIDI-EXPORT.md) checkpoint remains separately recorded.
Stereo PCM is deterministic across compilers, but it intentionally uses different
timbres/envelopes from the preview and is not asserted equal to WFC preview PCM.

Checked FPC 3.2.2 and 3.3.1 i386-win32 runs produce:

| Result | Value |
| --- | --- |
| Learned models / generated cells | 5 / 64 |
| Five-cell segments / continued voice holds | 13 / 21 |
| Preview samples | 769546 mono frames, 44100 Hz |
| Stereo samples / notes | 774838 stereo frames / 88 notes |
| Stereo duration | 17.5700 seconds |
| Stereo channel peaks | 0.354553 / 0.410004 |

Stereo SHA256:
`b70aaa5e307387a3e936081931b6296592e86f1df67ed30936fe09b1a6ac0340`.
Preview SHA256:
`d3000c49f3f173ffa4bc40dcf83951dc0f6d52beacb1077dc36a07efb1049d2d`.

Logs: `build/voices-stable-checked.log`,
`build/voices-development-checked.log`, `build/voices-compiler-replay.log`.
Both compilers reproduce WAVs and JSON exactly. Seven-cell realization produces
10 segments and 16 continued holds with identical stereo and preview bytes
(`build/voices-segment-replay.log`). This invariance depends on the fixed full
plan; changing free-stream segment size can change its choices.

The original combined-ensemble demo still reproduces its WAV and report with
the shared capacity scan (`build/voices-ensemble-regression.log`).
Native stereo inspection is `build/voices-stereo-inspect.json`.
The normal build includes this example and its verification mode. The current
[52-unit packages](PACKAGING.md#earlier-fifty-two-unit-package-checkpoint) reproduce all four recorded
outputs from extracted library/companion sources, including chord-frame MIDI,
full-score byte parity and the strict note round trip. The historical fifty-unit
packages retain their earlier finite-note MIDI evidence.
Browser and additional platform results remain outside this evidence.

This closes the native independent-voice consumer gap identified by the precursor
review. Authored guides and a small symbolic corpus do not establish learned
macro-form, broad compositional quality or WAV-to-voice transcription. Recorded
pulse/event learning remains a separate implemented path with explicit uncertainty.
