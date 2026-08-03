---
description: Fixture adapter referencing every core phase and flow except one, to exercise the negative case of checks/adapters-cover-core.sh.
---
Follow `${CLAUDE_PLUGIN_ROOT}/core/flows/task.md`.
Follow `${CLAUDE_PLUGIN_ROOT}/core/flows/review.md`.
Follow `${CLAUDE_PLUGIN_ROOT}/core/flows/resume.md`.
Follow `${CLAUDE_PLUGIN_ROOT}/core/flows/init.md`.
Follow `${CLAUDE_PLUGIN_ROOT}/core/flows/conventions.md`.
Follow `${CLAUDE_PLUGIN_ROOT}/core/phases/pipeline.md`.
Follow `${CLAUDE_PLUGIN_ROOT}/core/phases/test.md`.
Follow `${CLAUDE_PLUGIN_ROOT}/core/phases/execute.md`.
Follow `${CLAUDE_PLUGIN_ROOT}/core/phases/code-review.md`.
Follow `${CLAUDE_PLUGIN_ROOT}/core/phases/end.md`.

One flow file under core/flows/ is deliberately left with no adapter here —
this fixture exists to prove `checks/adapters-cover-core.sh` catches exactly
that kind of gap.
