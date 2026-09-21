# Native compiler and source delivery

[Home](../README.md) · [Profile](../PROJECT.md) · [Provenance](PROVENANCE.md) ·
[Work and remaining gates](WORK.md)

Pythian's source packages provide the core independently, or the core plus WFC
adapters and the pinned companion source. These are local development snapshots,
with self-contained examples and full notices. They exclude Phanes and external
music/model assets. Fresh ZIP extraction verifies delivered bytes before compiling
and running consumers solely against package sources.

The [current API delivery](#current-api-delivery) includes the later spectral
partition and pitch boundary queries, phase-aware harmonic fitting, corrected
automation workload accounting, transactional layer edits, explicit/fixed timing
maps, saved generation preferences and the reusable saved-grid API.
Earlier snapshots below retain their dated scope. Linux/remote CI and independent
downstream-use acceptance remain open under
[WAV-05-DELIVERY](MILESTONES.md#wav-05-delivery) and
[DELIVERY-RELEASE](MILESTONES.md#delivery-release).

## Build and package

Use an existing native FPC installation on PATH with its standard RTL/FCL packages:

```powershell
./tools/build.ps1
./tools/package.ps1
./tools/package.ps1 -WithWfc
```

Both scripts accept `-Compiler` followed by the selected compiler executable path.
The package script chooses a fresh directory under `build/packages/`. Optional
`-OutputDirectory build/source-package` gives it a readable location; an existing
directory is rejected to prevent stale contents. No compiler installation or
global configuration change is performed. Compiler and target probes select
the existing toolchain; checked builds use `-B -Sa -Cr -Co -Ci -gl`.

The archive contains selected `.pas`, `.pp` and `.inc` files from the current
flat source directories, full licenses, provenance, examples and package info.
The WFC option requires an unchanged companion checkout and records its exact
revision. It includes `vendor/wfc/src` and its license, preserving upstream
names and notices.

After creating the ZIP, the script extracts it into a fresh directory. A generated
build driver imports every owned unit; separate examples compile and run with
fresh unit output outside the package. All project source search paths refer to
the extracted package. Standard compiler configuration supplies the RTL/FCL.
Consumer sources and logs remain in `consumer-check/`; the delivered source
directory receives no compiled units or generated WAVs.

The [core example](../examples/pythian.example.core.lpr) renders three panned tones,
checks the stereo WAV round trip and prints its exact byte hash. The
[WFC example](../examples/pythian.example.wfc.lpr) analyzes that recording, learns
through the actual WFC contract, generates tokens and reconstructs source grains.
Their packaged [README](../packaging/README.md) includes standalone commands and
ownership guidance.

The [native notes example](../examples/pythian.example.notes.lpr) composes two
authored voices and two tempos, exports MIDI with explicit channel bindings,
strictly imports it, and compares every rendered WAV byte before writing the
MIDI and WAV outputs. The [MIDI stream example](../examples/pythian.example.midi.stream.lpr)
counts and replays an authored event source directly to a host-owned file sink.
Both examples now ship in either package and run during package verification.

The [instrument example](../examples/pythian.example.instrument.lpr) renders
keyboard/velocity zones through the note-sequence API. The WFC package also ships
a [saved-event example](../examples/pythian.example.events.lpr): it learns explicit
intervals from two WAVs, writes an archive, frees the original learning, reloads
from disk and generates through the saved actual model. Package verification
supplies the core/instrument example WAVs, so no workspace tool or external music
asset is needed. These intervals are authored divisions, not inferred beats.

<a id="current-api-delivery"></a>
## Current source packages

The 2026-09-20 provider-description refresh delivers **84 core units and 26 WFC
adapters**. Shared grid/duration descriptors expose typed choices, dependencies,
preferences and timing through the existing named sessions. See the
[provider contract](GRID-STYLE.md#provider-descriptions). Core implementation is
unchanged; both packages include the updated API guidance.

| Artifact | Contents and verification |
| --- | --- |
| `build/provider-descriptions/core/pythian-source.zip` | 94 files; 84 core units; five examples; FPC 3.2.2 Win32; 316251 bytes |
| `build/provider-descriptions/wfc/pythian-source.zip` | 224 files; 84 core units / 26 adapters; seven examples and journal operator closure; FPC 3.2.2 Win64; 1108832 bytes |

All 93/223 content hashes plus manifests pass fresh extraction, every owned unit
compiles and delivered consumers pass, including existing partition/blend/reblend/
fit/replay checks. A separate copy of the maintained style consumer compiles with
only extracted library/tool units and passes descriptor-driven grid edits and held
performance checks. Its current saved fixtures are supplied separately, outside
the archive. The checkout's new `pythian.style providers` CLI is not bundled.

ZIP SHA256:

- Core: `26ee76271aebc9cd6a7479f990e92bab0fd5a29ac3008fdd2c5a44e2a6076952`.
- WFC: `f89ab43325d7ce7ddee241b4b6626c090b03a4869c2c20dd42a8207e1be85b63`.

Logs and external consumers are under `build/provider-descriptions/`. Checked
workspace Win32/Win64 tests and the unchanged Win64 listening-path replay are
scoped in the provider contract. No new owned-source warnings or reported leaks;
existing companion/RTL warnings remain. Linux/remote CI, a new complete clean
source-clone build and independent musical-use acceptance are not established.

## Previous partition-operator packages — 2026-09-20

The 2026-09-20 operator refresh delivers **84 core units and 25 WFC adapters**.
The `journals` command now applies explicit partition/group declarations through
the core selector; see the [operator contract](CORPUS-EVALUATION.md#operator-partition-selection).
No new manifest format or dependency is introduced.

| Artifact | Contents and verification |
| --- | --- |
| `build/journal-partition-operator/core/pythian-source.zip` | 94 files; 84 core units; five examples; FPC 3.2.2 Win32; 316019 bytes |
| `build/journal-partition-operator/wfc/pythian-source.zip` | 223 files; 84 core units / 25 adapters; seven examples and journal operator closure; FPC 3.2.2 Win64; 1105574 bytes |

All 93/222 content hashes plus manifests pass fresh extraction, every owned unit
compiles and delivered consumers pass. The maintained package check now also
compares partitioned learning with explicit training-only input, verifies exact
model/audio bytes and the full report audit through an external Pascal fixture,
and rejects exposed evaluation material and known palette-starter leakage without
publishing outputs. The verifier stays outside the archive and uses only extracted
library units. Existing journal blend/reblend/fit/context/replay checks still pass.

ZIP SHA256:

- Core: `f3246af9a6abadb17ffaeb8177adbf5acac6955c5baeef3f00f50dedf90d8e64`.
- WFC: `122e3eb1b04c12747a65f1bf9e783e9d8abc5bb5cbd5b90880c99e776c6e036c`.

Logs are under `build/journal-partition-operator/`. Checked workspace Win32/Win64
controls additionally cover unequal weights, all three input partitions, existing
output preservation and compatible palette reuse. No new owned-source warnings
appear; existing WFC/RTL warnings remain. This is scoped delivery, not a new
complete source-clone build, Linux/remote CI or independent musical-use verdict.
Branch/index/HEAD and vendor sources remain unchanged.

## Previous library-selector packages — 2026-09-20

The 2026-09-20 partition-selection refresh delivers **84 core units and 25 WFC
adapters**. `SelectJournalPartition` checks caller-declared corpus splits before
existing journal learning; see the [contract](CORPUS-EVALUATION.md#library-partition-selection).
The operator still requires explicit ranges; no manifest format or dependency
is added.

| Artifact | Contents and verification |
| --- | --- |
| `build/journal-partitions/core/pythian-source.zip` | 94 files; 84 core units; five examples; FPC 3.2.2 Win32; 315746 bytes |
| `build/journal-partitions/wfc/pythian-source.zip` | 223 files; 84 core units / 25 adapters; seven examples and journal operator closure; FPC 3.2.2 Win64; 1104057 bytes |

All 93/222 content hashes plus manifests pass fresh extraction. Every owned unit,
delivered example and WFC journal workflow passes its package checks. An external
copy of the maintained journal fixture compiles against only the extracted WFC
package and passes partition isolation, exact training-only palette/model parity,
range/ownership checks and the existing selection/context tests. Checked workspace
fixtures pass on stable Win32 and Win64. Final runs have no owned-source warnings
or reported leaks; existing WFC/RTL warnings remain.

ZIP SHA256:

- Core: `6cc9c2141d96f8120d10eb5e1abf46f14256c37119fcdb9e8e2c4e6c744f4fd7`.
- WFC: `bc77731f783525a7eb1fe13c41009ca8f15111bb0913fe74e9350a2096250c69`.

Logs and extracted consumers are under `build/journal-partitions/`. This focused
refresh does not add a complete source-clone build, Linux/remote CI, independent
downstream-use acceptance or style-quality verdict. Branch/index/HEAD and vendor
sources remain unchanged.

## Previous candidate-path packages — 2026-09-20

The 2026-09-20 candidate-path refresh delivers **84 core units and 25 WFC adapters**.
`SelectBeatTrackPath` exposes retained-candidate optimization with caller-owned
base context and explicit breaks; see the [contract](BEAT-TRACKING.md#candidate-path-api).
No default inference rule, dependency or format version is added.

| Artifact | Contents and verification |
| --- | --- |
| `build/beat-phase-context/core/pythian-source.zip` | 94 files; 84 core units; five examples; FPC 3.2.2 Win32; 314404 bytes |
| `build/beat-phase-context/wfc/pythian-source.zip` | 223 files; 84 core units / 25 adapters; seven examples and journal operator closure; FPC 3.2.2 Win64; 1102713 bytes |

All 93/222 content hashes plus manifests pass fresh extraction. Every owned unit,
delivered example and WFC journal workflow passes its package checks. An external
copy of the maintained path/tracking fixture passes against only the extracted
core on Win32. An external conditional-path consumer and report helper compile
against the WFC package's extracted core/tool units on Win64 and reproduce the
workspace's complete source-bound selection/clock report byte-for-byte. The
diagnostic source report and consumer are verification inputs, not shipped music
or a production automatic metrical policy. Existing WFC/RTL warnings remain;
final checks introduce no owned-source warnings or reported leaks.

ZIP SHA256:

- Core: `ef356cd57167e014805796d20e06ede8284f7ab63195da81fc16f3f07eb656da`.
- WFC: `468f04696a2bc87b42dd485661699a7edfbd9feebf7f399a3fa666fd16008464`.

Logs and extracted consumers are under `build/beat-phase-context/`. This is a
focused refresh, with no new complete source-clone build, Linux/remote CI or
independent downstream-use acceptance. Branch/index/HEAD and vendor sources
remain unchanged.

## Previous alignment packages — 2026-09-20

The 2026-09-20 alignment refresh delivers **84 core units and 25 WFC adapters**.
The independent [alignment API](BEAT-TRACKING.md#alignment-api) and optional
clock mode retain supported, unknown and unavailable decisions. Independent
alignment remains the default; no musical admission rule or format fork is added.

| Artifact | Contents and verification |
| --- | --- |
| `build/beat-alignment-adoption/core/pythian-source.zip` | 94 files; 84 core units; five examples; FPC 3.2.2 Win32; 313250 bytes |
| `build/beat-alignment-adoption/wfc/pythian-source.zip` | 223 files; 84 core units / 25 adapters; seven examples and journal operator closure; FPC 3.2.2 Win64; 1101553 bytes |

All 93/222 content hashes plus manifests pass fresh ZIP extraction. Every owned
unit compiles; packaged examples and WFC journal workflows pass. The maintained
clock/alignment/admission fixture passes as an external core-package consumer
on Win32. External context/report and verification consumers use only extracted
WFC/core dependencies on Win64, then save, reload and generate the optional
alignment context. Report/profile/audio match the workspace exactly: 23 pulse
tones and 555660 stereo frames at 44100 Hz. These verification sources and
authored input are outside the delivered package. Existing WFC/RTL warnings
remain; no new owned-source warnings appear.

ZIP SHA256:

- Core: `a2a25fe385f6b99952d2ec13f46a324b40bdebe3f9ca60f6df0540cf352c417c`.
- WFC: `350f15187a1d2010123e907d14d1c498fd66f8fabe85e1ce2769201caf5cd678`.

Logs and extracted consumers are under `build/beat-alignment-adoption/`.
This refresh uses focused source checks and extracted package consumers; it
does not claim a new complete source-clone build, Linux/remote CI or independent
downstream acceptance. Root branch/index/HEAD and vendor sources remain unchanged.

## Previous clock/context packages — 2026-09-20

The 2026-09-20 clock/context refresh delivers **83 core units and 25 WFC
adapters**, including explicit reconstructed-clock admission into the existing
context/profile providers. The [admission contract](WAVE-CONTEXT-ADMISSION.md#reconstructed-clock-ranges)
retains caller-owned quarter meaning, source offsets and gap/restart/phase
barriers. No automatic musical admission, extra format or music asset is added.

| Artifact | Contents and verification |
| --- | --- |
| `build/clock-context-adoption/core/pythian-source.zip` | 93 files; 83 owned core units; five examples; FPC 3.2.2 Win32; 309891 bytes |
| `build/clock-context-adoption/wfc/pythian-source.zip` | 222 files; 83 core units / 25 adapters; seven examples and journal operator closure; FPC 3.2.2 Win64; 1098195 bytes |

All 92/221 content hashes plus manifests pass fresh ZIP extraction. Every owned
unit compiles; packaged examples and WFC journal workflows pass. An external
copy of the maintained clock/admission fixture passes using only the extracted
core on Win32. An external context operator and report helper compile using
the extracted WFC/core sources on Win64, then save/reload/generate an authored
step-clock context. Its report/profile/audio match the workspace byte-for-byte:
23 pulse tones, 555660 stereo frames at 44100 Hz. These extra consumer sources
and authored fixture inputs are verification assets, not shipped operator/music
assets. Existing WFC/RTL warnings remain; no new owned-source warnings appear.

ZIP SHA256:

- Core: `a8b0b5e0a025108a128e0695c45504b2a0d4f63b031eaadcbf7b6a05762af0fe`.
- WFC: `ddf4f81f1052708ffe2f7f33d1772b7b633892be76412288f12dd41efde18105`.

Logs and extracted consumers are under `build/clock-context-adoption/`.
The full source-clone build below predates clock adoption; this refresh uses
focused source checks and extracted package consumers. Linux/remote CI and
independent-use acceptance remain open. Root branch/index/HEAD and vendor
sources are unchanged.

## Previous clock API packages — 2026-09-20

The 2026-09-20 clock adoption refresh delivers **83 core units and 25 WFC
adapters**, including `pythian.beat.clock` and the selected-track conversion.
The [clock API](BEAT-TRACKING.md#selected-clock-api) reconstructs caller-selected
pulses; the experimental joint selector and private study programs are not shipped.
Source bytes match the workspace at this checkpoint, including the rejected-
phase alignment fix. No music assets, learned runtime model or old style reader
is added to either source package.

| Artifact | Contents and verification |
| --- | --- |
| `build/beat-clock-adoption/final-core/pythian-source.zip` | 93 files; 83 owned core units; five examples; FPC 3.2.2 Win32; 309166 bytes |
| `build/beat-clock-adoption/final-wfc/pythian-source.zip` | 222 files; 83 core units / 25 adapters; seven examples and journal operator closure; FPC 3.2.2 Win64; 1097466 bytes |

All 92/221 content hashes plus the manifests pass fresh ZIP extraction checks.
Every delivered owned unit compiles, all packaged examples run, and the WFC
journal learning/blend/reblend/context/replay checks pass (134144 replay frames).
An additional external copy of the maintained clock fixture compiles using only
each extracted package's core unit path. Analytic phase controls, gaps/restarts,
rejected spans, selection conversion, ownership, malformed inputs and crossing
budgets pass on both package targets, with no compiler warnings or unfreed blocks.

ZIP SHA256:

- Core: `bf400d660847624c6bdb6dc9af5b94515df36eca430f1b91b864722ee1fcff55`.
- WFC: `8dd23827fbbd99339481439240f286879404f662241a318220ee8005c6290709`.

Only `final-core` / `final-wfc` are this turn's final deliveries. Earlier
`package-core` / `package-wfc` under the same evidence folder predate the rejected-
phase alignment fix and are retained as superseded development evidence. No file
format fork is introduced. The full source-clone build below predates clock
adoption; this refresh uses scoped source checks and extracted package consumers.
Linux/remote CI, automatic musical admission and independent-use acceptance remain
open. Root branch/index/HEAD and the WFC pin are unchanged.

## Previous API refresh — 2026-09-20

The preceding API refresh delivered **82 core units and 25 WFC adapters**.
All selected library source bytes matched the workspace and isolated source
snapshot at that checkpoint. No inference study, private WAV, runtime model, compiled binary
or historical style reader is included. The packaged README now describes the
new core queries and owned grid/duration consumers.

| Artifact | Contents and verification |
| --- | --- |
| `build/delivery-api-refresh/core/pythian-source.zip` | 92 files; 82 core units; five examples; checked FPC 3.2.2 i386-win32 |
| `build/delivery-api-refresh/wfc/pythian-source.zip` | 221 files; 82 core units / 25 adapters; seven examples; journal operator and three helpers; checked FPC 3.2.2 x86_64-win64 |

All 91/220 content hashes plus each checksum manifest pass fresh extraction
verification. Every owned unit compiles and every packaged example runs.
The WFC journal workflow also passes cache/section learning, saved blend, further
blend, frozen-vocabulary fit, source-context attachment and saved replay using
only the authored core-example WAV. The replay renders 134144 frames without
caches or retraining.

ZIP SHA256:

- Core: `0818ef5083e958f0ef6944a2427a89f6e43dc26a02fb54916aec40b963d85b60`.
- WFC: `7a2241a8ede985f6d1a80dde5ca1971dde4d3e4df3fdaccbc8e062a1b216e4a9`.

WFC remains at `47fa3d8cb8f0f72bf53943eb5eb79758c8f22ce4`.
These are dependency subsets of the same current contracts. Refreshing packages
preserves previously credited delivery capability; it does not close target,
musical-quality or independent-use acceptance.

### Previous extracted API and listening-path checks

External copies of the existing source, pitch and spectrum fixtures pass against
the extracted core package on stable Win32. The extracted WFC package passes the
named-layer and saved-style fixtures on stable Win64, including transactional
replacement, mapped/fixed timing, preferences, rollback and saved reblends.

The existing voice operator is compiled as an external consumer with every
project unit path inside the extracted WFC package. Separate base and preferred
saved-grid checks pass typed edits, detached ownership, provider scopes and
rejected joint paths. The authored two-note style and its saved preference
reblend are copied as external fixture data; they are not packaged music assets.

Preferred and pitch-locked renders each produce **705600 stereo frames / 120
notes**. Actual WFC PCM verification, independent output checks and coupled-edit
checks pass. All eight WAV/JSON/MIDI/preview artifacts exactly match the prior
owned-grid checkpoint. This verifies delivery of the changed listening path;
it does not supply a listening verdict or learn general bass/voice roles.

Compiler warnings are confined to the existing WFC/RTL warnings; no owned-source
warning appears in these package/API builds. Logs and external consumers are in
`build/delivery-api-refresh/{core,wfc}/`, with grid replay hashes under
`wfc/grid-consumer/`. Library source directories remain free of build outputs.

<a id="clean-source-snapshot"></a>
## Pre-clock clean source snapshot

The last full-build isolated snapshot contains **301 owned files plus two gitlinks** at
`5231371804cfd7cf8466d256c42f9bad3bafbd85` on its own `hello-pythian` branch.
A fresh `git clone --no-local` fetched the exact Athena/WFC revisions from their
declared remotes. All owned file hashes match the workspace at snapshot creation;
the 82/107 packaged owned units match the same source. The root HEAD/index/branch
are preserved. Delivery/status documentation is updated after snapshot creation.

The full maintained `tools/build.ps1` integration build passes with checked
FPC 3.2.2 i386-win32 from `build/delivery-api-refresh/checkout/`. This includes the
current synthesis/workload checks, spectral queries, source-timed pitch queries,
layer timing/preferences, saved grid/duration consumers and complete native
learning/archive workflows on generated fixture inputs. The terminal result is
`full-status.log`, with commands and execution output in `full-build.log`.
The checkout remains clean; no owned-source compiler warnings appear. Existing
WFC/RTL warnings remain. This is one complete stable Win32 build plus the scoped
extracted-package stable Win32/Win64 checks above, not a full three-target suite.

The read-only WSL probe still returns installation help and exit code 1; no usable
Linux runner is established. Local Windows execution does not establish Linux,
remote CI, published source availability or independent downstream adoption.
No publication or root commit is made. The current partial delivery outcome
remains open for those gates and future accepted musical-provider integration.

A delivery-directory collision occurred before the snapshot setup: the newly
created core package was moved intact into this fresh directory after its checks
passed. Its log retains the original execution path. The historical directory's
core-package log was replaced during that attempt, and a failed invocation was
appended to its snapshot log; its old ZIPs and checkout were untouched. The
collision and relocated artifact are recorded in `path-collision.log`; current
evidence uses only the identified new package and snapshot.

## Preceding trajectory source packages

The 2026-09-19 snapshots include the
[spectral trajectory API](SOURCES.md#spectral-trajectory-checkpoint),
[magnitude/level factoring](SOURCES.md#magnitude-trajectory-checkpoint),
[saved trajectory adapter](WAVE-STYLE.md#saved-spectral-trajectories), explicit
[centered pitch API](PITCH.md#centered-periodic-measurement) and
[energy-fall API](ONSETS.md#energy-fall-evidence). Focused external consumers below
exercise these additions using only extracted library sources. The source and
voice operators remain repository tools; only the journal operator ships in the
WFC ZIP.

The snapshots also retain bounded
journal learning, saved blends/context replay, section selection, vocabulary
fit, spectral-band measurements, phase-family pulse fitting and streamed PCM
adaptation. Their ZIPs contain source and self-contained examples, with no
compiled binaries, private music, analysis caches or Phanes checkout.

| Artifact | Verified contents and target |
| --- | --- |
| `build/delivery-trajectories/core/pythian-source.zip` | 91 files; 81 core units; five examples; checked FPC 3.2.2 i386-win32 |
| `build/delivery-trajectories/wfc/pythian-source.zip` | 219 files; 81 core units / 24 adapters; seven examples; journal operator plus three helpers; checked FPC 3.2.2 x86_64-win64 |

All 90/218 content hashes plus `SHA256SUMS` pass fresh extraction checks.
Every owned library unit compiles and every packaged example runs with source
paths confined to the extracted package. The WFC package additionally builds
and executes `pythian.learn` from its delivered source and helper closure.
The core package has no WFC or operator dependency. Logs are under
`build/delivery-trajectories/package-{core,wfc}.log` and each package's
`consumer-check/`; source units in the extracted packages remain free of outputs.

ZIP SHA256:

- Core: `87d058bf32844fa3e9da1ff88699788f43c2e2f2e339fcd125dcfe69afa84e49`.
- WFC: `58d0d7a1b615b52ba6fedd2107d3524530b44653ade57501b4c7084ef665b13c`.

The companion retains revision `47fa3d8cb8f0f72bf53943eb5eb79758c8f22ce4`.
Packages are dependency subsets with one current artifact contract per purpose;
they are not parallel historical-format implementations.

### Trajectory and measurement delivery checks

Copies of the existing source, pitch and onset fixtures compile and run against
each extracted package, with separate fresh unit output per fixture. They exercise
raw and magnitude trajectories, centered timing controls and energy-fall evidence,
including rejection, ownership and boundary cases. The WFC package also passes
the existing saved-style fixture: raw trajectory evidence, union-knot shapes,
independent envelope weights, saved further blends and rendering survive reuse.
These fixture sources are external checks, not additional shipped examples.

A copy of `pythian.voices.demo` compiles against the extracted WFC package and its
delivered file helper. The previously verified recorded trajectory/static second
blend supplies external input data. Actual WFC generation and PCM verification
pass for three spans / five notes / 19845 stereo frames. WAV, MIDI and preview
bytes match the preceding independent consumer. WAV SHA256:
`29c8d382d02fdba4928c313f8345389ffcd5d21daa22525846c7885d6ba34d75`.
The archive remains unchanged. This is the existing short supported request,
not evidence of sustained musical phrasing or genre learning.

Evidence is in `build/delivery-trajectories/api-{core,wfc}.log`, each package's
`api-check/` and `wfc/trajectory-consumer/`. Core checks run on stable Win32;
WFC checks and the voice consumer run on stable Win64. All project unit paths
point inside the ZIP extraction; no checkout library unit, private recording or
Phanes dependency is needed to compile. The recorded archive is not distributed.

### Packaged journal workflow

The maintained package check and [delivered commands](../packaging/README.md)
use the core example's authored 66150-frame stereo WAV. Seven-feature cache
batches feed two disjoint ranges, `[0,24)` and `[32,56)`: 48 observations train
23 WFC states. A saved self-blend, then a further blend, retains two ranges with
192 weighted observations / eight weighted samples from that same recording.
These weights do not create eight independent recordings. Frozen-palette fit
measures the original 48 observations. Saved attachment retains 21 contexts /
139 windows; replay renders 134144 frames without training or journal inputs.

Only delivered Pascal source and generated example audio are used. This closes
the operator/source-closure gap for the selected Windows targets, not musical
quality, long-source throughput, or Linux/remote-CI acceptance. Package checking
now exercises this path through the existing CI package step; no separate test
framework or legacy format reader is introduced.

## Preceding trajectory clean snapshot

The trajectory delivery snapshot contains 295 owned files plus the Athena/WFC
gitlinks, on its own `hello-pythian` branch at
`0dccc0b5fbb76db48236bc2bed4c76a8dfebc7d4`. A fresh `git clone --no-local` under
`build/delivery-trajectories/checkout/` fetched both pins from their declared
public remotes. All owned file hashes match the workspace at snapshot creation;
the 81/105 delivered owned units also match that snapshot exactly. The root
repository's HEAD, index and branch were preserved.

The complete maintained `tools/build.ps1` passes with checked stable FPC 3.2.2
i386-win32 from this clone. It exercises native fixtures and operator workflows,
including trajectories, centered pitch, energy falls, saved styles and actual
WFC generation, using generated fixture inputs. The terminal result is
`build/delivery-trajectories/full-status.log`; `full-build.log` contains compiler
and execution output. Final checkout status is clean. Existing WFC/RTL warnings
remain; no owned-source warning or build/runtime failure was reported. This is
one complete maintained Win32 build, alongside the scoped extracted-package
Win32/Win64 checks above, not a full three-target or Linux run.

The snapshot and inventories are recorded in
`build/delivery-trajectories/snapshot.log`, `source-manifest.xml` and
`inventory-check.log`. The delivery/work/milestone records and synthesis-quality
crosslink are updated afterward. The earlier Linux environment probe did not
establish a usable runner; no new Linux or remote-CI execution is claimed.
Publishing remains unselected, and the root HEAD still contains only the initial
license. This isolated snapshot establishes local source availability only.

## Preceding journal source snapshot

The earlier `build/delivery-journal/` ZIPs have the same 91/219-file inventory
sizes, but predate trajectory and measurement additions. Their SHA256 values are
core `e3b3046e083e8eaeaaebab442a88c46f742a708e542d0a3c3948997200fefee4`
and WFC `0686e6116bbc5018f44fd873fb44ebee255f6a55d57fd664c0da87a7f0379504`.
The following build evidence remains scoped to that earlier source checkpoint.

An isolated local snapshot contains all 295 owned files plus the two pinned
gitlinks, leaving the working repository's index, branch and HEAD unchanged.
Its commit is `e4d1fe32504e9d55dd3f84deba1c1d1ff9da4952`, on its own
`hello-pythian` branch. A fresh `git clone --no-local` under
`build/delivery-journal/checkout/` fetched Athena and WFC from their declared
public remotes at the recorded pins. All 295 owned file hashes match the
workspace at snapshot creation, before this delivery-record update. Initial
Git status is clean, with no copied compiler output or private music.

The complete maintained `tools/build.ps1` integration build passes with checked
stable FPC 3.2.2 i386-win32 against this snapshot. This includes native core,
WFC passes and selective edits, current saved styles, exact note/audio checks,
journal learning and recorded-event workflows using generated fixture inputs.
The terminal outcome is `build/delivery-journal/full-status.log`, with commands
and output in `full-build.log`. Final Git status was clean. At that checkpoint,
all implementation, test, tool, example and packaging files matched the working
tree; the delivery/work/milestone records changed immediately afterward. Existing
WFC/RTL compiler warnings remained. Its package checks independently used fresh
ZIP extractions of those implementation bytes. This was not a full three-target suite or a
Linux run.

The read-only local WSL probe still returns installation help and exit code 1;
no usable Linux execution environment was established. Linux and configured
remote CI remain unverified. The working repository's HEAD still contains only
the initial license, so this local snapshot does not establish published-source
availability. Publishing remains unselected.

## Preceding seventy-unit delivery snapshot

The superseded `build/delivery-current/` packages retain 70 core units, optionally
20 adapters, and five/seven examples. Their 80/200-file inventories and consumers
passed checked stable Win32/Win64 respectively. ZIP hashes are core
`8e05deebe8ff25131931ee74fc352f68e583ac94f6cbe4680e72cd03090a8653` and WFC
`e50a77922bd8c1be836a20d787428543d6ea60601ad5d5b42630a1ae5bb83021`.
The associated 270-file local snapshot was
`cc70e056e8519e0b9a991e73f6fce1feb1cbd265`; its clean clone passed the maintained
stable-Win32 build. The separate development-Win64 separation consumer remains
scoped evidence for that older package. Later changes are covered by the current
snapshot and their recorded checks, not retroactively by those old ZIPs.

## Preceding source-phase source packages

The source-phase snapshots contain the shared WAV beat frontend and aligned
context/rhythm/pitch admission, including source origins in current style evidence.

| Artifact | Verified contents and target |
| --- | --- |
| `build/package-phase-core/pythian-source.zip` | 77 files; 67 core units; five native examples; FPC 3.2.2 i386-win32 |
| `build/package-phase-wfc/pythian-source.zip` | 196 files; 67 core units / 19 adapters; seven examples; FPC 3.2.2 x86_64-win64 |

All 76/195 content hashes plus `SHA256SUMS` pass extraction checks, every owned
unit compiles from extracted source, and every packaged example runs. Logs:
`build/package-phase-{core,wfc}.log` and their `consumer-check/` directories.
Detailed style/phase runtime evidence is in
[context admission](WAVE-CONTEXT-ADMISSION.md#selected-beat-phase-and-source-scope).
Earlier development PYST files lacking the source start tick must be regenerated;
these snapshots retain one current reader. The PCP schema is unchanged.

The complete maintained FPC 3.2.2 i386-win32 build also passes with current
styles regenerated (`build/phase-full-stable.log`, `build/phase-full-stable-status.log`).
The focused source-phase workflow produces 18 identical artifacts on stable and
development Win32; both Win64 compilers pass native phase/scope checks. This does
not establish full Win64 fixture-suite or Linux CI execution.

## Preceding extensible-input source packages

The current snapshots include extensible WAV input through the shared reader,
alongside the sample-time correction and existing synthesis/style APIs.

| Artifact | Verified contents and target |
| --- | --- |
| `build/package-extensible-core/pythian-source.zip` | 76 files; 66 core units; five native examples; FPC 3.2.2 i386-win32 |
| `build/package-extensible-wfc/pythian-source.zip` | 195 files; 66 core units / 19 adapters; seven examples; FPC 3.3.1 x86_64-win64 |

Every owned unit compiles from the extracted package, every example runs, and
all 75/194 delivered content hashes plus `SHA256SUMS` pass extraction checks.
Evidence: `build/package-extensible-{core,wfc}.log` and each `consumer-check/`.
The focused [extensible input workflow](WAVE-READING.md#extensible-input-evidence)
also covers stable/development Win32/Win64. These ZIPs supersede the timing-only
snapshots below. Their sources remain independent of Phanes, and the core ZIP
contains no WFC sources.

## Preceding sample-time source packages

The refreshed snapshots contain 66 core units and optionally all 19 WFC adapters.
Both include `SHA256SUMS`, covering every other delivered file. The maintained
package script captures the complete staged inventory, verifies extracted file
count, length and SHA256, then compiles all delivered owned units and runs each
consumer with source paths pointing into the ZIP extraction. No workspace music
or compiled unit cache is included.

| Artifact | Verified contents and initial target |
| --- | --- |
| `build/package-current-fixed-core/pythian-source.zip` | 76 files; 66 core units; five native examples; FPC 3.2.2 i386-win32 |
| `build/package-current-fixed-wfc/pythian-source.zip` | 195 files; 66 core units / 19 adapters; seven examples; FPC 3.2.2 x86_64-win64 |

The same extracted WFC package also compiles all 85 owned units and runs all seven
examples on FPC 3.3.1 i386-win32 and x86_64-win64 with standard checked flags.
These are additional Windows architecture checks, not a Linux or full Win64
fixture-suite claim. The current core package has no vendor directory.

The cross-target work found and fixed a synthesis boundary discrepancy:
`Ceil(ReleaseSeconds * SampleRate)` could retain an x87 extended intermediate,
adding a frame to an 80 ms release at 44100 Hz. The shared
`SampleFramesFromSeconds` helper now stores a Double product before floor/ceiling.
Offline and scheduled synthesis, including early release, share it. The instrument
consumer now has 91728 frames across the checked targets, preserving 16 notes and
20 layers. Exact integer-frame/PPQ clock behavior is unchanged.

Cross-target PCM is not claimed bit-identical universally. Against stable Win64,
the development Win32 consumers match all eight audio/MIDI files; the independently
learned event archive differs. Development Win64 differs in seven instrument
samples, 28 note-render samples and seven reconstructed event samples, each by
one PCM16 step, with identical geometry. Its other five output files match.
Both development targets load the stable Win64 archive using the original source
hashes and pass the maintained saved-event output checks. Independently recomputed
floating-point measurements can change archive bytes; a persisted archive retains
its exact source bindings and usable learned model.

The maintained full build also passes on FPC 3.2.2 i386-win32 after the timing fix
(`build/current-full-fixed-stable.log`, `build/current-full-fixed-status.log`).
Core, scheduled-synthesis and exact-clock fixtures pass on both compilers/targets.
Additional `-O3` checks pass on stable Win32/Win64 and development Win32. Development
Win64 hits compiler internal error `200304235` in the existing WAV metadata code
under `-O3`; standard checked flags pass. No source workaround or optimization
support claim is made for that compiler configuration.

Evidence: `build/package-current-fixed-{core,wfc}.log`, each package's
`consumer-check/`, WFC `consumer-trunk-{win32,win64}/replay.log`,
`cross-load-trunk-{win32,win64}/load.log`, and `build/sample-time-*/`.
The earlier `package-current-core` / `package-current-win64` snapshots predate the
sample-time fix and are superseded. Checksums are included with the final ZIPs;
they verify content integrity, not publisher authenticity.

## Native CI configuration

[The workflow](../.github/workflows/native.yml) checks out pinned submodules,
installs Ubuntu's FPC 3.2.2 compiler/standard units, verifies the compiler version,
runs the same maintained build and packages both source variants. Packages are
retained only after successful checks; failure logs are retained separately.
Permissions are read-only, actions use reviewed commit pins, and superseded runs
are cancelled. This is validation/artifact retention, not tagged release publishing.

The selected [Ubuntu compiler package](https://packages.ubuntu.com/fp-compiler)
and [runner software](https://github.com/actions/runner-images/blob/main/images/ubuntu/Ubuntu2404-Readme.md)
were checked when configuring the workflow. Local validation uses the installed
FPC YAML parser and PowerShell parser. No Linux host or remote Actions run has
been verified in this session; the first clean-checkout CI result remains open.

## Preceding fifty-eight-unit source packages

These preceding snapshots delivered all 58 native units and, optionally, 17 WFC
adapters. They include periodic/composed automation, typed musical context,
saved context selection, modulated delay, bounded WAV input/analysis and reverb
alongside the earlier synthesis, MIDI and recorded-event learning APIs.

| Artifact | Verified contents |
| --- | --- |
| `build/package-foundation-core/pythian-source.zip` | 67 files; 58 core units; five native examples |
| `build/package-foundation-wfc/pythian-source.zip` | 184 files; 58 core units and 17 adapters; five native and two WFC examples |

The maintained package script creates and extracts these ZIPs, then builds
every delivered owned unit and runs each delivered example using FPC 3.2.2
i386-win32. The same extracted ZIPs also pass complete owned-unit compilation
and every delivered example on FPC 3.3.1 i386-win32. Unit output stays outside
the extracted sources; consumer search paths point only into the package.

The new [processing consumer](../examples/pythian.example.processing.lpr)
reads 257-frame WAV blocks, applies stereo reverb through an effect chain, and
writes PCM16 blocks plus one explicit second of tail. It then reopens the file,
analyzes spectral windows and hashes source/output with bounded input buffers.
The package's authored core WAV supplies input, so it requires no workspace
tools or external recording. It produces 111132 stereo frames, 109 observations
and peak 0.1087234497, with SHA256
`5e5770bc719c22c4c9f3c473da1959d3f6c4c1e165bf8cd31cf8dc4a35a0356f`.
It enforces the example's source/sample/FFT limits and PCM headroom; it is not
an unlimited or real-time processor.

All delivered example MIDI/WAV/archive outputs match byte-for-byte across
compilers. The established outputs also match the previous 53-unit packages.
New context adapters are included in full-unit compilation; their detailed
runtime evidence remains in [context profiles](CONTEXT-PROFILES.md), rather than
being inferred from the older packaged WFC examples.

```powershell
./tools/package.ps1 -Compiler fpc -OutputDirectory build/package-foundation-core
./tools/package.ps1 -Compiler fpc -WithWfc -OutputDirectory build/package-foundation-wfc
```

Those directories now exist; choose fresh names for another run. Stable logs
are in each package's `consumer-check/`; development logs are in
`consumer-development/`. Command summaries are
`build/package-foundation-{core,wfc}.log`. The inventory and replay records are
`build/package-foundation-inventory.log` and `build/package-foundation-replay.log`.
Inventory checks compare every delivered source byte with the worktree and ZIP
extraction, complete owned notices, exact WFC revision, counts and excluded
assets. Delivered source was not changed after packaging.

ZIP SHA256 values:

- Core: `75704023550039f41ed84e41d2bd7b9820a38e5e4707308778b37103fa8da790`.
- WFC: `1591618999b4305f42836ac5fa05b8039578f4ae4b520800c6c2e82cb8d13156`.

This is local development delivery. No new full-suite run, clean Git checkout,
remote CI, additional platform or tagged release is claimed.

Subsequent integration evidence: the maintained full workflow also passes on
FPC 3.2.2 i386-win32 for this 58-core / 17-adapter tree, including all 53
maintained test programs and its core/WFC operator smokes.
`build/foundation-full-stable.log` and `build/foundation-full-status.log`
record that separate check. New effect/profile artifacts match their focused
outputs, and the canonical synthesis hash remains unchanged. This adds a
current local full-build checkpoint; clean Git, CI and other targets remain open.

## Earlier fifty-three-unit package checkpoint

The refreshed snapshots include all 53 native units and the 14 WFC adapters,
including instrument bindings and shared/persisted recorded-event learning:

| Artifact | Verified contents |
| --- | --- |
| `build/package-events-core/pythian-source.zip` | 61 files; 53 core units; four native examples |
| `build/package-events-wfc/pythian-source.zip` | 175 files; 53 core units and 14 adapters; four native examples and two WFC learning examples |

Both ZIPs were produced by the maintained package script on FPC 3.2.2 i386-win32.
The same extracted ZIPs compile every owned unit and run every delivered example
on FPC 3.3.1 i386-win32. All example MIDI, WAV and event-archive bytes match across
compilers. Stable logs are in `consumer-check/`; development logs and complete
comparisons are in `consumer-development/` and its `replay.log`.

The instrument consumer renders 16 notes / 20 layers / 91729 stereo frames. The
saved-event consumer learns 16 members in two independent runs, reloads its exact
archive from disk, and renders eight events / 91729 frames. Existing core, MIDI
notes/transport and WAV-learning outputs retain their established contracts.

```powershell
./tools/package.ps1 -Compiler fpc -OutputDirectory build/package-events-core
./tools/package.ps1 -Compiler fpc -WithWfc -OutputDirectory build/package-events-wfc
```

Use fresh directories for another run. Command summaries are
`build/package-events-{core,wfc}.log`. `build/package-events-inventory.log` records
ZIP counts/digests and verifies every delivered source byte against the tree,
complete owned notices, WFC's exact revision and absence of Phanes, compiled
files or music assets. No source files changed after packaging.

An additional `consumer-recorded/` under the WFC package builds copied operator
and checker sources against only the extracted library/companion paths. Its stable
compiler run loads the existing two-recording pulse archive without onset reports
or learning, reconstructs 64 events / 1207709 frames, and checks every PCM sample.
WAV, JSON, actual model text and the saved archive match the earlier verified
workspace artifacts exactly, including reversed source arguments. Its build/run
logs and `replay.log` retain this external-consumer evidence. The copied operator
and external recordings are verification inputs, not files shipped in the ZIP.

These snapshots remain local development delivery. The earlier full stable suite
covers its stated 52-unit checkpoint; no new full-suite, remote CI, clean Git
checkout, additional target or tagged release is claimed by package verification.

## Earlier fifty-two-unit package checkpoint

The preceding snapshots include all 52 native units, including shared chord frames
and bounded chord-frame MIDI, plus 12 adapters in the WFC variant:

| Artifact | Verified contents |
| --- | --- |
| `build/package-complete-core/pythian-source.zip` | 59 files; 52 core units; three native examples |
| `build/package-complete-wfc/pythian-source.zip` | 170 files; 52 core units and 12 adapters; three native examples and actual WFC WAV-learning example |

Both ZIPs were created and checked by `tools/package.ps1` using FPC 3.2.2, then
their complete owned-unit drivers and all delivered examples were rebuilt/run
on FPC 3.3.1. Both targets are i386-win32. Examples' MIDI and WAV bytes match
across compilers. `consumer-check/` and `consumer-development/` hold build/run
logs; `consumer-development/replay-final.log` records the completed comparisons.
The MIDI stream example writes only a MIDI file; the two other native examples
provide WAVs. Final replay checks cover the actual delivered outputs.

Commands, with `fpc` resolving to the stable compiler:

```powershell
./tools/package.ps1 -Compiler fpc -OutputDirectory build/package-complete-core
./tools/package.ps1 -Compiler fpc -WithWfc -OutputDirectory build/package-complete-wfc
```

These directories now exist; use fresh names for another run. Command summaries
are `build/package-complete-{core,wfc}.log`. ZIP inspection verifies all delivered
owned source matches the current tree, complete notices, the pinned WFC source
and no Phanes, binaries or music assets. Evidence is
`build/removal-audit/package-inventory.log`.

The WFC package's external `consumer-audio/` additionally rebuilds the native
chord MIDI fixture, event remix/checker and independent-voice consumer using only
extracted library/companion paths. The chord fixture passes complete actual WFC
bytes/plans. Pulse mode relearns 36 joint tokens / 71 WFC states from 79 recorded
intervals and verifies every one of 1207932 stereo frames. The voice consumer
verifies all preview PCM, 88 MIDI note gates and the actual full-score MIDI bytes,
including meter. Pulse WAV/JSON/model and all four current voice artifacts match
their earlier verified outputs exactly. Build/run logs are in `consumer-audio/`;
binary comparisons are in `build/removal-audit/consumer-replay.log`.

The [Phanes removal audit](REFERENCE-REMOVAL.md) used these checkpoint consumers,
complete source dispositions and retained notices. Other platforms, remote clean
checkout/CI, musical quality and broad recorded-music annotation accuracy remain
outside this evidence.

The normal stable build also passed after Phanes removal, including native/WFC
fixtures and all standard learner/remix smokes. Its complete log is
`build/removal-audit/post-removal-build.log`; no owned compiler warning was found.
The full-suite result is FPC 3.2.2 i386-win32 only, distinct from both-compilers
package compilation and example replay.

<a id="current-fifty-unit-package-checkpoint"></a>

## Earlier fifty-unit package checkpoint

This historical checkpoint includes local beat grids/tracking, pulse-event
admission, MIDI byte streaming and native note export:

| Artifact | Extracted contents and verification |
| --- | --- |
| `build/package-midi-core/pythian-source.zip` | 57 files; all 50 core units compile and all three native examples run |
| `build/package-midi-wfc/pythian-source.zip` | 168 files; all 50 core and 12 adapter units compile; native examples and actual WFC WAV-learning example run |

The package script checks them on FPC 3.2.2 i386-win32. The same extracted ZIPs
also compile their complete owned-unit drivers and run all included examples
on FPC 3.3.1 i386-win32, using fresh `consumer-development/units` output.
All example MIDI/WAV files match across the two compilers. The native notes
example produces 97020 stereo frames at 44100 Hz from eight notes on two channels;
MIDI import preserves the complete rendered PCM16 WAV.

Native notes MIDI SHA256:
`55b9895e53d73f4134cffbdb1f207da89063af6b332de2ad623a759716287ecb`.
Native notes WAV SHA256:
`159a1cfbcaf282860c156eeb3029a6c2879f65db42b7cca8089e804f311d3117`.

Commands use the verified stable compiler executable as `fpc`:

```powershell
./tools/package.ps1 -Compiler fpc -OutputDirectory build/package-midi-core
./tools/package.ps1 -Compiler fpc -WithWfc -OutputDirectory build/package-midi-wfc
```

These directories now exist; use fresh names for a rerun. Summaries are
`build/package-midi-core.log` and `build/package-midi-wfc.log`. Compilation and
execution logs are in each `consumer-check/` and `consumer-development/` directory.
`build/package-midi-inventory.log` records inspected ZIP counts, complete owned
notices and absence of Phanes, binaries and music assets. The WFC license and
revision remain included. No owned compiler warning was reported; unchanged
companion/compiler-library warnings remain.

The stable `consumer-audio/` under the WFC package contains copies of the
event-remix tool, its output checker, the independent-voice tool and their
three helper units. They are external consumers, not distributed ZIP contents.
Their only library/companion search paths point to the extracted package:

```text
-Fu../unpacked/pythian/src
-Fu../unpacked/pythian/adapters/wfc
-Fu../unpacked/pythian/vendor/wfc/src
```

Pulse mode uses the existing attributed Pixel Sprinter recording, shared archive
and fine-onset report. It admits 79 intervals, learns 36 joint tokens / 71 actual
WFC states and produces 64 events / 1207932 stereo frames. The output checker
verifies every sample and source/model/path identity. Audio, JSON and WFC model
bytes match the preceding corpus artifacts exactly. The independent-voice
consumer verifies actual WFC preview PCM and a strict MIDI round trip of all
88 notes, channels and both tempos. Its stereo WAV, preview WAV, MIDI and JSON
also match the checkout's preceding outputs.

`pulse-run.log`, `pulse-verify.log`, `voices-run.log` and per-program build logs
are in that external consumer directory. `build/package-midi-replay.log`
records all compiler/example and recorded-music/voice binary comparisons.
Library units resolve into `unpacked/pythian`; the source recording and analysis
archive remain external data, and no Phanes source or asset is used.

This refreshes package independence and current learner/voice consumer evidence.
It does not close the remaining precursor inventory, establish musical quality
or annotation accuracy, or prove another OS/CPU or clean remote checkout.

The complete `tools/build.ps1` at the fifty-unit checkpoint also passes on stable FPC 3.2.2
i386-win32 in `build/package-midi-stable-full.log`, including native fixtures,
actual WFC checks and operator smoke workflows. This refreshes full-suite
evidence through the fifty-unit checkpoint. No owned compiler warning or reported
build/test failure was observed; upstream warnings remain. The development compiler has
the complete package builds/example replay and focused runtime evidence described
above; a fresh development full-suite run is not claimed here.

The later [shared chord data and incremental MIDI extraction](CHORD-MIDI.md)
adds two core units and changes the voice tool's MIDI path. Its focused checks
are recorded separately; the fifty-unit ZIPs and this full-suite log retain
their original scope.

## Stable compiler compatibility

Existing FPC `3.2.2-rrelease_3_2_2-0-g0d122c4953` and
`3.3.1-20634-gd7f522a561` installations target i386-win32. The stable full build
passes in `build/stable-full.log`; the development full build after the same
changes passes in `build/stable-compat-development.log`. Both complete native
fixtures and tool smoke workflows; no owned-unit compiler warning was reported.
Existing upstream WFC warnings remain. Version-specific outputs stay separate.

Stable FPC rejected explicit real type casts accepted by the development compiler.
Typed assignments now perform those conversions in stereo downmix, spectral
frequency calculation, passage duration checks and JSON tempo output. The
resampling overflow fixture constructs its wide input through the same portable
assignment rule. Wide intermediate arithmetic is retained.

The stable FCL lacks `FpSHA256`. `pythian.hash` now implements SHA256 directly
using the algorithm in [FIPS 180-4](https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.180-4.pdf).
It uses fixed working storage, explicit modular arithmetic with range/overflow
checks enabled, and preserves the lowercase exact-byte digest contract. The
[hash fixture](../tests/pythian.tests.hash.lpr) checks empty input, `abc`, the
standard two-block text and one million `a` bytes. Optional
`-dFCL_SHA256_PARITY` compares binary lengths 0 through 256 with actual FCL SHA256
on the development compiler, covering padding and block boundaries. Logs:
`build/stable-hash.log` and `build/hash-fcl-parity.log`.

## Verified artifacts — 2026-09-14

| Artifact / check | Observed result |
| --- | --- |
| `build/package-stable-core-final/pythian-source.zip` | 47 files; all 42 core units compile from the extracted ZIP on FPC 3.2.2; core example runs |
| `build/package-stable-wfc-final/pythian-source.zip` | 157 files; 42 core and 11 adapter units compile; core and actual WFC examples run |
| `build/package-chord-wfc/pythian-source.zip` | Updated 158-file snapshot with the chord-stream extraction; 43 core and 11 adapter units compile after extraction; both external examples run |
| Package contents | Source, examples, notices and metadata; no Phanes, music assets, executables, object files or compiled units |
| Core example in both packages | 67032 stereo frames; SHA256 `314678b572f318be921aa0f133fef0348f3af5fd0737f70f48706e400269b324` |
| WFC example | 66 WAV observations learned; 64 generated grains rendered |
| Existing joint archive | Stable compiler admits `build/corpus/shared-paired.pyac` with the native hash implementation |
| Published passage replay | Stable compiler admits the original source/archive and reproduces all bytes of the existing 32-bar WAV, JSON and WFC model |

The included WFC revision is `47fa3d8cb8f0f72bf53943eb5eb79758c8f22ce4`.
Package build/run logs are beneath each output's `consumer-check/`; package
command summaries are `build/package-stable-core-final.log` and
`build/package-stable-wfc-final.log`. Archive and passage replay evidence is
`build/stable-published-archive.log`.
The updated chord snapshot is checked in `build/package-chord-wfc.log`, with
its consumer logs in `build/package-chord-wfc/consumer-check/`. Its contents were
inspected for the new core/adapter source, notices and absence of Phanes or
generated binaries/assets. The [chord stream evidence](CHORD-STREAMS.md) records
the new renderer's native and actual WFC parity checks.

These checks establish source closure and native consumer execution on the
verified compiler/target. They do not establish other OS/CPU support, clean remote
fetching, cross-platform floating-point identity, or musical listening quality.

## Earlier onset/event package checkpoint

The subsequent snapshots include the onset localizer, onset-event planner and
joint event adapter, plus the expanded ensemble capacity API:

| Artifact | Verified on FPC 3.2.2 i386-win32 |
| --- | --- |
| `build/package-inventory-core/pythian-source.zip` | 50 files; all 45 core units compile; external core example runs |
| `build/package-inventory-wfc/pythian-source.zip` | 161 files; all 45 core and 12 adapter units compile; external core and WFC examples run |

Commands, with `fpc` resolving to the verified stable compiler:

```powershell
./tools/package.ps1 -Compiler fpc -OutputDirectory build/package-inventory-core
./tools/package.ps1 -Compiler fpc -WithWfc -OutputDirectory build/package-inventory-wfc
```

These output directories now exist; replay requires fresh output names. Command
summaries are `build/package-inventory-core.log` and
`build/package-inventory-wfc.log`; build/run logs are in each `consumer-check/`.
ZIP contents were inspected for source, notices, current units and absence of
Phanes, generated binaries and music assets. Existing WFC/FCL warnings remain;
no owned-unit warning was reported.

The newer WAV workflow was also exercised as an external consumer. Copies of
`pythian.onsets.lpr`, `pythian.event.remix.lpr`, `pythian.tools.files.pas` and
`pythian.tests.events.output.lpr` were placed in the WFC package's `consumer-check/`.
They are not distributed in the ZIP. Compilation used `-B -Sa -Cr -Co -Ci -gl`,
freshly rebuilt unit output and only these project unit search paths:

```text
-Fu../unpacked/pythian/src
-Fu../unpacked/pythian/adapters/wfc
-Fu../unpacked/pythian/vendor/wfc/src
```

From that consumer directory, the onset tool analyzed the existing attributed
`../../corpus/pixel-sprinter.wav` into `pixel-onsets-fine.json` and
`pixel-onsets-listen.wav`. The event tool used `../../corpus/shared.pyac`, that
source and report, seed 731 and 128 events. The output checker verified all
547459 stereo frames, source/model identities and latent path. Binary comparison
then confirmed identical onset report/audition and event WAV/JSON/model bytes
against the earlier corpus outputs. Logs: `onsets-run.log`, `onsets-replay.log`,
`events-run.log`, `events-verify.log` and `events-replay.log` under that consumer
directory. Compiler logs use the corresponding program name plus `-build.log`.

This verifies the current learner/listening path without Phanes source or assets.
The audition retains the original recording with synthesized location cues;
the event output reconstructs learned selections of source intervals. Neither
this package check nor byte identity establishes musical quality, annotated
onset accuracy or inferred phrase structure. No fresh full-suite, other-platform
or remote-checkout claim follows from this scoped verification.
