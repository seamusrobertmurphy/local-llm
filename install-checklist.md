# Install checklist

For the week of 21 September 2026. Steps in order, each with the command and the one thing
that goes wrong. Detail in `colibri-runbook.md` and `harness-plan.md`.

## Before you start

Confirm the two facts that change the plan, on the HP.

```bash
lsblk -d -o NAME,ROTA,MODEL,SIZE          # the SSD's model, to tell NVMe from SATA
df -h ~                                    # confirm 510 GB is still free
lscpu | grep -E 'Model name|^CPU\(s\)|Flags' | cut -c1-200   # cores, and avx512 or avx2
nvidia-smi 2>/dev/null || echo "no NVIDIA GPU"
```

A GPU makes DeepSeek prefill five to ten times faster and decode about 2.5 times faster, and
anything from the GTX 10 series up is supported. AVX-512 machines pull well ahead once the disk
stops being the bottleneck.

## Day one, the download

```bash
sudo apt update && sudo apt install -y build-essential git python3 python3-pip
pip install -U "huggingface_hub[cli]"
git clone https://github.com/JustVugg/colibri.git && cd colibri
hf download deepseek-ai/DeepSeek-V4.1-Flash --local-dir ~/Models/DeepSeek-V4.1-Flash
```

510 GB across 88 files. It resumes if it stops. The client can report success on a truncated
shard, so check the size and file count when it finishes.

```bash
du -sh ~/Models/DeepSeek-V4.1-Flash
ls -l ~/Models/DeepSeek-V4.1-Flash/model-*.safetensors | wc -l
```

## Day one, while it downloads

```bash
make -C c deepseek_v41
python3 c/tools/prepare_dsv41.py --model ~/Models/DeepSeek-V4.1-Flash
```

The sidecar is about 1 MB and runs once. Its hash multipliers are stored as decimal strings
because they run past a double's 53-bit mantissa, so never let a JSON tool rewrite that file.

## Day two, first run

```bash
cd ~/colibri
./coli doctor --model ~/Models/DeepSeek-V4.1-Flash
./coli plan   --model ~/Models/DeepSeek-V4.1-Flash
V41_STATS=1 ./coli chat --model ~/Models/DeepSeek-V4.1-Flash
```

The first turn is the slowest you will see. The engine records which experts your prompts route
to and pins them on later runs, so the same machine gets faster across its first few sessions.

Then measure the one setting that is drive-dependent, one turn each, same prompt.

```bash
V41_STATS=1 V41_DIRECT=1 ./coli chat --model ~/Models/DeepSeek-V4.1-Flash
V41_STATS=1 V41_DIRECT=0 ./coli chat --model ~/Models/DeepSeek-V4.1-Flash
```

Keep whichever reads faster. Leave `V41_READ_DEPTH` at 8; the measured curve is 0.358 tok/s at
depth 1, 0.566 at 8 and 0.506 at 16. Then run `./coli tune` and let it save a profile.

## Day two, the gateway

```bash
COLI_MODEL=~/Models/DeepSeek-V4.1-Flash \
  ./coli serve --host 127.0.0.1 --port 8000 --model-id deepseek-v41-flash

curl http://127.0.0.1:8000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"deepseek-v41-flash","messages":[{"role":"user","content":"hi"}]}'
```

Smoke-test before wiring any client to it.

## Day two, Claude Code against it

```bash
export ANTHROPIC_BASE_URL=http://localhost:8000
export ANTHROPIC_API_KEY=local
export ANTHROPIC_MODEL=deepseek-v41-flash
claude
```

The key is only checked if you set `COLI_API_KEY`, but the client will not start without some
value. Expect a long silent wait on the first token, because Claude Code's system prompt and
tool catalogue are large and every one of those prompt tokens is prefilled against experts
streamed off the SSD.

## Day three, OpenCode

On the Mac, or on the HP.

```bash
curl -fsSL https://opencode.ai/install | bash
```

Rules and skills need no configuration; it reads `~/.claude/CLAUDE.md` and
`~/.claude/skills/*/SKILL.md` directly. The memory rules need one line.

```json
// ~/.config/opencode/opencode.json
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": ["~/.claude/memory/*.md"],
  "provider": {
    "colibri": {
      "npm": "@ai-sdk/openai-compatible",
      "options": { "baseURL": "http://127.0.0.1:8000/v1" },
      "models": { "deepseek-v41-flash": { "name": "DeepSeek V4.1 Flash" } }
    }
  }
}
```

Verify the rules actually loaded before trusting it. Ask it to quote the first rule in
`~/.claude/CLAUDE.md` and to name three of the portable memory files.

Do not connect it to a metered Anthropic API key. OpenCode removed the Claude Pro/Max plugins
at version 1.3.0 because Anthropic prohibits them, so the only supported Anthropic route bills
per token on top of the subscription, which is the opposite of what this repository is for.

## Optional, jcode on the HP

Worth it for the 27.8 MB footprint and the built-in local provider profiles.

```bash
curl -fsSL https://jcode.sh/install | bash
./flatten-rules.sh ~/AGENTS.md
mkdir -p ~/.jcode/skills && cp -RL ~/.claude/skills/. ~/.jcode/skills/
jcode provider add colibri --base-url http://127.0.0.1:8000/v1 \
  --model deepseek-v41-flash --no-api-key --context-window 128000 --set-default
jcode --provider-profile colibri auth-test --prompt 'Reply exactly JCODE_PROVIDER_SETUP_OK'
```

`cp -RL` follows the 16 symlinks into `library-skills` and `library-audits` and copies the real
directories. Raise `JCODE_STREAM_IDLE_TIMEOUT_SECS` above its 180 second default, because the
model thinks before it emits while experts come off disk.

## Optional, Bonsai for speed

If DeepSeek at under a token per second is too slow for everyday work, Bonsai 2 27B is 5.95 GB,
fits in RAM, and is Apache 2.0. It needs the PrismML llama.cpp fork, because stock llama.cpp
loads these files without warning and produces garbage.

```bash
git clone https://github.com/PrismML-Eng/llama.cpp && cd llama.cpp
cmake -B build -DGGML_CUDA=ON && cmake --build build -j
hf download prism-ml/Ternary-Bonsai-2-27B-gguf Ternary-Bonsai-2-27B-PQ2_0.gguf --local-dir .
./build/bin/llama-cli -m Ternary-Bonsai-2-27B-PQ2_0.gguf -ngl 99 -fa on -c 32768
```

Drop `-DGGML_CUDA=ON` with no NVIDIA card, and use `-ngl 0` for CPU only.
