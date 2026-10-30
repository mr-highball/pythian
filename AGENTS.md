# Working in Pythian

Read [the current goal](docs/GOAL.md), [implementation assessment](docs/ASSESSMENT-2026-10-29.md),
[project profile](PROJECT.md) and relevant [Athena standards](vendor/athena/README.md#standards-map).
Start with [principles](vendor/athena/docs/principles.md),
[coding conventions](vendor/athena/docs/coding-standards.md) and
[impact-based validation](vendor/athena/docs/validation.md).

- Prioritize real instrumental synthesis through the breadth of the musical WFC
  graph. Studio must let the operator hear bass, drums, harmony and lead, inspect
  actual graph dimensions/passes/constraints, change them and compare results.
  The first delivery order is shared instrumental runtime, explicit percussion,
  then ordinary Studio jobs. Reuse the working instruments and musical adapters.
- Source recordings teach or provide reference. Do not select further full-mix
  grain reconstruction, microclip labeling or acoustic join experiments as a
  proxy for instrumental progress. Preserve their historical evidence and answers.
- Studio is the experimental proving ground. Authored, MIDI, operator-supplied
  and uncertain recording-derived proposals may bootstrap instrumental generation.
  Mark uncertain capabilities Experimental, expose correction/override, and retain
  actual origins. Independent inference benchmarks, fixed corpus floors and
  external-adoption dossiers are not entry gates. Never invent accuracy or
  misrepresent authored settings as learned musical knowledge.
- Root owned Pascal units at `pythian`; keep the portable library independent of
  WFC, Phanes, browser APIs, engines and playback devices.
- Consolidate shared algorithms/contracts into the primary library. Native,
  pas2js and future WASM consumers reuse it; adapters own platform I/O and
  presentation. Remove inferior duplicates rather than preserving compatibility.
- Use Pascal for implementation, analysis, inference, codecs and maintained
  tools. Scripts orchestrate builds only. Use verified existing toolchains.
  Do not execute TensorFlow, ONNX, HDF5 or third-party inference runtimes.
- WFC is integral to the full product while core-only use stays independent.
  Its contracts belong in `adapters/wfc/`; audio/musical adaptation stays here.
  Do not edit dependency source in this checkout. For a demonstrated generic
  WFC gap, use its separate repository and a new branch, tell the user, and follow
  the [cross-repository procedure](docs/TASKFLOW.MD#cross-repository-wfc-gaps).
- Preserve complete license notices and precursor provenance, including removed
  Phanes notices. Keep private recordings, saved operator responses and generated
  artifacts outside source control. Saving feedback must not silently retrain.
- Follow [stewardship](vendor/athena/docs/agent-stewardship.md) under the active
  operator override: **single-agent Big Boss only, from 2026-10-26 until explicitly
  changed**. Do not start, resume or delegate to helpers. Big Boss owns selection,
  architecture, implementation, verification and final judgment. Solo checks are
  not independent review. Inactive team settings are historical, not authorization.
- Read [WORK.md](docs/WORK.md), [task flow](docs/TASKFLOW.MD),
  [active tasks](docs/TODO/README.md) and [milestones](docs/MILESTONES.md) before
  selecting work. The operator explicitly resumed implementation solo after the
  2026-10-29 goal/backlog reset. Follow the instrumental runtime delivery order.
- Tasks use `NS-<goal>_<feature>_<xx>.md` and contain Goal, Effort (integer 1–10),
  Status, Description, Acceptance Criteria, Blockers and a final Dev Notes section.
  Completion is derived from accepted effort divided by current-goal total effort,
  never assigned percentage credits. Additions/reestimates/completion moves update
  task links, index and milestone totals together. Retired work earns nothing.
- Before every batch, state its criterion, concrete deliverable, closing evidence
  and stop condition. After two consecutive nonclosing batches, stop and reassess.
  A new goal, agent, handoff, renamed experiment or task split never resets counts.
  Read the current count in WORK. The reset preserved its inherited count of
  two; the later real runtime closure resets the consecutive count. Required
  distinct gaps get linked tasks before scope expands.
- Validate changed boundaries and actual consumers proportionally. Listening and
  Studio exploration guide musical decisions. Tests/reports alone earn no musical
  acceptance; formal research protocols are not blanket prerequisites to audition.
  Preserve deterministic replay, data integrity, failure evidence and honest limits.
- Work on `hello-pythian` in this repository. On this workstation put new
  build/test/cache/run output under `E:/CodexWork/pythian/` in dedicated
  `build/`, `tests/`, `cache/` and `runs/` folders. Existing repo-local
  `build/` is a real D-drive directory, not a redirection; inspect or add an
  explicit output override before running scripts that hardcode it. Preserve
  historical evidence and fixed service slots; other projects' E folders are unrelated.
- Launch review services only from the fixed executable slots in the
  [LAN procedure](docs/LAN-REVIEW-SERVICE.md), including isolated QA. Keep minimal
  local-use security and reuse existing service/job transport.
- For browser QA use an isolated profile, close its exact process tree afterward,
  and confirm no QA browser or looping audio remains. Documentation-only changes
  need meaning, metadata, link and privacy checks, not a service restart or playback.
