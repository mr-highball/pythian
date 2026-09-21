# Derived stem/mix preparation

[Part evaluation](PART-EVALUATION.md) · [Task](TODO/DONE/NS-3_parts_01.md)

This native operator prepares a separately identified mixture from
hash-bound PCM16 stems. It does not reconstruct the publisher's original mix or
qualify its undocumented preparation. All derivatives inherit their source
recording's exposure and must remain in the same recording family. Reserved
reference-only evaluation material remains unavailable for learning or tuning.

## Frozen construction

Before processing either supported recording, fix each stem's gain at **1/16**,
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

Run from the repository root. The operator accepts only these exact source
tuples from the pinned BabySlakh archive:

| Group | Source UUID | Exposure |
| --- | --- | --- |
| `BabySlakh-4603870-Track00001` | `1a81ae092884234f3264e2f45927f00a` | `development` |
| `BabySlakh-4603870-Track00002` | `0c3b7bf33cd3d67970ecfc06339bfc49` | `reference-only-evaluation` |

The archive SHA256 is
`6490dc83d8b59ccbe7e9e0304023af8e585d2065f9a5f5921952a273fac4a9b0`.
Other identities or exposure combinations reject. Input is the current
source-preflight JSON binding and its expected SHA256, with `exposure`, `group`,
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

Evaluation additionally requires `family_decision` as a path/hash object with
path `family-decision.md` and SHA256
`a8163978ed1cd303e79b39ed606e228676cde6a100908553e2f050214f155db5`.
Exactly one matching auxiliary entry must bind those bytes. Exactly one auxiliary
must bind each original evaluation identity: metadata SHA256
`d8ce65e81c0d09c6445e4ff2a497647290ef5d0b8270401c830c58a12807182e`
and original score SHA256
`0fedda3ebff9e0ffa5ba6462eec4f1f717e3602a34722327e975d24774aebd3d`.
The operator verifies the actual bytes through the same held-stream checks as
all other inputs. The decision is optional for the existing development binding;
when supplied it must satisfy the same decision identity check. This admits a
specific accepted family decision, not arbitrary families supplied by callers.

The output must be a new direct child of ignored `build/role-prepared/`. It contains
derived stem WAVs, `mix.wav`, the unchanged binding and license, the family
decision when bound, and a completion `manifest.json` written last. Its current
kind is `derived-stem-mixture`. The manifest binds the tool, this policy, original
binding, artifacts and source family, and copies the exact source exposure.
`family_qualification` is `accepted-two-family-reference-scope` when the decision
is bound, otherwise `not-bound`. `model_training_overlap` remains `unknown`;
`independent_family_verified` and `independent_accuracy_verified` remain false.
This distinguishes the scoped family decision from broader independence claims.
Role/acoustic timing verification and original-mix qualification remain false.
Do not infer
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
