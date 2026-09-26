# Bounded WAV input and RF64 reading

[Home](../README.md) · [Architecture](ARCHITECTURE.md) ·
[WAV learning](WAV-LEARNING.md) · [Work](WORK.md)

## Reader and ownership

`pythian.wave.read.TWaveFrameReader` borrows a seekable `TStream`.
The container starts at the stream's current position and must extend exactly
to its end. Construction scans all chunk headers, including chunks after audio,
then positions the stream at the data payload. It does not read the whole audio
payload. The caller keeps the stream open and its contents stable; reader calls
control its position and must be serialized.

Read-only properties expose sample rate, channels, original format tag, decoded
encoding tag, container/valid bits, channel mask, Int64 frame count/position,
RF64 status and failure state.
`ReadFrames(Count=4096)` returns an owned interleaved `TAudioSamples` array
containing up to the requested number of frames. A positive request at EOF
returns an empty array. The count must be 1..65536. A short final block is valid.

`SeekFrame(Frame)` uses exact Int64 frame coordinates from zero through the
audio end. Reads always seek to their confirmed frame position first. No sample
clock, wall-clock scheduling or playback device is involved.

The decoder uses a fixed 4096-byte scratch buffer and at most 65536 stereo
frames per returned block (512 KiB of Single samples). A bounded RF64 table is
temporary during header scanning. Audio length does not determine block memory.
Short positive source reads are accumulated; zero before the requested byte
extent is a truncation error.

## Supported formats and admission

Supported samples are little-endian PCM8/16/24/32 and IEEE float32, mono/stereo,
at the existing 1..384000 Hz rates. PCM8 is unsigned; wider PCM is signed.
Integer scaling and float headroom retain the existing decoder's semantics.
PCM32 is represented as Single, so its least significant integer bits may round.

RIFF and RF64 containers accept format/data chunks in either order and skip
unknown chunks, including odd-byte padding. The parser rejects duplicate format
or data chunks, missing/truncated fields, inconsistent byte rate/alignment,
partial frames, mismatched container sizes and exceeded bounds.
There are at most 65536 chunks and 4096 RF64 size-table entries.
Container extent is at most 9007199254740991 bytes, matching the writer envelope.

RF64 requires a leading `ds64` chunk. Sentinel size fields use its 64-bit
replacement sizes; ordinary 32-bit RIFF/data sizes remain authoritative.
Additional sentinel chunks consume matching table entries in occurrence order.
A nonzero `ds64` sample count must equal the admitted audio frame count;
zero is accepted as unspecified. Size-table values remain bounded by the
container-size envelope. Duplicate `ds64` chunks reject.

These RF64 size rules follow
[EBU Tech 3306 v1.1, section 3.4 and Annex A.2](https://tech.ebu.ch/files/live/sites/tech/files/shared/tech/tech3306v1_1.pdf).
The implementation supports the existing mono/stereo encodings, not the
specification's complete multichannel/broadcast feature set. Compressed formats,
float64, multichannel layouts and metadata interpretation
remain unsupported by this reader.

## Extensible PCM and float input

The same reader accepts WAVE_FORMAT_EXTENSIBLE in RIFF or RF64, including data
before format. `FormatTag` retains 65534; `EncodingTag` resolves the complete
standard subtype GUID to PCM (1) or IEEE float (3). Ordinary files expose their
original tag as the encoding, full container precision and an unspecified mask.
There is no new native archive format or separate compatibility reader.

PCM containers remain 8/16/24/32 bits. Valid precision must be 1..container bits;
left-aligned samples use the existing container scaling. Unused low bits must
be zero and are checked when samples are read. Float requires 32 container and
valid bits, preserves finite headroom, and rejects NaN/Infinity on read.

An unspecified channel mask (zero), mono front-center (4), or stereo front-left /
front-right (3) fits the current clip contract. Other speaker assignments reject
as unsupported, rather than losing their meaning in a mono/stereo conversion.
The extension must contain at least 22 declared bytes within the format chunk;
additional declared bytes are skipped. Unknown GUIDs and incomplete headers reject.

This is new native code following Microsoft's
[extensible format definition](https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/ksmedia/ns-ksmedia-waveformatextensible)
and [subtype GUID mapping](https://learn.microsoft.com/en-us/windows-hardware/drivers/audio/converting-between-format-tags-and-subformat-guids),
checked 2026-09-15. No Windows units or external decoder are required. The output
writer continues producing the existing canonical PCM16 format.

## Extensible input evidence

FPC 3.2.2 and 3.3.1 pass checked native core, reader and analysis fixtures on
i386-win32 and x86_64-win64. Explicit sample values cover unsigned PCM8,
12-in-16 / 20-in-24 / 24-in-32 signed precision, full PCM32 and float headroom.
RIFF/RF64, data-before-format, short reads and exact seeks pass. Malformed
extension lengths, GUIDs, precision, unsupported masks/channels and deferred
padding/NaN/Infinity failures reject without partial sample publication.

The fixture can write four extensible encodings of a PCM16 input:

```text
pythian.tests.wave.read INPUT_PCM16.wav OUTPUT_PREFIX
pythian.tests.analysis.wave REFERENCE.wav CANDIDATE.wav
```

The authored 67032-frame stereo source is encoded as PCM16, 16-in-24, 16-in-32
and float32. Every feature matches the original recording. The actual learner's
66 observations produce the same 16-token / 22-state model; the WFC example's
64-grain reconstruction and the 137-frame-block PCM16 transcode retain exact
reference bytes. All four encodings pass on all four compiler/target combinations.
Parity is within each target; independently computed floating-point results are
not claimed universally identical across targets. These are controlled encoding
checks, not a broad survey of external exporters.

Logs are under `build/extensible-{stable,trunk}-{win32,win64}/`. The ordinary
maintained build now checks feature/model equivalence for all four encodings of
its synthesis recording. That exact new block passes on stable Win32 with 348
observations / 36 states (`maintained-block.log`). The subsequent complete stable
Win32 build also passes with extensible input and source-phase integration
(`build/phase-full-stable-status.log`). Remote CI execution remains unverified.
Refreshed core/WFC packages compile all units
and run all consumers. The extracted WFC consumer also reproduces the four
extensible reconstructions (`build/extensible-package-check.log`).

## Failure and sample validation

Construction establishes container structure and format, not the validity of
every float sample. NaN/Infinity encodings reject when their block is requested,
before those samples are converted or published. Seeking past unrequested data
does not validate it.

Argument errors (such as zero/oversized block counts or out-of-range frame
seeks) preserve a healthy reader. Once I/O, a source callback or sample decoding
fails during a read/seek, the reader becomes failed and refuses later calls.
The original source exception is retained. The last confirmed logical frame
position and a caller's previously assigned sample array remain unchanged.
The underlying stream may have partially advanced; physical rollback is not
promised. Reopen/reposition the stream and construct a new reader for recovery.
A failed constructor can also leave the borrowed stream position changed.

Callbacks from a source cannot reenter ReadFrames or SeekFrame. The public
properties are observational; they do not expose mutable decoder state.

## Existing loading functions

`DecodeWave` and `LoadWave` now share this parser and sample conversion.
Byte-array decoding uses a read-only retained view of the input array, avoiding
an additional encoded-data copy. Its existing 256000044-byte input cap remains.

File loading reads sample blocks directly, avoiding the old temporary buffer
holding the entire encoded file. Both convenience functions still build a whole
`TAudioClip` and enforce its 64-million-scalar-sample budget before allocation.
They validate every decoded sample because they read the entire audio payload.
Use the frame reader directly for longer recordings.

This provides a bounded input primitive, not an unbounded learner. Current
corpus/source tools retain their own byte, clip, analysis and observation limits.
ACID loop metadata reading remains a separate bounded RIFF-only API.

## Native tool and evidence

`pythian.wave.transcode INPUT.wav OUTPUT.wav [BLOCK_FRAMES]` reads bounded
blocks and writes through the existing sequential PCM16 RIFF/RF64 writer.
Default block size is 4096 frames. Sample rate, channel count and frame extent
are retained; PCM16 quantization/clipping applies and metadata is not copied.
Container/argument validation happens before opening the output. A later source,
sample or sink failure can leave partial output; replacement is not atomic.

Checked FPC 3.2.2 and 3.3.1 i386-win32 builds use no vendor paths.
Artifacts/logs are under `build/wave-read-{stable,trunk}/`.
The core fixture still passes its original RIFF/PCM/float/malformed-input
expectations, and the existing streaming writer fixture passes.

The focused reader fixture checks short source reads, irregular output blocks,
EOF and frame seeks, original I/O exception preservation, reentrancy, deferred
nonfinite rejection, RF64 size-table/padding and size-field precedence.
A virtual stream uses an actual writer header for 2147483651 stereo frames
(8589934684 bytes), then reads the final frame beyond 4 GB. Only 84 bytes are
read in that check. This proves address/count handling, not complete physical
multi-gigabyte file playback.

The native transcode path processes both attributable recorded fixtures:
Pixel Sprinter (1512000 stereo float32 source frames) and Opening Theme
(3969000 stereo PCM16 source frames), both at 44100 Hz. Outputs match between
compilers and match the retained earlier decoder executable's same-rate
conversion byte-for-byte. Pixel output is also identical for 137- and
65536-frame requests. Binary provenance, timestamps and SHA256 are recorded
in `build/wave-read-stable/earlier-converter.log`;
direct comparisons/hashes are in `build/wave-read-replay.log`.

| PCM16 output | SHA256 |
| --- | --- |
| Pixel Sprinter | `28273e636b2f250c0c1931d040e5d3355783254a77662aaffcec9deea12b83ae` |
| Opening Theme | `b7c00845ac8ca50761e5f7bf87c1f53f6737e97efbcbc50f354c7928294dfcba` |

The normal build includes the reader fixture and a canonical PCM16 transcode
smoke. Current source counts are 56 core units and 16 WFC adapters. Existing
package archives predate this reader; this is not a new full-suite or
extracted-package checkpoint.
