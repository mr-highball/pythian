# Minimal synthesis consumer packet

[Package evidence](PACKAGING.md#accepted-caller-provider-artifact--2026-09-30) ·
[Consumer contract](CONSUMER-CONTRACT.md) · [Independent-use task](TODO/NS-6_delivery_07.md)

Use the frozen source package from
[`bdd55eb04a89d0271241da6111f42e47039055d6`](https://github.com/mr-highball/pythian/commit/bdd55eb04a89d0271241da6111f42e47039055d6),
verified on stable FPC 3.2.2 Win32, Win64 and Ubuntu 24.04 x86_64 Linux. No actual
independent reviewer run is recorded yet. This packet requests that result;
implementation-agent tests and CI are preparation only.
This later handoff preserves the accepted `de45c9e` minimal and `912f037`
source/effect artifact histories; it does not relabel those archives.

## Obtain the artifact

Open the [successful native run](https://github.com/mr-highball/pythian/actions/runs/36698183025)
and download `pythian-source-packages`, artifact `11088603551`. Its outer ZIP
contains two source ZIPs. Choose the core package for minimal synthesis, or the
WFC package for the optional caller-provider example. These contain source,
examples, full notices, provenance, metadata and `SHA256SUMS`, with no compiler
or private media. The source archives work with the supported native compilers;
their metadata records the builder target. CI artifacts have a 14-day retention
period. If this exact artifact is unavailable, request a frozen replacement with
reviewed identity/evidence rather than substituting a moving checkout.

| Source ZIP in downloaded artifact | Bytes | SHA256 |
| --- | ---: | --- |
| `ci-package-core/pythian-source.zip` | 396790 | `99ddb535ce2a65d7cbc364ef92fe7f0ca5f521288975334bf9a088c5cc6fe365` |
| `ci-package-wfc/pythian-source.zip` | 1326453 | `6af4d77e041edb05169b5f7ad7b466eea0372d36d10d6676c045e715331074a1` |

Verify the chosen ZIP hash before extraction (`Get-FileHash` on Windows or
`sha256sum` on Linux). Extract into a fresh directory outside the Pythian
checkout. Inside its `pythian` directory, retain `LICENSE`, `PROVENANCE.md`,
`PACKAGE-INFO.txt` and the checksum inventory. Linux can verify every delivered
file with `sha256sum -c SHA256SUMS`; the same SHA256 values are available for
Windows checksum tools. No repository-only verification program is needed.

## Build and use the core

Use an existing FPC 3.2.2 installation with standard RTL/FCL for i386-win32,
x86_64-win64 or x86_64-linux on Ubuntu 24.04. Record `fpc -iV`, `fpc -iTP` and
`fpc -iTO`; explicitly select your compiler if PATH points elsewhere. If using
an existing cross compiler, include its target flags in the probes and build.
Compiler setup belongs to the consumer; a development compiler does not qualify
this supported-target verdict.

From the extracted `pythian` directory, create `build/units` and `build/bin`
(`mkdir -p build/units build/bin` on Linux, or
`New-Item -ItemType Directory -Force build/units,build/bin` in PowerShell), then:

```text
fpc -B -Sa -Cr -Co -Ci -gl -Fusrc -FUbuild/units -FEbuild/bin examples/pythian.example.core.lpr
build/bin/pythian.example.core base.wav 1 731
build/bin/pythian.example.core quieter.wav 0.5 731
build/bin/pythian.example.core replay.wav 1 731
```

Windows executables use `.exe`. Quote paths with spaces. Every output must be a
fresh `.wav` path in an existing parent directory. The example creates three
caller-controlled tones, synthesizes, saves PCM16 and reloads the actual saved
file. Each result must be 44,100 Hz, stereo, 67,032 frames, including release.
Compare the actual `base.wav` and `replay.wav` SHA256 values: they must match on
your target. `quieter.wav` must differ; gain 0.5 halves amplitude within PCM16
quantization. Listen at comfortable settings and report audible defects and
usability. No automatic playback is performed.

You may also write a small caller program using the same public units. Record
your inputs and the actual load-or-create → control → synthesize → save → reload
route. No library edits or unpublished dependencies should be required.

## Optional caller-provider path

Use the WFC source ZIP and first create separate `build/wfc-units`. It includes
the pinned companion and complete adapter/native-tool closure:

```text
fpc -B -Sa -Cr -Co -Ci -gl -Fusrc -Fuadapters/wfc -Fuvendor/wfc/src -Futools -FUbuild/wfc-units -FEbuild/bin examples/pythian.example.wfc.provider.lpr
build/bin/pythian.example.wfc.provider provider.wav 0.25 731
build/bin/pythian.example.wfc.provider louder.wav 0.5 731
build/bin/pythian.example.wfc.provider provider-replay.wav 0.25 731
```

The caller authors note samples, its provider description/contracts and a layer;
actual WFC generation feeds native synthesis. Every saved/reloaded result must
be 16,000 Hz, stereo, 16,000 frames. Gain 0.5 doubles default amplitude within
quantization; fixed-input/seed replay must match actual file hashes on your
target. This demonstrates a canonical-pitch provider, without claiming custom
semantic codecs, accepted recorded learning or learned styles.

## Optional caller-source/effect path

Either downloaded package also includes `docs/CALLER-EXTENSIONS.md` and an
external Pascal source/factory plus stateful stereo delay. From the same fresh
extracted root, create a separate `build/extension-units` and use:

```text
fpc -B -Sa -Cr -Co -Ci -gl -gh -Fusrc -Fuexamples -FUbuild/extension-units -FEbuild/bin examples/pythian.example.extensions.lpr
build/bin/pythian.example.extensions extended.wav 0.35 0.3 731 257
build/bin/pythian.example.extensions extended-replay.wav 0.35 0.3 731 1
build/bin/pythian.example.extensions extended-changed.wav 0.7 0.3 731 257
```

The caller unit owns the harmonic-mix parameter and retained delay state;
no WFC or Pythian source edits are needed. Each saved/reloaded WAV must be
16,000 Hz, stereo, 16,240 frames, including the 240-frame delay tail. The first
two actual WAV hashes must match despite their different read caps; the changed
harmonic mix must change the output. Listen to the extended output at the
declared settings and report synthesis defects, audible behavior and whether
the packaged guide lets you adapt the public caller unit without private help.
This is useful outside-use/listening evidence for the separately open
[extension task](TODO/NS-2_extension_01.md), with acceptance assessed against
its full contract. Our existing mechanical runs are not your listening verdict.

The examples reject invalid controls/seeds, missing parents and existing
outputs. An existing valid WAV is preserved. Direct writing may leave partial
new output after an I/O failure; repair the cause and choose a fresh path.
Concurrent writers are unsupported. Ownership and work are bounded as described
in the packaged README; no device playback, physical write atomicity or hard
real-time guarantee follows.

## Return these results

- A consumer name or pseudonym and confirmation of an actual non-agent run
  outside the implementation checkout; omit private contact/machine paths.
- Received source revision and ZIP hash, checksum verification, and companion
  pin if used.
- Which optional extension route you used, its exact parameters and actual
  output hashes, listening verdict and any changes to your own caller unit.
- OS/CPU, compiler version/target probes and relevant setup differences.
- Exact commands, any caller changes or external input provenance, and build/
  runtime success or useful error text without credentials/private paths.
- Actual output hashes and frame/rate/channel geometry, changed-control result,
  same-target replay/reload equality and recovery observations for failures.
- Actual listening settings, audible defects and documentation/usability feedback.
- A scoped minimal-use pass/fail/unknown verdict and any support/repair needed.

Supported reproduction blockers need repair and an affected-path recheck;
broader feature requests retain their own task owner. A successful minimal run
does not establish recorded accuracy, full style/blend acceptance, a physical
operator verdict or ecosystem adoption. The missing external condition is a
willing independent consumer and their supported environment. No invitation or
third-party message has been sent as part of this packet.
