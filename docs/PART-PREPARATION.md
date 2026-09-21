# Derived stem/mix preparation

[Part evaluation](PART-EVALUATION.md) · [Task](TODO/NS-3_parts_01.md)

This native operator prepares a separately identified development mixture from
hash-bound PCM16 stems. It does not reconstruct the publisher's original mix or
qualify its undocumented preparation. All derivatives inherit their source
recording's development exposure and must remain in the same recording family.

## Frozen construction

Before processing the development recording, fix each stem's gain at **1/16**,
offset at zero, and output at the input sample rate and channel count. Quantize
each scaled sample once to PCM16 with the library's nearest, half-away-from-zero
rule. Store those derived stems, reopen them, and sum their signed PCM16 integers
without further scaling. Store the exact sum as a separate PCM16 mix. No fitted
gain, normalization, offset search, resampling, filtering or metadata gain occurs.

Support 1–15 mono or stereo PCM16 stems with identical frame count, channels and
sample rate, at most 960 seconds and 48000 Hz. At this fixed gain each derived
sample is in [-2048, 2048]; at most 15 stems sum within [-30720, 30720]. Reject
violations rather than clip. This bound holds for arbitrary supported input,
independently of its observed peak. The derived stems lose up to half a PCM16 LSB
relative to the ideal scaled input; they have different identities and must be
used as the references for this constructed mix. Original source bytes are kept.

Verify every output sample twice at distinct boundaries: derived stem decoding
against the signed source integer divided by 16 using an integer rounding oracle,
then decoded mix against the sum of decoded derived stems. Preserve exact sample
positions and lengths. Report the measured input/output peaks, changed samples,
and worst scaled-input quantization error (in sixteenths of an output LSB).
Zero reconstruction error is required. Failure leaves an incomplete fresh output
directory and no completion manifest; never treat loose WAVs as a qualified packet.

## Input and output

Run from the repository root. The current operator deliberately accepts only the
existing Track00001 development group, UUID and archive identity; support for a
new source needs an explicit provenance and preparation decision. Input is the
current source-preflight JSON binding
and its expected SHA256, with `exposure: "development"`, a nonempty `group`,
`source_uuid`, `archive_sha256`, original `mix` path/hash, `auxiliary` path/hash
entries, and `stems` entries containing `stem_id`, `wave` path/hash and `midi`
path/hash. Paths are relative to the binding directory, restricted to safe ASCII
member paths without traversal. Stem IDs are unique ASCII filenames. All bound
files are hashed while held open against ordinary writes; total input is at most
1 GiB. MIDI and original mix bytes are hashed only, not used to infer notes or fit
the construction. Concurrent source mutation is unsupported. The current source
is CC BY 4.0 and must include the exact `CC-BY-4.0.txt` auxiliary file; preserve its
full notice in the packet. Source author attribution is retained in this project's
[provenance](PROVENANCE.md#attributed-mixture-development-source).

The output must be a new direct child of ignored `build/role-prepared/`. It contains
derived stem WAVs, `mix.wav`, the unchanged binding and license, and a completion
`manifest.json` written last. The manifest binds the tool, this policy, original
binding, artifacts and source family, and declares unknown role/acoustic timing,
unverified family independence and an unqualified original mix. Do not infer
annotation acceptance, estimator accuracy or task completion from preparation.

Proposed execution limits per preparation: 180 seconds, 256 MiB private memory,
and 1 GiB outputs (native time/input/output bounds; supervised memory). Reuse the
existing native toolchain and library WAV reader/writer; no additional runtime.
Two fresh executions must reproduce WAV and manifest bytes. Existing-directory
and wrong-hash rejection must preserve prior output and source bytes.

```powershell
New-Item -ItemType Directory -Force build/part-prepare/units | Out-Null
fpc -B -Sa -Cr -Co -Ci -gl -gh -Fusrc -Futools -FUbuild/part-prepare/units -FEbuild/part-prepare tools/pythian.part.prepare.lpr
./build/part-prepare/pythian.part.prepare.exe --controls
./build/part-prepare/pythian.part.prepare.exe build/role-reference/binding.json 060e2bd37e99f62be5c71166d104eee63ed2507d71276ff71ab358aaff4ca222 build/role-prepared/example
```

Final acceptance evidence belongs in [part evaluation](PART-EVALUATION.md). This
policy stays bound to the construction, independently of the current QA verdict.
The original development mix's 13-LSB residual and failed 11-LSB candidate bound
remain unchanged.
