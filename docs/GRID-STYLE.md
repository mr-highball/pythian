# Reusable saved-style grid API

[Home](../README.md) · [Layered style](LAYERED-STYLE.md) ·
[Named sessions](LAYERS.md) · [Duration performance](PERFORMANCE.md) ·
[Independent voices](INDEPENDENT-VOICES.md)

[`pythian.wfc.grid`](../adapters/wfc/pythian.wfc.grid.pas) owns the uniform-grid
providers of a current saved WAV style. It builds actual WFC passes and captures
typed musical values without file I/O, JSON, synthesis voices or a fixed PPQ.
It belongs to the companion adapter; the portable core remains independent of WFC.

## Definition and ownership

`TStyleGrid.Create(Style, Options)` copies the style's context, onset and optional
intensity/pitch models, plus their saved generation preferences. Start with
`DefaultStyleGridOptions`: 32 cells, fragment extent, independent pitch history
and the existing layer search defaults. Choose `CellCount` in 1..1024, an explicit
whole/prefix/fragment extent, seed and nonnegative search budgets. All providers
use the same cell count and the saved PPQ/step; no implicit normalization occurs.
The grid's total tick extent must fit a native Integer.

`CouplePitch=True` requires observed pitch/onset relationships in the style.
The exact pass order is:

| Provider | Name | Availability |
| --- | --- | --- |
| `gpKey` | `key` | Always |
| `gpTempo` | `tempo` | Always |
| `gpPitchRhythm` | `pitch-rhythm` | Coupled mode only |
| `gpOnsets` | `onsets` | Always |
| `gpIntensity` | `intensity` | Saved dynamics evidence |
| `gpPitch` | `pitch` | Saved pitch evidence |

`ProviderIndex` returns -1 for an absent provider. Use `ProviderCount` and
`ProviderName(Index)` to inspect the actual pass list. An intensity pass depends
on onsets; coupled mode additionally projects its observed joint provider to
onsets, pitch and available intensity. Key/tempo retain their independent paths.
These are the saved providers, not inferred bass/chord/melody roles.

The source style may be freed after construction. `CreateSession` returns a
caller-owned `TLearnedLayerSession` with independent model/relation/preference
copies; it can outlive the definition. Keep the definition while constructing
typed masks or capturing its original models. `ModelText(Index)`,
`CopyPreferences(Index)`, `StyleIdentity`, `TicksPerQuarter` and `StepTicks` expose
detached settings and provenance. No new saved format or historical reader is added.

Duration-performance preferences reject in this consumer. Joint pitch/rhythm
preferences require coupled mode; settings are not silently dropped. The
[duration API](PERFORMANCE.md) is the consumer for measured duration models.

## Typed edits and capture

`ValueConstraints(Provider, Locks)` accepts `MakeGridValueLock(Cell, Value)`:

| Provider | Value |
| --- | --- |
| `gpTempo` | Microseconds per quarter under the context token contract |
| `gpOnsets` | 0 or 1 |
| `gpIntensity` | 0..4 |
| `gpPitch` | Admitted MIDI note 0..127 |

`KeyConstraints` accepts `MakeGridKeyLock(Cell, KeyContext)`, including canonical
unknown key. Each dimension permits one lock per zero-based cell; invalid values,
duplicate/out-of-scope cells and absent providers reject. These helpers build
complete replacement masks for `Session.SetConstraints(Name, Mask)`; an empty
mask clears the supported pass. A valid value can still be absent or infeasible
in that learned model and scope, which the session/analysis must reject.

For a coupled edit, also call `CoupledConstraints(OnsetLocks, IntensityLocks,
PitchLocks)` and set its result on `pitch-rhythm`. This intersects the requested
dimensions with observed joint tokens and rejects empty alternatives. Regenerate
from `pitch-rhythm` so actual WFC includes its consumers. Independent key/tempo
states remain accepted unless those providers have their own pending edits.
Clearing an edit requires clearing both its consumer mask and the corresponding
joint mask. Hard locks, soft preferences and training weights remain distinct.

`Capture(Sequences)` returns a `TStyleGridResult` containing native `Context`,
Boolean `Onsets`, integer `Intensities` and `Pitches`. Each capture allocates fresh
arrays independent of the definition/session. Ordinary assignment of the returned
record follows Pascal dynamic-array sharing rules; copy arrays before modifying
an additional alias. Absent optional providers have empty arrays.

Capture checks every configured model path/extent, token-to-state agreement,
onset/intensity consistency and all observed joint relationships. Individually
valid marginal paths are insufficient if their combination violates the joint
provider. Unknown/changing keys and changing tempos remain explicit. An onset
choice is not a declaration of measured silence elsewhere. Authored accompaniment
restrictions, such as a constant known key, belong to the consuming tool.

Capture validates against the definition's original models, not a session's later
replacement models or pending masks/preferences. It does not mutate or roll back
the session. Capture into a candidate result before publishing a new musical plan.
Failed capture leaves a previously assigned result intact.

## Provider descriptions

`TStyleGrid.CopyProvider(Index)` and
`TStylePerformance.CopyProvider(Provider)` return the shared
[`TStyleProviderDescription`](../adapters/wfc/pythian.wfc.providers.pas).
A host can discover supported musical choices without decoding token strings.
Each call copies choices, dependencies and saved preferences into detached arrays;
the result can outlive the definition. Ordinary record assignment still shares
dynamic arrays. Failure preserves a previously assigned description.

The description binds the session name, current vocabulary kind, PPQ, requested
cell count/extent and timing interpretation. Origins are tick zero:

| Timing | Meaning |
| --- | --- |
| `sptUniform` | Positive `StepTicks`; cells cover successive half-open tick intervals. |
| `sptHeld` | One selected context value explicitly holds across the captured plan. `StepTicks=0`; one WFC cell does not mean one timed interval. |
| `sptGeneratedSpans` | Performance tokens jointly select pitch kind/note/duration. `StepTicks=0`; cumulative boundaries become known after solving. |

Dependencies name the actual immediate WFC projection providers and their mapping.
For example, coupled intensity depends on both `onsets` and `pitch-rhythm`, while
key/tempo are independent. The three duration passes have no WFC projection edges;
their shared coverage is checked at capture. Downstream rendering consumes context,
but that does not create an undeclared solver dependency.

Each choice includes its original token and a `Dimensions` set. Read only fields
listed in that set: key, microseconds per quarter, onset, intensity band, absolute
MIDI pitch/kind and duration in PPQ ticks. Unknown key retains root -1. Duration
silence and unknown retain distinct `PitchKind` values and note -1. A missing onset
does not claim silence. Joint level 5 means onset without a measured intensity;
its choice omits the intensity dimension. Level 0 retains the existing no-onset
band zero. Optional providers remain absent; no bass/melody role is inferred.

Choose a complete joint token to preserve its observed combination, then use it
with `MakeWfcSequenceTokenConstraint` / `Session.SetConstraints` or
`MakeLayerTokenPreference` / `Session.SetPreferences`. Regenerate from that named
provider; WFC includes its dependent passes. A marginal edit still needs the
coupled-mask treatment above. Public choices are vocabulary, **not a promise of
position-specific or joint feasibility**. Existing model paths, constraints,
projections and budgets decide feasibility. Preferences are distinct from locks.

Descriptions reflect the definition, not pending session edits or a replacement
model. Their enum identifies supported decoding, not arbitrary model compatibility.
Inspect again after rebuilding a definition. Existing PYS reload/blend semantics
remain authoritative; this API adds no archive, historical reader, registry or
stream-edit policy. General voice/harmony descriptors remain in
[WFC-LAYERS](MILESTONES.md#wfc-layers).

The checkout's existing style tool provides read-only inspection:

```text
pythian.style providers INPUT.pys grid 64
pythian.style providers INPUT.pys coupled 64
pythian.style providers INPUT.pys performance 32 0 0
pythian.style providers INPUT.pys performance 32 32 32
```

The last two counts select key and tempo scopes; zero explicitly holds a
single-valued model. Grid inspection uses fragment extent, performance uses prefix.
Inspection reports choices, timing, dependencies and saved multipliers; it does
not solve or publish a style/audio artifact.

### Description checks — 2026-09-20

Checked stable Win32 and Win64 consumers discover an alternate joint pitch/onset
choice, apply both a preference and a hard lock, capture the expected pitch/onset/
intensity, and preserve every independent key/tempo latent state. Existing grid
replay, optional-provider, changing/unknown-context and rejection controls pass.
Held performance checks verify joint pitch/duration choices and distinguish held
context from a single finite context cell. Canonical unknown/silence, missing
intensity and mixed-vocabulary rejection controls preserve previous caller values.
The CLI's coupled-grid report is byte-identical across the two targets. There are
no reported leaks or owned-source warnings; existing WFC/RTL warnings remain.
The preferred second-blend listening path also retains exact prior WAV, MIDI,
preview and report bytes (64 cells, 705600 stereo frames, 120 notes), with actual
WFC PCM verification. Fresh [source packages](PACKAGING.md#current-api-delivery)
pass extraction checks and a separate consumer using only packaged units.
Evidence is under ignored `build/provider-descriptions/`. This does not establish
new inference accuracy, arbitrary role registration or listening acceptance.

## Feasibility and limits

`AnalyzeProvider(Index, Constraints, Analysis)` checks structural feasibility
through actual WFC token-domain analysis. It uses the configured scope and supplied
complete mask, without solving or inspecting session edits. It retains the layer
limits of 262144 state-cells and 16777216 cell-state-state work. Diagnostic budget
rejection is not a claim that generation is impossible. Joint rule/mask preparation
also uses the layer projection-work bound; session construction retains its own
aggregate graph and projection checks.

A feasible isolated provider does not prove joint feasibility, musical admission
or listening quality. Solve, capture and musical evaluation are separate steps.
Variable durations, unequal pass grids and arbitrary semantic registration remain
separate contracts; use the existing duration/generic layer APIs where appropriate.

## Integration checkpoint — 2026-09-20

The voice demo now delegates saved grid model assembly, preferences, projections,
typed masks, scope analysis and capture to this API. Its CLI, 64-cell/480-PPQ
arrangement, reporting, known-key requirement and authored accompaniment stay in
the tool. The context-only and measured-duration paths retain their own contracts.

The independent `pythian.tests.wave.style grid-api SOURCE.pys` caller exercises
released source ownership, separate-session replay, detached settings/results,
typed key/tempo/pitch edits, preserved independent states and rejected invalid
paths, tokens and joint combinations. Its source is the maintained two-note
MIDI-60/62 WAV fixture, optionally carrying saved grid preferences. Additional
native controls cover eight-cell grids, absent pitch/dynamics providers and
unknown/changing context with matching source-clock evidence.

Checked stable Win32/Win64 and development Win32 pass with zero reported leaks.
The maintained build invokes the API check after creating the pitch source style.
Final stable Win64 preferred and pitch-locked renders retain exact prior WAV/JSON
hashes; both have 64 cells, 705600 stereo frames and 120 notes. The independent
pitch path also passes actual WFC PCM/MIDI and saved-style output checks (710892
stereo frames, 130 notes). These are scoped consumer checks, not listening verdicts
or newly compared audio across compiler targets. The unsupported joint model still
exits 1 without publishing a WAV on all three targets, with a named provider/scope
diagnostic and zero reported leaks.

Focused evidence is under ignored `build/grid-api/`; this does not refresh source
packages or claim independent ecosystem adoption. Recorded musical admission and
general semantic role controls remain under [WFC-LAYERS](MILESTONES.md#wfc-layers).
