# Working in Pythian

Read [the project profile](PROJECT.md) and the relevant standards in
[Athena](vendor/athena/README.md#standards-map). Start with its
[principles](vendor/athena/docs/principles.md),
[coding conventions](vendor/athena/docs/coding-standards.md), and
[impact-based validation](vendor/athena/docs/validation.md).

- Root owned Pascal units at `pythian`; keep the portable library independent
  of WFC, Phanes, browser APIs, engines, and playback devices.
- Use Pascal for implementation, analysis, codecs, and maintained tools.
  Scripts orchestrate builds only. Use existing verified toolchains.
- WFC is a retained companion submodule. Put its contracts in `adapters/wfc/`.
  Phanes was removed after its extraction audit; preserve its recorded provenance
  and derived notices. Do not edit dependency source in this checkout.
- Follow [Lean stewardship](vendor/athena/docs/agent-stewardship.md), with one
  primary agent and no delegation unless explicitly authorized.
- Preserve complete license notices and record precursor provenance.
- Keep generated files under ignored `build/`. Validate meaningful boundaries,
  deterministic replay, and the changed listening path without redundant suites.
- Read [the work record](docs/WORK.md) before resuming implementation.
- Follow [task flow](docs/TASKFLOW.MD) and the linked [task catalog](docs/TODO/README.md)
  for task selection, discovered gaps, completion moves and milestone accounting.
