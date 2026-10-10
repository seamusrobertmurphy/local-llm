# local-llm

Settled decisions for this repository, recorded 20 September 2026. Read this before
proposing anything, because every choice below was made and closed in the scoping session
of that date.

## The goal

Seamus, 20 September 2026, verbatim: "I want build local llm for free use". Everything here
runs on hardware he owns, under a licence that costs nothing, with no account, no API key and
no per-token billing. A hosted API is not an answer to any question in this repository.
Jev, `api.typesafe.ai`, was scoped and rejected on exactly that ground.

## The machine

An HP laptop running Ubuntu, 32 GB of RAM, 1 TB free on its SSD. Whether that SSD is NVMe or
SATA is still unconfirmed and sets the token rate, because the experts are read from storage on
every token. The Mac this repository sits on has 8 GB and is under memory pressure, so
footprint matters for anything installed here.

## The engine

Colibri, `JustVugg/colibri`, Apache 2.0, release v1.12.0. A single C file that holds the dense
weights resident in RAM and streams the routed experts from disk, so a model far larger than
memory runs at the cost of speed rather than not at all. Python is used only by the launcher,
the one-time converter and the optional API gateway.

## The model

DeepSeek V4.1 Flash, 552B parameters, 510 GB, MIT licence, ungated. Chosen 20 September 2026
after Seamus said, verbatim, "No i want the full large model", having been offered the
85 GB REAP-pruned DeepSeek and the 372 GB GLM-5.2.

It reads 4.5 GB of experts per token against GLM-5.2's 12.7, so on a disk-bound machine it is
both larger and faster than the model it was compared with. No conversion step, because its
dense weights are already fp8 and its experts already fp4. Vision, tool calling and the DSpark
draft head are on.

The install is in `colibri-runbook.md`. Do not re-scope the model choice.

## The harness

Claude Code stays the daily driver. Colibri's gateway serves the Anthropic protocol at
`/v1/messages` on the same port as the OpenAI one, so Claude Code reaches the local model with
three environment variables and no migration at all.

OpenCode, `anomalyco/opencode`, is the chosen second harness, because it is the only one that
reads `~/.claude/CLAUDE.md`, the 59 skills and the 57 portable memory rules from where they
already sit. Note that `opencode-ai/opencode` is a different, archived repository that moved to
Crush; it is not this project.

Rejected, with reasons, in `harness-plan.md`. Codex cannot reach colibri because its `wire_api`
takes only OpenAI's Responses API. pi and LazyPi have no hook subsystem. jcode inherits only
MCP servers, but earns a place on the Ubuntu box at 27.8 MB per session.

## House style

The global rules in `~/.claude/CLAUDE.md` apply here in full. One correction was given in this
repository on 20 September 2026 and is now in portable memory as
`give-the-steps-not-the-limits`. Seamus, verbatim, "dont tell me what are the limits, tell me
how to do this". A how-to question is answered with the commands that do it, and a constraint
gets a clause inside a step rather than a section before them.

## Files here

| file | what it is |
|---|---|
| `colibri-runbook.md` | the six-step install for DeepSeek V4.1 Flash on Ubuntu |
| `colibri-scoping.md` | the background reading behind the model choice |
| `harness-plan.md` | Claude Code against omp, jcode, pi, LazyPi, Codex and OpenCode, with the export path for each |
| `flatten-rules.sh` | builds one `AGENTS.md` from `~/.claude/CLAUDE.md` plus the 57 memory rules |
| `install-checklist.md` | what to do next week, in order |
