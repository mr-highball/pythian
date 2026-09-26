# Source provenance

Pythian is MIT licensed, copyright 2026 mr-highball. Units derived from WFC retain
its 2021 notice as well. Every source file carries its complete applicable notice.

Precursor sources reviewed for the extraction:

- WFC: https://github.com/mr-highball/wfc at
  `47fa3d8cb8f0f72bf53943eb5eb79758c8f22ce4`.
- Phanes: https://github.com/mr-highball/Phanes at
  `21cbefee1de7c41c468751246354f846711e07c8`.

Extracted mechanisms include PCM/codec conventions, exact tempo clocks, the
fixed-point triangle oscillator, seeded noise, note projection, ordered note
export, two-pass MIDI transport and synthesis
control. Native DSP, WAV analysis and reconstruction extend those mechanisms.
WFC remains an optional companion; its learner and solver are used directly.
When included, its source license and exact revision accompany it in `vendor/wfc`.

Phanes's browser application, corpus, style identities and assets are excluded.
Native DSP and ADSR behavior do not claim Web Audio or all precursor PCM parity.
The example phrases are authored in Pythian and include no external music.
The instrument example uses native oscillator voices and explicit keyboard/velocity
zones. The saved-event example applies the existing native measurements and real
WFC learner to caller-supplied WAVs, preserving independent source runs; package
verification supplies only the two authored native example WAVs.

The packaged journal operator combines native bounded analysis, source-bound
feature storage and the actual WFC learner. Its section/blend/replay check uses
only the core example's authored WAV. Journal ranges, deterministic palettes,
coverage diagnostics, counted learning, saved lineage and source-context reuse
are Pythian coordination code; no additional music assets or external learner
implementation are bundled. The maintained pulse fitter uses project-owned
phase-concentration measurements with explicit metrical uncertainty. Stationary
harmonic fitting uses native streaming Givens QR, informed by Julius O. Smith's
[Sinusoidal Amplitude and Phase Estimation](https://www.dsprelated.com/freebooks/sasp/Sinusoidal_Amplitude_Phase_Estimation.html),
without copying an external implementation.

Bounded WAV analysis and stream hashing reuse existing native algorithms.
Stereo reverb uses standard damped comb and Schroeder allpass structures with
new Pythian code and parameters; no external effect implementation is copied.
The processing example composes these library units over caller-supplied audio.
Context bundles/profiles retain admitted labels, actual WFC models and complete
selection ancestry; they do not establish automatic WAV musical inference.

Current style profiles retain onset, optional pitch/dynamics/duration evidence
and weighted repeated derivations. WFC adapters retain actual learned models and
explicit provider scopes; the core remains independent of those companion types.
Global pulse candidates reuse native spectral flux and project-owned bounded
autocorrelation. That approach is informed by Daniel P. W. Ellis's
[Beat Tracking by Dynamic Programming](https://www.ee.columbia.edu/~dpwe/pubs/Ellis07-beattrack.pdf),
without copying its implementation or claiming automatic musical pulse selection.

The native SHA256 implementation follows the algorithm in
[FIPS 180-4](https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.180-4.pdf), retaining
the extracted exact-byte provenance contract without a development-only FCL unit.

Extensible WAV input is new native code following Microsoft's
[format definition](https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/ksmedia/ns-ksmedia-waveformatextensible)
and [subtype GUID mapping](https://learn.microsoft.com/en-us/windows-hardware/drivers/audio/converting-between-format-tags-and-subformat-guids).
It shares the bounded RIFF/RF64 reader and original PCM/float sample scaling;
no platform decoder or external implementation is copied.

The shared Fourier primitive extracts Pythian's existing radix-two analysis
engine and adds inverse scaling and explicit result ownership. Native
harmonic/percussive separation is informed by Derry FitzGerald's
[Harmonic/Percussive Separation using Median Filtering, DAFx 2010](https://dafx.de/paper-archive/2010/DAFx10/DerryFitzGerald_DAFx10_P15.pdf).
No external implementation is copied. Linked stereo masks, edge handling and
bounded reconstruction are project code. The source package includes no external
music, separated recordings or claims of isolated voice/instrument inference.
