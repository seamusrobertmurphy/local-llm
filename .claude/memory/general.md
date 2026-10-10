# General

Project facts for `local-llm`. One line per fact, dated, naming the artefact it rests on.

- 2026-09-20 Colibri's gateway serves Anthropic's `/v1/messages` alongside `/v1/chat/completions`
  on the same port, so Claude Code reaches the local model with `ANTHROPIC_BASE_URL`,
  `ANTHROPIC_API_KEY` and `ANTHROPIC_MODEL` and nothing else changes. Source `docs/api.md` in
  `JustVugg/colibri`, section "Anthropic-protocol endpoint". This is why no harness migration is
  needed to run DeepSeek locally.
- 2026-09-20 Codex cannot reach colibri. Its `model_providers.<id>.wire_api` accepts only
  `responses`, OpenAI's Responses API, and colibri serves no Responses endpoint. Source the Codex
  configuration reference at `developers.openai.com/codex/config-reference.md`.
- 2026-09-20 Codex caps combined instructions at `project_doc_max_bytes`, default **32 KiB**, and
  stops reading once it is reached. The flattened `AGENTS.md` is 108 KB, so the default silently
  drops two thirds of it. Source `developers.openai.com/codex/guides/agents-md.md`.
- 2026-09-20 OpenCode reads `~/.claude/CLAUDE.md` and `~/.claude/skills/*/SKILL.md` directly, and
  its `instructions` array takes globs, so `["~/.claude/memory/*.md"]` loads the 57 portable rules
  live with no copy to go stale. Source `packages/web/src/content/docs/rules.mdx` and `skills.mdx`
  in `anomalyco/opencode`.
- 2026-09-20 OpenCode removed the Claude Pro/Max plugins at version 1.3.0 because Anthropic
  prohibits them; current release is 1.18.31. The only supported Anthropic route is a metered API
  key. Source `packages/web/src/content/docs/providers.mdx`, the info box under the Anthropic
  setup steps.
- 2026-09-20 `opencode-ai/opencode` is archived, last pushed 2025-09-18, and moved to Crush under
  the Charm team. The live project is `anomalyco/opencode`. Do not confuse them.
- 2026-09-20 `flatten-rules.sh` must strip YAML frontmatter only where it exists. Sixteen of the
  57 files in `~/.claude/memory/` open with a heading instead, and a blind `sed` frontmatter strip
  truncates each of them to one line without erroring.
