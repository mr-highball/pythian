# Reusable saved-style performance API

[Home](../README.md) · [Layered style](LAYERED-STYLE.md) ·
[Named WFC sessions](LAYERS.md) · [Independent voices](INDEPENDENT-VOICES.md)

`pythian.wfc.performance` turns a current saved duration style into independently
controlled key, tempo and performance passes, then captures their result on a
native musical clock. It composes the existing actual WFC session and Pythian
timing contracts. It adds no solver, archive format, JSON, file I/O or synthesis
policy. The standalone core remains independent of WFC.

The corresponding [saved-grid API](GRID-STYLE.md) handles uniform key/tempo,
onset, intensity and pitch passes, including observed pitch/rhythm coupling.

## Definitions, sessions and ownership

`TStylePerformance.Create(Style, Options)` copies the saved key, tempo and joint
pitch/duration models and their saved generation preferences. Grid-model preferences
reject because this consumer cannot apply them; see the
[saved preference contract](WAVE-STYLE.md#saved-generation-preferences).
The input style may then be released. Start with
`DefaultStylePerformanceOptions`, which requests 32 spans and held context.
`SpanCount` accepts 1..1024. `KeyCells` and `TempoCells` independently accept
0..1024: zero explicitly holds a single-valued model; positive values request a
finite prefix on the saved context grid. Changing models cannot be held silently.
The duration and context models must share a PPQ timebase. Search budgets retain
the existing bounded layer-session contract.

`CreateSession` returns a caller-owned `TLearnedLayerSession` with the exact names
`key`, `tempo` and `performance`. The session owns its models and may outlive the
definition. The definition is needed to construct typed masks and capture plans.
For example, with appropriately declared variables and an admitted input style:

```pascal
Options := DefaultStylePerformanceOptions;
Options.SpanCount := 3;
Definition := TStylePerformance.Create(Style, Options);
try
  Session := Definition.CreateSession;
  try
    if not Session.TryGenerate(Providers, Report) then
    begin
      raise EAudio.Create('Performance solve failed');
    end;
    Plan := Definition.Capture(Providers);
    try
      Spans := Plan.CopySpans;
      Clock := Plan.CopyClock;
      try
        { Realize spans using host-selected native voices and this clock. }
      finally
        Clock.Free;
      end;
    finally
      Plan.Free;
    end;
  finally
    Session.Free;
  end;
finally
  Definition.Free;
end;
```

`Capture` checks actual prefix state paths, state/token agreement, configured
counts, cumulative duration bounds and complete context coverage. It neither
repeats finite context nor extrapolates missing cells. Unknown keys and
unknown/silent spans remain explicit. The library does not require 480 PPQ.

The returned `TStylePerformancePlan` owns its spans and musical context; it may
outlive both the definition and session. `CopySpans`, `CopyClock` and `CopyKeys`
return detached data, and `KeyAtTick` queries the captured timeline. The public
plan constructor also accepts native authored spans, a clock and key changes;
it requires a contiguous canonical partition starting at zero with an exact
shared endpoint. Such a directly authored plan does not claim learned provenance.

Solving and capture are separate acceptance steps. A successful symbolic solve
can still lack enough finite context for its generated duration. Failed capture
does not roll back that solved session, and does not invalidate a previous plan.
Capture into a candidate before replacing the last accepted audible plan.

## Granular edits

- `PerformanceConstraints(DurationLocks, PitchLocks)` accepts multiple typed
  zero-based cell locks: positive PPQ durations and MIDI pitches 0..127.
- `TempoConstraints` accepts typed cell/value locks on the tempo provider;
  values use the existing microseconds-per-quarter token contract.
- `KeyConstraints` accepts typed cell/key locks on the key provider.

Use `MakePerformanceValueLock` and `MakePerformanceKeyLock` to build entries.
Each dimension permits at most one lock per cell. Duration and pitch on the same
cell intersect into one joint mask, including for a one-span request. Constraints
retain only observed joint alternatives; two individually observed values do
not imply their combination was observed. Duplicate cells, invalid scopes and
absent alternatives reject before a candidate mask is returned. Search work
retains the existing projection bound.

Pass a returned mask to `Session.SetConstraints('performance', Masks)` (or the
other provider name), then call `TryRegenerate` with that name. Masks replace the
whole pass mask; an empty mask clears it. An observed alternative can still be
infeasible at a requested prefix position. Actual WFC solve failure preserves
accepted generation history. Pending provider edits participate in the existing
session's selective regeneration rules.

`StyleIdentity`, `TicksPerQuarter`, `StepTicks` and `ModelText` expose provenance,
clock geometry and existing canonical WFC text. They do not define another saved
performance format.

## Integration and evidence

`AnalyzeProvider(Provider, Constraints, Analysis)` exposes the companion's exact
structural token-domain analysis for this definition's provider scope. Held
key/tempo providers use one prefix cell; performance uses its requested span
count. The method reads owned model copies without creating or modifying a
session. Constraints are the complete supplied mask, not a session's pending
edits. It retains the 262144 state-cell bound and requires
`cells * states * states <= 16777216` for analysis. Exceeding this diagnostic work
bound raises; it is not a declaration that generation is infeasible.

A false result identifies a structural contradiction through the actual
`TWfcSequenceDomainAnalysis.Issue`. It distinguishes missing paths from solver
backtrack exhaustion. A true result does not establish enough finite musical
coverage, phrase accuracy or listening acceptance; solve and capture checks still
apply. The voice operator uses this analysis after a contradictory solve to name
the provider and failed path position, and separately reports solver/pass limits.

The [duration-scope checkpoint](WAV-STUDIES.md#duration-scope-checkpoint) diagnoses
the old 32-span rejection: the isolated-note performance has no prefix beyond
three spans, while its key/tempo models remain feasible. A multi-note recording
and a saved second blend support 32 spans through actual passes. Unknown key is
retained; the authored accompaniment tool separately requires a known key.
Checked Windows fixtures cover provider scope, typed infeasible masks, actual
generation and independent PCM verification. These additions postdate the older
integration evidence below.

The duration path in `pythian.voices.demo` now uses this public API. Its authored
five-pass accompaniment, known-key requirement, 480-PPQ policy, command-line
parsing and output reports remain tool responsibilities. Extracting joint masks
also fixes simultaneous pitch/duration locks for a one-span request.

The existing `pythian.tests.wave.style performance-api` fixture exercises released
input ownership, detached plans, typed joint/context edits, actual state-path
validation, insufficient coverage, solve failure and recovery. Checked stable
and development Win32 plus stable Win64 pass. Held and changing-context outputs
retain the preceding WAV/MIDI/preview/report bytes; all three scenarios, including
the one-span joint lock, match across these targets (24 comparisons). The complete
maintained recorded workflow passes on stable Win32. Evidence is under
`build/performance-api-{stable,trunk,win64}/`; the final stable checks are
`final-api-run.log`, `final-replay.log` and `recorded-workflow.log`.

This makes the existing saved-style coordination reusable by a library host.
The shared [provider descriptions](GRID-STYLE.md#provider-descriptions) expose
joint choices and distinguish held/timed context from generated-span timing.
General semantic layer registration, arbitrary projections across unequal time
resolutions, broader recorded accuracy and learned polyphonic voice/timbre roles
remain open. These are separate outcome milestones, not format versions.
