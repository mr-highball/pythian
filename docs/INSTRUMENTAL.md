# Instrumental musical WFC runtime

[Home](../README.md) · [Goal](GOAL.md) · [Tasks](TODO/README.md) ·
[Named voices](INDEPENDENT-VOICES.md) · [Instruments](INSTRUMENTS.md)

## What this provides

The shared [instrumental adapter](../adapters/wfc/pythian.wfc.instrumental.pas)
connects actual named musical WFC passes to the primary note projector, instrument
planner, buses and scheduler. A successful plan has distinct parts, native notes
and source-free or explicitly bound instrument tones. Optional
[unpitched percussion](PERCUSSION.md) uses a separate rhythm-dependent graph group
and the same native performance. It never selects recorded
training-mix grains or silently substitutes a different renderer.

The [simple Studio](OPERATOR-STUDIO.md) uses **Library → Selection → Generate**.
Whole tracks or clips and per-track learning influence feed Experimental musical
providers automatically. The native job uses these actual providers with six
instrumental parts; no authored starter fills in selected-music learning.
The simple interface plays the mix and an original comparison excerpt. Native
artifacts retain all six stems, actual graph dimensions, provider model files,
source clocks, proposal origins and coverage. The host keeps working when the
page closes. This finite path accepts 2–30 second previews plus a release tail.
Deeper graph editing, sound design and long instrumental
streams retain their linked [tasks](TODO/README.md).

## Public API and ownership

The retained native musical-material consumer uses the shared
[observed sound controls](INSTRUMENTS.md#experimental-observed-sound-controls)
to apply an explicit low-pass cutoff and envelope sustain to one pitched part.
The job retains the saved source recipe and actual `applied_sound` values; other
parts retain their instrument recipes. Saving choices/feedback never queues work.
Each explicit Generate constructs its musical models again; identical model
hashes after a sound-only edit are not a cache/reuse claim.

[Musical controls](MUSICAL-CONTROLS.md) compile pitch bounds and soft preferences
through the existing named graph. `TInstrumentalOptions.Expression` optionally
maps generated pitched notes through the primary detached expression implementation
before instrument planning. `CopyMusic` retains actual symbolic decisions;
`CopyNotes` describes the performed gates/velocities. Empty expression preserves the
original path. The runtime also supports the retained-score sound edits below;
Studio's ordinary Generate still starts a new plan. This is finite generation,
not passage/role graph regeneration.

Call TryCreateInstrumentalPlan with an actual TWfcMusicVoicesGraphConfig, ordered
role/instrument/bus bindings, session options, explicit PPQ tempo changes and
material origin. Masks and preferences use harmony, rhythm, then declared role
order. They retain the named session's hard/soft distinction.

The function constructs a private named session, projects WFC attack/hold/rest
frames through the shared music adapter without whole-bar padding, and plans
each part using TInstrument and the primary PlanNoteVoiceTones selector. A false solve returns its original
negotiation/proof report and failing pass. Bad inputs, resource rejection or
observer cancellation raise before replacing the previous plan. Success replaces
and frees the previous plan only after all planning/ready callbacks.

The plan owns cloned models/session state, detached pitched notes and accepted
percussion recipes. CopyGraph returns
actual pass dimensions, proof flags, model token/state counts and dependency
indices. CopyProvider, CopyModel, CopyMusic, CopyConstraints, CopyPreferences and
CopyNotes expose detached accepted pitched data. CopyPercussionHits/Part describe
unpitched events/recipes; CopyPassTokens/States and CopyModel cover every group.
Copies of part tones still borrow native
factory/automation/envelope resources; preserve those resources through player
creation, and preserve source factories for their own source lifetime.
RoleAt returns metadata with Instrument=nil after planning, not a dangling pointer.

## Retain the score while changing sound

`TInstrumentalPlan.Reperform` accepts one or more `TInstrumentalSoundEdit` records.
Each names an existing pitched role by index, an explicit instrument/identity and
absolute velocity/gate expression. It stages a complete candidate performance,
then commits after its readiness callback. Rejection or observer cancellation
preserves the plan, including sound identities and playable parts. Reentry rejects.

```pascal
LEdit := Default(TInstrumentalSoundEdit);
LEdit.Role := 2; // caller's Lead role
LEdit.Instrument := LNewLead;
LEdit.InstrumentId := 'my-lead-recipe';
LEdit.Expression := DefaultMusicalExpression;
LPlan.Reperform([LEdit], LProgress);
```

No model construction, learning or solving occurs here. Accepted WFC models,
tokens/states, pitched attacks/pitches, drum choices and unselected audio parts
stay exact. `CopyScore` returns the detached original pitched gates before
expression; `CopyNotes` returns the performed gates. Expression is always relative
to that original score, so repeating50% velocity does not make25%, and restoring
neutral expression recovers the original. Shorter gates/release tails can change
`FrameCount`; compare parts on a shared padded timeline when necessary.

Instruments are borrowed during replanning; their factories, curves and envelopes
keep the ordinary borrowed lifetime through new player construction. Existing
players keep their scheduled voices. The primary `PlanNoteVoiceTones` selects a
voice without allocating a duplicate score or renumbering source gates. Its
note-local seeds match planning a separately selected voice and do not depend on
unrelated parts. Both initial generation and reperformance use this same planner.

This public in-memory operation does not yet restore durable Studio jobs or
regenerate selected graph roles/passages. Those integration requirements keep
[graph controls](TODO/NS-4_graph-controls_01.md) open. Saving feedback does not call it.

CreatePlayer takes a healthy matching-rate bus graph and returns a new owned
TScheduledSynth. Every note is admitted before return; rejected construction
disposes its private scheduler without processing/resetting the bus graph.
The player exclusively borrows that graph. Role indices are scheduler groups;
explicit role bus indices let callers mute/solo and route through existing bus
controls. Use a fresh graph for replay or simultaneous playback.

The finite plan currently admits at most 4096 scheduled tones. Its PCM storage
does not grow with output duration: consume Process frames or bounded
RenderScheduledFrames blocks. This is not yet indefinite musical lookahead.
FrameCount includes the exact musical extent, the longest remaining native
note release, and the caller's explicit effect-tail frames. Effect decay cannot
be inferred automatically. Unexpected processing failure follows the existing
scheduler's Reset/new-epoch policy.

## Maintained source-free caller

The [public example](../examples/pythian.example.instrumental.lpr) writes stereo
PCM16 WAV through the primary streaming writer, plus a JSON graph/model/token
sidecar. It accepts output path, cells, seed, BPM and tonic pitch class.

The reusable [authored starter](../adapters/wfc/pythian.wfc.instrumental.starter.pas)
provides two symbolic training phrases, saw bass, triangle harmony and square
lead with native ADSR/filter/pan. Its harmony/rhythm guide is explicitly authored;
WFC selects compatible pitched parts through five provider passes. Exact harmony
adds seven coverage proof passes. Default execution is twelve 64 x 1 x 1 passes:
harmony, joint rhythm, three voices and seven witnesses. These are passes against
one time axis, not twelve musical dimensions.

An optional TPitchPattern supplies an operator-selected motif for bass, harmony
or lead. The primary pythian.music.pattern unit can quantize selected-channel pitch
spans onto explicit eighth-note cells; callers can also author or correct cells.
Unknown cells split examples and remain distinct from measured silence. The
starter explicitly repeats each known run four times to teach repeatable motifs,
with authored accompaniment. Those repetitions and accompaniment are authored
material, not observations of a recording or continuity across missing material.
AMinor selects the starter's minor accompaniment; it does not infer a key.

For this motif path, pass the starter's borrowed ContextModel as the final
TryCreateInstrumentalPlan argument. The shared musical-context provider learns
full synchronized symbolic ensemble frames with one explicit driven role. Its
canonical ctx2 tokens reuse the primary ensemble codec, absolute MIDI pitches and
declared role order/identity. Context preserves distinct pitch histories instead
of merging them into lossy harmony/rhythm marginals. One actual WFC context pass
decides harmony, rhythm and the selected role together, honoring their hard masks
and soft preferences. Accepted choices constrain those three named graph inputs;
the other pitched roles remain unpinned and independently selected. A contradictory
lock fails rather than being relaxed. ContextSolve reports its negotiation;
context_validate_witness validates the synchronized history with cancellation.

CopyGraph exposes this additional graph group and its pinned-input lineage:
context group 0, pitched group 1 and optional percussion group 2. The sixteen-cell
C/unknown/silence/D fixture with drums has seventeen actual passes, each 16 x 1 x 1.
The corrected richer melody has twenty passes because its harmonic vocabulary
requires more coverage proofs. These are actual vocabulary-dependent counts.
This is conditional generation, without backtracking across groups. A context
choice can still leave the following graph unsatisfiable; failures remain visible.
The retained native musical-material consumer supports analyzed/manual motifs,
correction, bypass and explicit part assignment. These deeper controls are not
required steps in the simple Studio interface. Saving does not generate.
Recording-linked jobs retain a bounded Original excerpt with exact source
coordinates; source audio is never the performed instrument.

The caller adds the primary filtered echo on the harmony bus and a three-second
effect tail. Changing tonic changes actual training/model pitches; changing BPM
changes the exact performance clock. A seed or supported constraint may produce
different valid voice paths, but a different seed is not a guarantee of variation.

Without a motif, adding --drums as the sixth argument creates kick, snare and hat from authored
velocity-event models and explicit rhythm projections. The result has a second
four-pass graph group, and sixteen actual passes total. It retains pitched
harmonic proof and adds the primary master limiter. Graph groups and pinned-input
lineage are explicit; this does not claim one jointly backtracking graph.
The sixth and seventh arguments may also include --motif=60,?,r,62: MIDI note
numbers, ? for unknown and r for rest. Each entered note is an explicit attack.
For example, append '--drums' '--motif=60,?,r,62' to a sixteen-cell invocation.
The sidecar records the actual context model, seed, tokens and conditional groups.

Compile from the repository root with the existing FPC toolchain, choosing
explicit E-drive unit/executable output folders on this workstation:

~~~powershell
$build = 'E:/CodexWork/pythian/build/instrumental-example'
New-Item -ItemType Directory -Force "$build/units" | Out-Null
fpc -Fusrc -Fuadapters/wfc -Fuvendor/wfc/src "-FU$build/units" "-FE$build" examples/pythian.example.instrumental.lpr
& "$build/pythian.example.instrumental.exe" "$build/music.wav" 64 731 120 0
~~~

No source recording, private catalog, playback device or service is needed.
Opening the WAV is explicit; running the example does not start audio.
Unsupported/unlucky graph requests return an actionable failure rather than
silently relaxing constraints. The maintained fixture checks real graph/note
controls, deterministic replay, exact changing-tempo timing, release tails,
borrowed callback cancellation and preservation of a previously accepted plan.

## Experimental coarse musical providers

The portable [musical proposal](../src/pythian.music.proposal.pas) consumes the
primary observation bundle. Chroma and low/mid/high spectral changes share one
FFT analysis. Complete eighth-note cells propose arranged bass, spectral harmony,
periodic lead where measured, a marked spectral lead otherwise, and drum actions.
These are arrangements from a mix, not identified stems or recovered instruments.
Silence remains known rest; diffuse unsupported cells remain unknown. The caller
supplies the explicit clock (40–240 BPM); this proposal does not infer tempo.
Periodic pitch still covers only the first eight seconds of each bounded
observation, while spectral measurements cover the whole window.

[TMusicalCorpus](../adapters/wfc/pythian.wfc.musical.corpus.pas) binds sources,
included ranges and measured proposal runs to original frame clocks. It learns
harmony, joint rhythm, one provider per pitched role, paired musical context and
three percussion providers. Source training influence multiplies sample/count
contributions; generation preferences remain separate. Unknown cells, omitted
time and recording boundaries split open samples. Starting holds are explicitly
rearticulated at the admitted boundary. Classification strings retain caller
context. An explicit classification selection can choose teaching material as
described below; no genre-to-instrument rule is implied.
Only known pitched/context cells enter this coupled corpus, including their
drum proposals. Drum-only or otherwise unsupported pitched material cannot yet
bootstrap this complete arrangement; unknown time earns no model-used coverage.

CopyCoverage separates included, excluded, processed, model-used and unmodeled
frames per source, plus actual weighted cells/samples. CopyModelTexts saves the
real immutable providers; Config, ContextModel and CopyPercussion borrow them
for TryCreateInstrumentalPlan. Caller-bound primary instruments perform the
result, without any original-audio factory. The optional sound recipe uses
full-window brightness/dynamics proposals, weighted by admitted seconds and
influence. It is not source instrument recovery.

The current bounded API admits 32 sources, 64 selections and 1024 runs; each run
uses the existing up-to-30-second/two-million-frame observation bound. Unknowns
may produce several samples per run. Weighted samples must fit the companion's
4096-sample limit and the caller's observation budget (default 65536, at most 1048576).
Companion public-token/state/history limits still apply; excess work rejects
instead of silently trimming or joining recordings.

Native `LearnStudioPlaylist` traverses the actual included whole/range recordings
in bounded windows and reuses source/clock/policy-bound primary proposal caches.
The primary `TWaveFrameReader.ReadClip` fills windows through bounded reads; whole
WAV decoding uses this same implementation. The musical proposal codec is shared
by native and pas2js, checks its complete payload hash and publishes only after
validation/cancellation checks. Cache hits skip analysis without inventing coverage.
The native tempo is an Experimental first-eight-second pulse candidate per
window, with an explicit 120 BPM fallback; it is not a whole-track beat truth.

The finite provider budget is 1,024 known cells in eight-cell musical blocks,
spread uniformly across included time and fairly among recordings. A separate
admission mask retains original known/unknown observations. It never joins gaps
or claims that all analyzed audio entered the model. Receipts retain measured,
cached, proposed, unknown/partial, budget-omitted and actual model-used time.
Sources below one supported proposal window can remain unanalyzed and are
reported as such. Whole sources remain on disk; windows, grids and model inputs
are bounded. Native source limits remain 16 GiB per recording / 32 GiB total.
The automatic Studio consumer uses the existing durable instrumental job with
a48hour wall-clock limit for playlist generation and explicit progress/cancellation.
Other training jobs retain their two-hour limit; requested music is at most24hours.
Rebuild identities and source contributions are now explicit, as described below.
Coarse [style-vocabulary learning](TODO/DONE/NS-3_style-vocabulary_01.md) is
accepted through the real native/Studio consumer. This is not universal
transcription or complete musical coverage of all traversed time.

### Explicit classification selection

Primary [pythian.music.selection](../src/pythian.music.selection.pas) is portable
and independent of WFC/browser code. `ClassifyMusicSelection` uses the caller's
exact scalar-text label to choose whole tracks or clips. A matching whole source
suppresses its clips; otherwise matching disjoint clips are selected. No match,
invalid original half-open frame ranges or overlapping matching clips reject
without publishing partial flags. This selects teaching material; it does not
map a word such as lofi to a pitch, instrument or inferred musical truth.

`MusicalClassificationPolicy` records `exact-label-whole-before-clips-v1`.
The shared selector admits256 items with16 labels per item and256 canonical
UTF-8 bytes per label; Unicode normalization is not performed and case matters.
These selector bounds do not raise the corpus's32source/64selection limits.
The native playlist contract retains optional `learning_label` and whole-track
`classifications`; selected range labels also reach actual corpus records.
Canonicalization recomputes inclusion through the same primary rule. Legacy
playlists without these optional fields retain their canonical shapes.

The native worker excludes nonselected tracks before payload preparation/hash/
analysis. `classification_selection` states the actual label/policy and source
selection effect; `excluded_sources` retains saved but unused names/clocks.
Each used source's `providers_taught` lists its actual provider keys. Studio's
optional Choose by label previews exact names/ranges, then autosaves the rule.
Manual inclusion edits clear it; browsing and previewing never silently train.
Same-seed actual native model and instrumental output changes, portable/native
Unicode/overlap cases and desktop/phone save/reopen/Generate pass. No automatic
genre/instrument identification or subjective quality acceptance follows.

For playlist results, `playlist_learning.sources` and the immutable request bind
the complete training selection and influence. `original_reference` and the
top-level `sources` describe comparison material. `used_sources` remains empty
because the generated mix performs instruments without original PCM. Listening
publications name the actual playlist-learning task/policy, not an authored starter.

### Stable musical meaning across rebuilds

`TMusicalCorpus.CopyVocabularies` returns each real provider's key, codec,
relevant ordered-role schema digest, exact model-text digest and public tokens.
Each token has a stable identity bound to its codec/key/schema/value. Its array
position remains local to that exact model. Adding or reordering recordings may
change those positions; it cannot silently change a saved meaning. Joint rhythm
and context also bind the ordered role schema, so renaming/reordering roles does
not preserve an incorrect positional interpretation. Named voices bind their
actual role names, including canonical Unicode.

Use `ResolveToken(providerKey, tokenIdentity)` to find the current local index.
It returns-1 when the meaning or provider is absent. Never reuse an old numeric
position or substitute a different meaning. Old saved model/replay artifacts
remain the authority for their own indices.

`CopyContributions` identifies each actual admitted open sample by original
source hash/rate/range, proposal policy/clock, provider keys and symbolic token
sequences. Unknowns, omitted time and run boundaries remain separate leaves.
Training multiplicity is a separate field: reweighting changes counts, without
inventing a second source ancestor. A rebuild consumes the complete desired
source/selection/run set once; it does not append the previous model's counts.
Existing source-bound analysis caches already support adding recordings without
remeasuring unchanged windows. `RevisionIdentity` binds the resulting ordered
provider models and admitted symbolic contributions/counts. Sound recipes,
classifications, excluded time and the complete playlist retain their separate
receipts; this is not a general instrumental-style archive.

Native learning receipts carry a compact `vocabulary` summary. The worker saves
the full `musical-vocabulary.json` beside its replay models, including token values,
stable identities, exact local indices and source contribution clocks/weights.
This generated JSON artifact shares the existing1MiB local-record bound; larger
metadata rejects explicitly rather than truncating or silently changing meaning.
No extra UI setup or automatic retraining is introduced.

Big Boss's native and actual pas2js rebuild checks cover source addition/reorder,
real index changes, reweighting, removal, Unicode schema edits, unknown/omitted
boundaries, detached records and cancellation. Saved models still drive actual
six-part synthesis; changing8:1 to1:8 source influence changes the rendered music.
The native Studio worker and browser Generate also save the actual bindings.
Source-evidence/revision hashes can differ across targets when their synthesized
fixture WAV bytes differ; stable meanings and exact provider-model hashes match.

The maintained musical-corpus fixture measures two actual controlled recordings,
swaps influence 8:1/1:8, reloads saved providers into six-part synthesis and checks
deterministic same-target replay. Native64 and actual pas2js pass; all nine
provider text hashes and both musical-decision hashes match across targets.
PCM hashes differ between targets;
cross-target byte-identical audio is not claimed. The generated graph has twenty
passes for this vocabulary, not a fixed universal grid size.
