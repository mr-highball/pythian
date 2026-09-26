# Native delivery checkpoint — 2026-09-20

[Consumer contract](CONSUMER-CONTRACT.md) · [Package history](PACKAGING.md) ·
[Project profile](../PROJECT.md) · [Delivery milestone](MILESTONES.md#wav-05-delivery)

This infrastructure checkpoint binds clean native execution and source-package
consumers to one pushed development revision. It does not validate later source
edits or claim final musical, listening or independent-consumer acceptance.

## Frozen source and closure

| Input | Exact identity |
| --- | --- |
| Root source | `0ecfe34997bca5b16c9fb22282fc62b1df03a491` |
| WFC companion | `47fa3d8cb8f0f72bf53943eb5eb79758c8f22ce4` |
| Athena standards | `909336d808f0c40b297426e23aa58426a75c6516` |
| Owned source closure | 85 core units; 26 companion adapters |

A separate clone was detached at the root revision under ignored build output.
It copied committed Git objects, not the
active working tree. `git submodule update --init --recursive` fetched both
recorded public submodule URLs and checked out the exact gitlinks; no dependency
source was edited. Root/submodule status was clean before execution. The root
tracks no generated `.ppu`, `.o`, `.exe`, `.wav` or `.zip` files, and `build/` is
ignored. Initial identities/status are retained in
`build/native-checkpoint-0ecfe34/closure-before.txt`.

The clean remote checkout independently fetched the same source and recursive
submodules. Phanes is absent from the gitlinks and packages; its historical source
identity and derived notices remain in the packaged provenance. No source music,
private input, optional research model or runtime is needed by these consumers.

## Checked Windows builds and extracted consumers

Both existing native compilers report FPC 3.2.2. `fpc` targets `i386-win32`;
`ppcrossx64` targets `x86_64-win64`. Each target uses the maintained full build
once, with `-B -Sa -Cr -Co -Ci -gl`, followed by one freshly created core package
and one companion package. Separate compiler/target and package output directories
prevent compiled-unit reuse between checks.

From the detached checkout, the commands are:

```powershell
./tools/build.ps1 -Compiler fpc
./tools/package.ps1 -Compiler fpc -OutputDirectory build/delivery-win32-core
./tools/package.ps1 -Compiler fpc -WithWfc -OutputDirectory build/delivery-win32-wfc
./tools/build.ps1 -Compiler ppcrossx64
./tools/package.ps1 -Compiler ppcrossx64 -OutputDirectory build/delivery-win64-core
./tools/package.ps1 -Compiler ppcrossx64 -WithWfc -OutputDirectory build/delivery-win64-wfc
```

The actual invocations select the existing compiler executables explicitly;
the names above denote those same verified compilers, with their standard RTL/FCL
configuration. No installation or global configuration change was made.

| Target | Full maintained build | Core ZIP consumer | Companion ZIP consumer |
| --- | --- | --- | --- |
| FPC 3.2.2 i386-win32 | Pass | Pass | Pass |
| FPC 3.2.2 x86_64-win64 | Pass | Pass | Pass |

Each ZIP is extracted freshly, its complete inventory, byte lengths and hashes
checked, then every delivered owned unit is compiled from that extraction. Core
packages compile 85 owned units without vendor search paths or vendor source in
the package. Companion packages compile 111 owned units plus the recorded WFC
source. Core packages contain 94 hashed content files plus `SHA256SUMS`; companion
packages contain 224 hashed content files plus `SHA256SUMS`.

The five core examples cover WAV round trip, exact MIDI/note rendering, forward
MIDI transport, instruments and streamed processing. Companion consumers also
perform actual WFC learning/reconstruction and saved-event reload. The delivered
journal operator checks bounded caching, source ranges, partition selection and
rejections, weighted blend, further blend, fit, context selection and saved replay.
All source paths point into the extraction, with fresh compiler output in its
sibling `consumer-check/`. The package source tree receives no generated output.
Authored example audio supplies the entire test input; this is mechanical
delivery evidence, not recorded-style quality or independent reviewer acceptance.

### Windows artifact identities

All four ZIPs are retained below
`build/native-checkpoint-0ecfe34/`; the table names their containing
directories. Each archive is named `pythian-source.zip`.

| Directory | Bytes | SHA256 |
| --- | ---: | --- |
| `delivery-win32-core` | 323501 | `cf68996196f80424b6df2c15254286f0326d49695384a97317471871af16594e` |
| `delivery-win32-wfc` | 1117360 | `4864adb615f3f847ac63ed18524d22634291e62fe363781542a575fb7dce9132` |
| `delivery-win64-core` | 323501 | `ac712e11d32e0e1168d06dbe7973b74c19f465c49188e032b4aa96ae074780e9` |
| `delivery-win64-wfc` | 1117364 | `ccc1534d5b155199a48904d5cae010dadc324a78351d1161b6cad2d118614196` |

These identify the produced archives; ZIP timestamps and target-specific package
metadata are not a promise of identical archive bytes across separate builds.
`PACKAGE-INFO.txt`, `SHA256SUMS`, complete source notices, root license and
provenance accompany each artifact. Both companion packages include the exact WFC
revision and its complete license. The extracted root license and provenance
match the frozen checkout byte-for-byte. Inventory verification also protects
the original source notices from alteration during packaging.

Local logs are under `build/native-checkpoint-0ecfe34/`: `win32-build.log`,
`win64-build.log`, and `win32-core-package.log`, `win32-wfc-package.log`,
`win64-core-package.log`, `win64-wfc-package.log`. Each package directory retains
its individual compiler/run logs in `consumer-check/`. Identity and hygiene
summaries are `windows-package-identities.json` and `package-closure.json`.
The copied evidence archives were rehashed against the identities above. Final
root/submodule status remains clean; `closure-after.txt` records the exact pins
and ignored output directories. `terminal-results.txt` records exit-zero outcomes
for both full builds and all four package commands. Extracted packages contain no
compiled units, executables, WAVs or ZIPs, and no embedded checkout paths were found.

## Successful remote Linux run

[Run 35557200115](https://github.com/mr-highball/pythian/actions/runs/35557200115)
and job `106203026246` completed successfully at the same frozen root revision.
The job ran from 2026-09-21 03:20:36 to 03:26:46 UTC on Ubuntu 24.04,
FPC 3.2.2, x86_64-linux. Recorded step conclusions show successful recursive
checkout, compiler setup, full maintained integration build, both extracted
package consumers and both artifact uploads. This is an executed terminal result,
not an inference from the [workflow configuration](../.github/workflows/native.yml).

| Retained remote artifact | ID | API-reported archive SHA256 |
| --- | --- | --- |
| `native-fpc-logs` | `10621275141` | `d88240428612809200c387026f7642230d0dfdff7b010a8fa35dfd98520d689d` |
| `pythian-source-packages` | `10621197298` | `298e6db4f329d1937abd583634c51fae0cf844806ed0006ba3c5cc0b603b2e54` |

The saved API responses bind both artifacts to run `35557200115` and source
`0ecfe34997bca5b16c9fb22282fc62b1df03a491`. Copies are retained locally in
`build/native-checkpoint-0ecfe34/ci-jobs.json` and `ci-artifacts.json`, with hashes in
`ci-metadata-hashes.txt`. The workflow retains remote artifacts for 14 days.
Unauthenticated log/artifact download returned HTTP 401. Their contents and Linux
compiler warnings were not locally inspected; the artifact digests above are
reported metadata, not independently rehashed downloaded bytes.

## Warnings, failures and acceptance boundary

Windows logs retain existing WFC constructor visibility, constant-range comparison
and unreachable-code warnings, plus RTL generic dictionary abstract-enumerator warnings.
No owned-source compiler warnings were found in either full build or the package
compiler logs. All six maintained build/package commands passed on their first
run; there was no failed boundary to repair or suite to repeat.
No dependency source was changed to suppress them. WFC/RTL informational compiler
notes remain in the same logs. Expected negative consumer cases, such as invalid
partition inputs, retain their rejection logs separately from process success.

The stable native matrix, dependency closure and extracted source delivery are
the acceptance scope. Development FPC 3.3.1 evidence remains the earlier dated
checks in [package history](PACKAGING.md); it was not rerun for this checkpoint.
Current working edits and later pushed revisions are outside these exact-source
results. [Final accepted-workflow packaging](TODO/NS-6_delivery_03.md) must revalidate
the accepted musical workflow and affected CI path. An actual external consumer
verdict remains in [independent acceptance](TODO/NS-6_delivery_04.md). This checkpoint
adds no browser, device deadline, durable file replacement, listening or general
cross-platform floating-point parity claim.
