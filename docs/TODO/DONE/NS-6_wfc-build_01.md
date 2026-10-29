# NS-6_wfc-build_01 — Qualify WFC native conformance within its build budget

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-6)

**Description:**

Resolve the demonstrated upstream qualification prerequisite for
[observed model cloning20](../NS-6_observability_20.md). WFC CI57's macOS job
exhausted its30-minute limit twice. Its shell build forces65 complete unit
rebuilds across consumers. The first timeout ends during compilation; the
second build log is truncated by GitHub's viewer. These are failed engineering
gates, not scientific rejections or proof that a conformance assertion failed.

North star: NS-6. Outcome owner: REUSABLE-OPERATIONS. Completion credit: 0 additional.
WFC owns its generic build orchestration. Keep Pythian's accepted pin and held
clone work intact; no vendor-source patch or upstream merge belongs here.

Completed 2026-10-29 at exact WFC d4d30b120ee6ac6741387b206d971bb2877896aa.
[CI58](https://github.com/mr-highball/wfc/actions/runs/40974532515) passes all
five required jobs: Linux 7m12s, macOS 11m38s, Windows 12m47s, pas2js with actual
browser conformance 12m42s, and development FPC 7m48s. Total duration 12m51s.
All original criteria below are satisfied. Downstream adoption remains clone20.

Criterion: complete unchanged upstream conformance inside its existing budget.
Deliverable: one fresh native unit cache per shell-build invocation, reused by
all its checked consumer compilations. Evidence: real native cross-consumer
reuse/unchanged results, complete command/test inventory and all five upstream
CI jobs. Stop on incompatible compiler profiles, unit-name collisions, skipped
checks, another required gap or failure of the unchanged budget. No repeated
same-source retry or timeout expansion is the repair.

**Acceptance Criteria:**

- Preserve both original timeout jobs and the original source; inspect the
  separate WFC checkout/branches for an existing fix. Notify the user and use
  a new branch from the reviewed clone revision before editing upstream source.
- Reuse FPC's primary unit mechanism without a new compiler or parser. Each
  invocation starts with a fresh isolated unit directory; caller flags/targets,
  source search paths, all programs, runtime assertions, package/inventory
  checks, failure propagation and the30-minute CI limit remain intact.
- Exercise actual checked native32/64 cross-consumer compilation and execution
  in fresh caches. Show shared units are compiled initially and reused later;
  preserve exact conformance and cancellation checks. Validate shell syntax and
  compare the complete compiler/program/runtime command inventory with the
  predecessor. No fixture listener needs a new local executable path.
- Pass all five upstream jobs, including complete macOS native conformance,
  inventories/packages and actual browser tests at the exact new revision.
  Then update linked tasks/accounting together. Downstream pin adoption and
  musical acceptance remain clone20 and their original owners' requirements.

**Blockers**

- No implementation blocker. Full upstream qualification remains required.

**Dev Notes:**

- 2026-10-29, Big Boss SOLO: exact CI58 is terminal SUCCESS for all five jobs.
  Native32/64 cache identity and unchanged conformance, shell syntax and complete
  command parity qualify alongside the full upstream run. The original src,
  test and workflow trees are unchanged from 5d69462; the 30-minute limit stays.
  Preserve both CI57 timeout attempts. Counts 55 open/95 DONE become 54 open/
  96 DONE, total 150; NS-6 has 16 open. Completion 52.45/47.55 and delivery
  nonclosing 0 remain. No musical credit, upstream merge or live deployment.

- Big Boss: upstream branch is clean/pushed at
  [d4d30b120ee6ac6741387b206d971bb2877896aa](https://github.com/mr-highball/wfc/commit/d4d30b120ee6ac6741387b206d971bb2877896aa).
  Only build.sh and its two existing build guides change. Bash syntax passes;
  reversing the reviewed fresh-cache setup and65 forced-B removals reproduces
  every original compiler/program/runtime command exactly. No workflow/budget,
  Pascal implementation or test source changes. Actual checked native32/64
  compile the original sequence consumer, then the complete learning/clone
  consumer in the same fresh cache without rebuilding the primary sequence
  unit: its PPU hash and modification time remain unchanged. Both execute120
  original checks and788662 learning/clone checks, including28 original learning
  aborts and318 clone aborts, with clean focused native heaps. Full
  [CI58](https://github.com/mr-highball/wfc/actions/runs/40974532515) is confirmed
  live at exactd4d30b1; all five jobs remain required. No acceptance or pin change
  follows from these focused checks. Private E-drive wfc-native-build packet
  retains command parity, compiler logs and cache identity records.
- 2026-10-29, Big Boss SOLO: WFC5d69462/CI57 attempt1 job123765406828 stops
  at30m21s near build log65644 during primary unit compilation. One unchanged
  macOS-only attempt2, job123781105247, is now terminal CANCELLED30m20s, with
  the job-limit annotation and canceled build line70451. Other four jobs pass.
  No third retry is selected. First accepted predecessor's macOS run took24m31s.
  GitHub truncates the second inline build log; attempted raw-log download
  stalled its tab. A fresh tab in the same authenticated browser restores
  inspection; no browser, security, credential or firewall settings change.
- Separate primary WFC expansion85d19fe and its native-build/cache branch search
  show no existing fix: it also has65 forced rebuilds. The selected reviewed
  clone tree has191 Pascal unit files across source/tools/tests/examples,
  no duplicate basenames and no per-consumer command defines. Existing common
  strict flags/search paths are retained. Branch
  `codex/pythian-native-build-reuse` is selected from5d69462; notice precedes
  source edits. Preserve both upstream checkouts and Pythian's dirty clone work.
  Counts55open/95DONE/150 total, NS6 17open;52.45/47.55 unchanged. Delivery
  nonclosing0 remains while this required batch is in progress; no musical credit.
