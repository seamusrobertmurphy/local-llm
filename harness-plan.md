# Harness plan

Written 20 September 2026. Compares Claude Code against pi, oh-my-pi and jcode, says which
to install, and gives the commands for moving your rules and skills into each one and for
pointing any of them at DeepSeek V4.1 Flash next week.

## The short answer

You do not have to change harness to run DeepSeek locally. Colibri's gateway serves the
**Anthropic protocol** at `/v1/messages` on the same port as the OpenAI one, so Claude Code
connects to it with three environment variables and keeps every skill, rule and hook you have.
`docs/api.md` says so in as many words, "existing clients that speak to Anthropic endpoints,
Claude Code, the Anthropic SDKs, work against colibri without a shim".

If you want a second harness anyway, install **oh-my-pi**, because it is the only one of the
three that reads your existing `.claude` directory on first run with no migration step.

## What you have

Your Claude Code install is not a default one, and that is the thing any comparison has to
price.

| piece | size | travels to another harness? |
|---|---|---|
| `~/.claude/CLAUDE.md` | 36 KB of house style, statistics, memory and scope rules | yes, as a rules file |
| `~/.claude/memory/` | 57 portable rule files plus `index.md` | only if you concatenate them |
| `~/.claude/skills/` | 59 skills, 16 of them symlinked into `library-skills` and `library-audits` | yes, omp and jcode both read skill directories |
| `~/.claude/plugins/` | 77 MB across 5 marketplaces | yes, omp's `claude-plugins` provider reads them |
| hooks in `settings.json` | 10 events wired, including the Kokoro text to speech Stop hook | no |
| output style, effort level, auto mode | `ELI5`, `high`, auto permissions | no |

The first three columns are the ones worth moving. The rest is Claude Code's own plumbing and
has no equivalent elsewhere.

## Claude Code

What it gives you that the others do not. Skills that load on demand rather than sitting in
the prompt, a plugin and marketplace system, hooks on ten lifecycle events, three separate
memory stores with routing rules, output styles, subagents with their own tool sets, and
Artifacts. You have used all of it. The cost is that it is Anthropic's, it is not open source,
and it bills.

## The three alternatives

| | pi | oh-my-pi (omp) | jcode |
|---|---|---|---|
| repo | `earendil-works/pi` | `can1357/oh-my-pi` | `1jehuang/jcode` |
| stars | 107,740 | 32,128 | 19,938 |
| licence | MIT | MIT | MIT |
| written in | TypeScript | TypeScript plus ~80k lines of Rust | Rust |
| what it is | the toolkit omp forked | pi with batteries included | a from-scratch efficiency play |
| RAM, one session | 144.4 MB | not published in this comparison | 27.8 MB, or 167.1 MB with local embedding on |
| permissions | none built in, containerise it yourself | per-tool prompts | per-tool prompts |
| reads your `.claude` | no | yes, on first run | MCP servers only, from `~/.claude.json` |
| local model providers | via `pi-ai` | Ollama, LM Studio, llama.cpp, vLLM, LiteLLM, plus custom | Ollama, LM Studio, vLLM, plus a built-in `deepseek` profile |

Three things decide it.

pi says plainly that it "does not include a built-in permission system for restricting
filesystem, process, network, or credential access" and runs as whatever user launched it.
It also auto-closes issues and pull requests from new contributors. It is the library omp was
built on rather than the thing to install.

omp inherits what is already on disk. Its own words, "on first run omp inherits whatever is
already on disk, rules, skills, and MCP servers from `.claude`, `.cursor`, `.windsurf`,
`.gemini`, `.codex`, `.cline`, `.github/copilot`, and `.vscode`. No migration script." For a
36 KB CLAUDE.md and 59 skills that is the whole migration problem solved.

jcode wins on memory, and your Mac has 8 GB. 27.8 MB against pi's 144.4 MB is a real number on
a machine already under pressure. It also loads skills by embedding similarity rather than all
at once, and ships a `deepseek` provider profile out of the box.

## What to install

Keep Claude Code as the daily driver. Install **omp** next, on the Mac, because it picks up
your rules and skills for free. Put **jcode** on the Ubuntu box beside colibri, where its
27.8 MB footprint and its built-in local provider profiles do the most good. Skip pi itself.

```sh
# omp, on the Mac
brew install can1357/tap/omp
omp setup

# jcode, on the Ubuntu box
curl -fsSL https://jcode.sh/install | bash
```

## Capture this session

One rule from today is already written. `~/.claude/memory/give-the-steps-not-the-limits.md`,
indexed in `~/.claude/memory/index.md`, records that a how-to question is answered with the
commands and a constraint gets a clause inside a step rather than a section before them.

Four more are worth writing, and each has one right home.

1. **Free and local only.** Goes in `~/.claude/memory/` as a `user` fact, because it decides
   model choice in every repository, not just this one.
2. **Jev is a paid API, not a local model.** Goes in `~/.claude/memory/` as a `reference` fact,
   naming `https://api.typesafe.ai/v1/systemone` and the Choice, Score and Noul question types,
   so the next session does not scope it again as a local option.
3. **Colibri speaks the Anthropic protocol.** Goes in this repository's `.claude/memory/`,
   because it is a fact about this project. It is the reason no harness change is needed.
4. **Ternary quantisation exists and works.** Goes in `~/.claude/memory/` as a `reference` fact.
   Bonsai 2 27B at 1.72 bits per weight puts a 27B model in 5.95 GB, and the PrismML llama.cpp
   fork is required because stock llama.cpp loads the file and produces garbage without warning.

Run `/promote-rule` on each, or say the word and I will write all four.

## Export to omp

Nothing to do for the rules and skills. Point omp at the directory and it reads them.

```sh
cd /Volumes/PortableSSD/Github/local-llm
omp setup
omp /reload-plugins
```

The one thing that does not come across is your 57 portable memory files, because they live in
`~/.claude/memory/` rather than in a rules file any harness looks for. Flatten them into an
`AGENTS.md`, which omp, jcode and Codex all read.

```sh
./flatten-rules.sh                 # writes ~/.omp/agent/AGENTS.md
./flatten-rules.sh ~/AGENTS.md     # or anywhere else
```

`~/.omp/agent/AGENTS.md` is omp's user-scope context file, read at the start of every
session in every directory. The script strips YAML frontmatter only where a file actually
has it, because 16 of the 57 memory files open with a heading instead and a blind
frontmatter strip truncates each of them to one line.

That `sed` drops the YAML frontmatter and keeps the rule text. Copy `~/AGENTS.md` into any
repository you want the rules to apply in, or keep one at your home directory for the global
set.

## Export to jcode

jcode reads MCP servers from `~/.claude.json` already. Skills go in its own directory and are
injected by embedding similarity rather than loaded up front.

```sh
mkdir -p ~/.jcode/skills
cp -RL ~/.claude/skills/. ~/.jcode/skills/
cp ~/AGENTS.md .
```

`cp -RL` follows the 16 symlinks into `library-skills` and `library-audits` and copies the real
directories, which is what you want on a second machine that does not have those repositories
checked out.

## Export to DeepSeek

There is nothing to export into DeepSeek, because DeepSeek is the model and not the harness.
Whichever harness you run sends its own system prompt, rules and tool catalogue over the wire.
All you configure is the address of the local server.

Start colibri's gateway on the Ubuntu box.

```bash
COLI_MODEL=~/Models/DeepSeek-V4.1-Flash \
  ./coli serve --host 127.0.0.1 --port 8000 --model-id deepseek-v41-flash
```

Smoke-test it before wiring anything to it.

```bash
curl http://127.0.0.1:8000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"deepseek-v41-flash","messages":[{"role":"user","content":"hi"}]}'
```

Then point each harness at it.

**Claude Code**, through the Anthropic endpoint on the same port.

```bash
export ANTHROPIC_BASE_URL=http://localhost:8000
export ANTHROPIC_API_KEY=local
export ANTHROPIC_MODEL=deepseek-v41-flash
claude
```

The key is only checked if you set `COLI_API_KEY`, but the client refuses to start without
some value. Expect a long silent wait on the first token, because Claude Code's system prompt
and tool catalogue are large and every one of those prompt tokens is prefilled against experts
streamed off the SSD.

**omp**, by declaring a custom provider in `~/.omp/agent/models.yml`.

```yaml
providers:
  colibri:
    baseUrl: http://127.0.0.1:8000/v1
    api: openai-completions
    apiKey: local
    models:
      - id: deepseek-v41-flash
        name: DeepSeek V4.1 Flash
        contextWindow: 128000
```

Then set it as the default role in `~/.omp/agent/config.yml`.

```yaml
modelRoles:
  default: colibri/deepseek-v41-flash
```

Verify with `omp models colibri`.

**jcode**, in one command.

```bash
jcode provider add colibri \
  --base-url http://127.0.0.1:8000/v1 \
  --model deepseek-v41-flash \
  --no-api-key \
  --context-window 128000 \
  --set-default

jcode --provider-profile colibri auth-test --prompt 'Reply exactly JCODE_PROVIDER_SETUP_OK'
```

Raise `JCODE_STREAM_IDLE_TIMEOUT_SECS` above its 180 second default on this path, because the
model thinks before it emits and the experts come off disk while it does.

Tool calling works on the DeepSeek engine over both protocols, through its native DSML parser.

## Porting the hooks

Added 20 September 2026 after reading omp's `docs/hooks.md`. The port is small, because
`pi.exec(...)` runs a shell command from inside a hook. Your four scripts do not change at
all. Only the wrapper around them is new.

An omp hook is a TypeScript file that default-exports a factory and registers handlers with
`pi.on(...)`. Six of your ten Claude Code events map straight across.

| Claude Code | omp event |
|---|---|
| `SessionStart` | `session_start` |
| `SessionEnd` | `session_shutdown` |
| `UserPromptSubmit` | `turn_start` |
| `PreToolUse` | `tool_call` |
| `PostToolUse` | `tool_result` |
| `Stop` | `agent_end` |
| `SubagentStop` | `agent_end`, fired per agent, so filter on the context |
| `StopFailure` | no event; `auto_retry_start` is the nearest |
| `Notification` | no event |
| `PermissionRequest` | no event; `tool_call` is the interception point |

The whole port is one file at `~/.omp/agent/hooks/post/claude-hooks.ts`.

```ts
import type { HookAPI } from "@oh-my-pi/pi-coding-agent/extensibility/hooks";

const STATUS = "/Users/seamus/.config/iterm2/cc-status";

export default function hook(pi: HookAPI): void {
  for (const e of ["session_start", "session_shutdown", "turn_start",
                   "tool_call", "tool_result", "agent_end"] as const) {
    pi.on(e, async () => { await pi.exec(STATUS); });
  }
  pi.on("agent_end", async () => {
    await pi.exec("bash /Users/seamus/.claude/tts_hook.sh");
    await pi.exec("bash /Users/seamus/.claude/hooks/spock-clip.sh");
  });
}
```

One trap. The native provider scans `hooks/pre/` and `hooks/post/` only. A factory placed
directly in `hooks/` loads nothing and reports no error, so the file must sit in one of those
two subdirectories.

The Kokoro text to speech hook needs one change beyond the move. Claude Code's `Stop` hook
reads the assistant's reply from the transcript, and omp's `agent_end` hands you a different
shape, so `tts_hook.sh` has to be given the text rather than finding it itself.

## LazyPi

LazyPi is not a harness. It is an installer, `robzolkos/lazypi`, 455 stars, MIT, created
18 April 2026, and what it installs is pi plus 25 curated pi packages. One command,
`npx @robzolkos/lazypi`, needing Node 22.19 or later. It is to pi roughly what oh-my-zsh is
to zsh.

The catalog is worth knowing, because it is a fair picture of what pi lacks out of the box.
Core: `pi-subagents`, `pi-ask-user`, `pi-mcp-adapter`, `pi-web-access`, `pi-memory-md` for
markdown-backed memory, `@devkade/pi-plan`, `pi-simplify`, `pi-add-dir`,
`pi-prompt-template-model`, and `@saccolabs/pi-claude-cli`, which lets pi use your Claude Code
CLI authentication as a model provider. Interface: plannotator, slopchop for diff review,
powerbar, a usage and cost dashboard, raw paste, a todo widget, a side-chat popover, and
interactive shell overlays. Research: an autonomous experiment loop and the Ralph Wiggum
iterative dev loop. Plus Compound Engineering and three theme packs.

It does not change the ranking, because underneath it is still pi, and pi does not discover
your `.claude` directory the way omp does. What it does change is how much work pi is to set
up, from a day to one command.

### Migrating to pi or LazyPi

Two settings, and pi reads everything you have.

```sh
./flatten-rules.sh ~/.pi/agent/AGENTS.md
```

pi loads `AGENTS.md` or `CLAUDE.md` at startup, and `~/.pi/agent/AGENTS.md` is its global
slot, so that one command carries your house style and all 57 rules.

Then point it at your skills, in `~/.pi/agent/settings.json`.

```json
{
  "skills": ["~/.claude/skills", "~/.codex/skills"]
}
```

pi implements the Agent Skills standard and documents this exact case, reading Claude Code and
Codex skill directories directly. It is deliberately lenient about a skill's name differing
from its parent directory, which it calls suboptimal for directories shared across harnesses,
so your 59 skills load without renaming.

What does not come across is the same list as before, plus one. Your plugins, because pi has no
equivalent of omp's `claude-plugins` provider. Your hooks, because pi has no hook subsystem at
all; that is what omp added when it forked. And `pi-memory-md` is a different memory model from
your three stores, so the flattened `AGENTS.md` is doing that work instead.

### Which of the two

omp, still. It reads `~/.claude/CLAUDE.md`, your skills and your plugins with no configuration,
and it has the hook subsystem your ten events need. pi with LazyPi needs two settings and
loses the hooks and the plugins. The reason to pick LazyPi instead is if you want the 25
packages, and the one genuinely worth envying is `pi-claude-cli`, which routes pi through your
existing Claude Code subscription.

## Codex

Added 20 September 2026. `openai/codex`, 125,511 stars, Apache 2.0, written in Rust, OpenAI's
own terminal agent. Install with `brew install --cask codex` or
`curl -fsSL https://chatgpt.com/codex/install.sh | sh`.

For your setup it has one large advantage and one hard blocker.

### The advantage

Codex has a lifecycle hook system whose event names are almost the ones you already use.
`PreToolUse`, `PermissionRequest`, `PostToolUse`, `SessionStart`, `SessionEnd`,
`SubagentStop`, `UserPromptSubmit` and `Stop`, plus `PreCompact`, `PostCompact`,
`SubagentStart` and `Interrupt`. Eight of your ten map by name with no thought at all. Only
`Notification` and `StopFailure` have no counterpart.

They are command hooks, meaning shell commands, and they support `async` the same way your
`Stop` handlers do. So `cc-status`, `tts_hook.sh` and `spock-clip.sh` port across as they
stand. No TypeScript, unlike omp.

Put them in `~/.codex/hooks.json` or inline as `[hooks]` in `~/.codex/config.toml`, and turn
the subsystem on with `features.hooks = true`.

### The blocker

Codex cannot talk to colibri. Its custom provider config takes `wire_api`, and the reference
says `responses` is the only supported value, meaning OpenAI's Responses API. Colibri serves
`/v1/chat/completions`, the legacy `/v1/completions` and Anthropic's `/v1/messages`, and no
Responses endpoint. There is nothing to point Codex at.

Its built-in local options are `oss_provider`, which takes `lmstudio` or `ollama` and runs
with `--oss`. Those work for a GGUF model such as Bonsai 2 27B, not for colibri's streamed
container. To use Codex against DeepSeek you would need a translating proxy such as LiteLLM in
front of colibri.

### Migrating to Codex

```sh
./flatten-rules.sh ~/.codex/AGENTS.md
ln -s ~/.claude/skills ~/.agents/skills
```

`~/.codex/AGENTS.md` is Codex's global instruction file, read before any work and layered
under whatever a repository adds. `$HOME/.agents/skills` is its user skill scope, and Codex
follows symlinked skill folders when it scans, so one link carries all 59.

Then raise the cap, because this one will bite silently.

```toml
# ~/.codex/config.toml
project_doc_max_bytes = 262144
features.hooks = true
```

`project_doc_max_bytes` defaults to **32 KiB** and Codex stops adding files once the combined
size reaches it. Your flattened `AGENTS.md` is 108 KB, so more than two thirds of your rules
would be dropped without a word.

### Ranking, revised

For rules and skills all four are about equal once you run `flatten-rules.sh` at the right
path. The separation is hooks and local models.

| | reads `~/.claude` directly | hooks port as shell | talks to colibri |
|---|---|---|---|
| omp | yes, including plugins | no, TypeScript wrappers | yes, OpenAI-compatible |
| Codex | no | yes, eight events by name | no, Responses API only |
| jcode | MCP servers only | not documented | yes, plus a built-in `deepseek` profile |
| pi, LazyPi | skills, with one settings line | no hook subsystem | yes, OpenAI-compatible |

omp still wins overall, because it is the only one that takes your plugins and your rules with
no configuration and still speaks to the local server. Codex is the one to pick if the hooks
matter more than the local model, since it is the only harness where they port unchanged.

## OpenCode

Added 20 September 2026. The repository at `opencode-ai/opencode` is **archived**, last pushed
18 September 2025, and its README says the project moved and continues as Crush under the
Charm team. The live OpenCode is `anomalyco/opencode`, 208,884 stars, MIT, TypeScript, and it
is the largest of every harness compared here.

For preserving what you have, it is the best of the six, because it is the only one that reads
all three of your stores without copying any of them.

**Rules.** OpenCode's discovery order is local `AGENTS.md` or `CLAUDE.md` walking up from the
current directory, then `~/.config/opencode/AGENTS.md`, then `~/.claude/CLAUDE.md`. Your global
file is read directly, with no flattening and no configuration, and
`OPENCODE_DISABLE_CLAUDE_CODE_PROMPT=1` turns that off if you ever want to.

**Skills.** It scans six locations, two of which are `~/.claude/skills/<name>/SKILL.md` and
`.claude/skills/<name>/SKILL.md`, named in its own documentation as the Claude-compatible
global and project paths. All 59 load with nothing configured.

**Memory.** This is the one that matters. OpenCode takes an `instructions` array that accepts
globs and remote URLs, so the 57 rule files load from where they live.

```json
// ~/.config/opencode/opencode.json
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": ["~/.claude/memory/*.md"]
}
```

No flattening, so no second copy to drift. Write a new rule with `/promote-rule` tonight and
OpenCode reads it tomorrow. Every other harness here needs `flatten-rules.sh` re-run after
every change, and a stale copy is the failure your own memory rules are written to prevent.

**The local model.** OpenCode uses the AI SDK, so colibri is a custom provider through
`@ai-sdk/openai-compatible`.

```json
{
  "provider": {
    "colibri": {
      "npm": "@ai-sdk/openai-compatible",
      "options": { "baseURL": "http://127.0.0.1:8000/v1" },
      "models": { "deepseek-v41-flash": { "name": "DeepSeek V4.1 Flash" } }
    }
  }
}
```

**What it costs.** Plugins do not come across; only omp reads the Claude marketplace format.
Hooks are JavaScript plugin modules subscribing to events such as `session.created`,
`session.idle`, `tool.execute.before` and the permission events, so the same rewrite omp needs.
And it is the heaviest of the lot, measured by jcode's own comparison at 371.5 MB for one
session against jcode's 27.8 MB, which is not nothing on a 8 GB Mac.

## Recommendation

Keep Claude Code as the daily driver. It reaches colibri through `/v1/messages` with three
environment variables and nothing else changes, so running DeepSeek locally costs you no
migration at all.

Install **OpenCode** as the second harness. It is the only one of the five alternatives that
reads your `CLAUDE.md`, your 59 skills and your 57 memory rules from where they already sit,
with one line of configuration for the last of those and none for the first two. Nothing is
copied, so nothing goes stale, which matters more for you than for most people because that
store changes weekly.

Pick **omp** instead only if the 77 MB of plugins is the part you cannot lose, since it is the
only harness with a `claude-plugins` discovery provider.

Do not pick **Codex** for this project. Its hooks port better than anyone's, eight of your ten
by name and still shell commands, but `wire_api` accepts only OpenAI's Responses API and
colibri does not serve one, so it cannot reach your model without a LiteLLM proxy in between.

Do not pick **pi** or **LazyPi**, which need configuration for skills, flattening for rules,
and have no hook subsystem at all. **jcode** stays worth installing on the Ubuntu box for its
27.8 MB footprint and its built-in `deepseek` profile, but it inherits only your MCP servers.
