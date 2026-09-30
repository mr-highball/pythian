# Minimal synthesis consumer packet

[Package evidence](PACKAGING.md#accepted-minimal-artifact--2026-09-30) ·
[Consumer contract](CONSUMER-CONTRACT.md) · [Independent-use task](TODO/NS-6_delivery_07.md)

Use the frozen source package from
[`de45c9eb05c9592e15ab19a1b581659610722d13`](https://github.com/mr-highball/pythian/commit/de45c9eb05c9592e15ab19a1b581659610722d13),
verified on stable FPC 3.2.2 Win32, Win64 and Ubuntu 24.04 x86_64 Linux. No actual
independent reviewer run is recorded yet. This packet requests that result;
implementation-agent tests and CI are preparation only.

## Obtain the artifact

Open the [successful native run](https://github.com/mr-highball/pythian/actions/runs/36677194774)
and download `pythian-source-packages`, artifact `11080696677`. Its outer ZIP
contains two source ZIPs. Choose the core package for minimal synthesis, or the
WFC package for the optional caller-provider example. These contain source,
examples, full notices, provenance, metadata and `SHA256SUMS`, with no compiler
or private media. The source archives work with the supported native compilers;
their metadata records the builder target. CI artifacts have a 14-day retention
period. If this exact artifact is unavailable, request a frozen replacement with
reviewed identity/evidence rather than substituting a moving checkout.

| Source ZIP in downloaded artifact | Bytes | SHA256 |
| --- | ---: | --- |
| `ci-package-core/pythian-source.zip` | 380450 | `10254a8cbef9d436fb390e86bb2056dd4c4069fdc812654dd98ab56cb0ac05a7` |
| `ci-package-wfc/pythian-source.zip` | 1281236 | `5703c330bf1385d96a6e120ccf2a12788e2fec23fb23eff7edd6d554b234d8df` |

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

Both examples reject invalid controls/seeds, missing parents and existing
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
