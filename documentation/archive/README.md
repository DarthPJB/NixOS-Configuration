# documentation/archive/

Historical material, preserved as record and **not** active guidance.
Do not follow archived documents as operational procedure unless an active
document explicitly points here.

| Item | What it was | Why archived (2026-10-05) |
|---|---|---|
| `vllm-migration-plan.md` | vLLM-only migration plan | Executed AND reversed; status header said "Ready for execution" — actively misleading. Live stack is Ollama + LiteLLM (see `../ai-stack.md`). |
| `vllm-architecture.md` | vLLM implementation record | Historical record of the reversed vLLM-only migration. |
| `vllm-cpu-fix.md` | `pkgs/vllm-cpu` wrapper fix record | Detail of an undeployed engine; reference-only for a possible vLLM revival. |
| `ai-upgrades.md` | vLLM-only upgrade problem record | Superseded by the Ollama-primary stack. |
| `x86-bootstrap-deployment-workflow.md` | x86 assimilation guide | Superseded by `../assimilator-deployment-workflow.md`; its Stage 3 host-key practice is **architecturally void** (see that document §1). |
| `ci-build-metrics-2026-08/` | CI measurement snapshot (2026-08-03) | Dated data + analysis; retained as the CI-performance baseline. Regenerate a new snapshot for current metrics — never edit this one. |

Archived: 2026-10-05, as part of the documentation QA review
(`../LDR-001-fleet-spec-and-boundaries.md`).
