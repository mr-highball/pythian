# Phanes reference removal audit

[Home](../README.md) · [Inventory](PROVENANCE.md) ·
[Source dispositions](PRECURSOR-BOUNDARIES.md) · [Work](WORK.md)

Completed on 2026-09-14 for Phanes revision
`21cbefee1de7c41c468751246354f846711e07c8`. WFC remains the pinned companion at
`47fa3d8cb8f0f72bf53943eb5eb79758c8f22ce4`; Athena remains the standards submodule.

| Removal condition | Evidence inspected |
| --- | --- |
| Complete audio/music inventory | Named WFC music/MIDI units and Phanes audio/music/corpus helpers have extracted, companion or application dispositions in the provenance and boundary records. The final six WFC support units and complete Phanes MIDI helper are reconciled. |
| Preserve intended behavior and deliberate differences | Native oscillator, clock, note, renderer, MIDI, scheduler and tonal evidence remains linked from provenance. Native Web Audio differences are explicit. Actual companion finite-pipeline fixtures additionally pass 48 and 99 checks on each installed compiler. |
| Standalone native and WFC consumers | Fresh core ZIP compiles all 52 native units; WFC ZIP compiles those plus 12 adapters. Both run all delivered examples on FPC 3.2.2 and 3.3.1 i386-win32 with identical MIDI/WAV artifacts. All project search paths point inside the extracted packages, which exclude Phanes. |
| Expanded WAV learning/listening | The external stable pulse consumer admits the recorded source/archive, learns 36 joint tokens and 71 WFC states from 79 intervals, and verifies all 1207932 stereo frames. WAV, JSON and model match previous recorded-music artifacts exactly. Earlier packaged onset audition retains its documented scope. |
| Latest frame audio/MIDI consumer | External chord MIDI fixture compares complete bytes/plans with actual WFC. Independent voices verifies all preview PCM, all 88 exported note gates and complete full-score MIDI bytes. Stereo WAV, preview, MIDI and JSON all match current checkout artifacts. |
| Retain notices and provenance | ZIP inspection finds complete applicable MIT notices in every delivered owned unit/example, matching current source, plus the WFC license/revision. Phanes is MIT 2026 mr-highball; its applicable notice remains in derived owned source and the root license. Root and packaged provenance retain source URL and exact revision. |
| Preserve final reference-only regression | Immediately before removal, actual Phanes `ExtractSamples` and native tonal selection agree on all 32 existing transposed/mixed-duration fixtures. Captured root/mode pairs now live in the ordinary native tonal fixture, which passes on both compilers without Phanes imports. |

Fresh artifacts are `build/package-complete-core/pythian-source.zip` (59 files)
and `build/package-complete-wfc/pythian-source.zip` (170 files). Each package has
`consumer-check/` and `consumer-development/` build/run evidence; development
`replay-final.log` compares all included output files. The WFC package's
`consumer-audio/` contains the external chord MIDI, pulse and voice consumers.
These consumer sources are verification inputs, not ZIP contents.

`build/removal-audit/package-inventory.log` records current-source and full-notice
inspection. `consumer-replay.log` records pulse/voice byte comparisons.
`tonal-reference-{build,run}.log` records the actual precursor comparison and all
32 captured pairs. `tonal-{stable,trunk}-{build,run}.log` records the replacement
native regression. Existing source/PCM comparison logs retain their original
scope; this audit does not claim browser execution or other OS/CPU support.

The Phanes worktree was deinitialized and its gitlink and `.gitmodules` stanza
removed. Git's retained local submodule object cache was left intact; it is not
part of the delivered source or a clean checkout. Remaining submodule pins match
the revisions above, and their worktrees are unchanged. No user music, owned
library implementation or retained provenance was removed. The reference-only
tonal comparison is now a standalone captured-result regression.

After removal, the normal `tools/build.ps1` run completed on FPC 3.2.2 i386-win32
with native/WFC fixtures and all standard operator smoke workflows, including
the current chord-MIDI and independent-voice paths. Log:
`build/removal-audit/post-removal-build.log`. No owned compiler warnings or
remaining Phanes unit references were found. Existing companion/FCL warnings
remain. No full development-compiler suite was repeated; its current coverage is
the complete package compilation/examples and focused regression described above.

This gate is narrower than the full project goal. Further synthesis controls,
WAV musical structure/accuracy, semantic styles and clean Git/CI delivery remain
tracked in the work record; removing the reference does not mark them complete.
