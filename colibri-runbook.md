# Colibri runbook

DeepSeek V4.1 Flash, 552B parameters, 510 GB on disk, on Ubuntu with 32 GB of RAM and a
1 TB SSD. Written 20 September 2026 against colibri v1.12.0 and `docs/deepseek-v41.md`.
This checkpoint needs no conversion, because its dense weights are already fp8 and its
routed experts are already fp4, and colibri reads both formats natively.

Do step three first and leave it running. The download is the long pole and everything
else takes minutes.

## Step one

Install the build tools and the Hugging Face downloader.

```bash
sudo apt update
sudo apt install -y build-essential git python3 python3-pip
pip install -U "huggingface_hub[cli]"
```

`build-essential` supplies gcc, make and OpenMP through libgomp, which is the engine's
entire dependency list.

## Step two

Get the source.

```bash
cd ~
git clone https://github.com/JustVugg/colibri.git
cd colibri
```

## Step three

Start the download now, in its own terminal, and let it run while you do the rest.
510 GB across 88 files.

```bash
hf download deepseek-ai/DeepSeek-V4.1-Flash \
  --local-dir ~/Models/DeepSeek-V4.1-Flash
```

It resumes if it stops. When it finishes, check that no shard came down truncated,
because the client can report success on a short file.

```bash
du -sh ~/Models/DeepSeek-V4.1-Flash
ls -l ~/Models/DeepSeek-V4.1-Flash/model-*.safetensors | wc -l
```

## Step four

Build the engine while the download runs.

```bash
make -C c deepseek_v41
```

That compiles `c/deepseek_v41.c` for your own CPU. To confirm the toolchain first,
`cd c && ./setup.sh` checks gcc and OpenMP, builds the reference engine and prints
`engine self-test: 32/32`. A 30 or 31 is also a pass.

## Step five

Write the sidecar. This runs once per checkpoint and produces about 1 MB.

```bash
python3 c/tools/prepare_dsv41.py --model ~/Models/DeepSeek-V4.1-Flash
```

It writes `dsv41_engram.json` next to `config.json`, holding the three tables the
engine cannot derive at load time. The compressed-token map, the bucket primes and the
hash multipliers. The multipliers are stored as decimal strings on purpose, because
they run past a double's 53-bit mantissa and a rounded one would hash every n-gram into
a different row that still looks valid.

## Step six

Check and run.

```bash
cd ~/colibri
./coli doctor --model ~/Models/DeepSeek-V4.1-Flash
./coli plan   --model ~/Models/DeepSeek-V4.1-Flash
./coli chat   --model ~/Models/DeepSeek-V4.1-Flash
```

`doctor` is read-only and names anything missing. `plan` shows where the weights will
live and what the bottleneck will be. Then chat.

For an API and a web dashboard instead of the terminal.

```bash
./coli web   --model ~/Models/DeepSeek-V4.1-Flash    # opens a browser
./coli serve --model ~/Models/DeepSeek-V4.1-Flash    # headless
```

## Settings

Turn the per-turn accounting on for the first few runs, so you can see the expert bytes,
their read rate and the draft acceptance.

```bash
V41_STATS=1 ./coli chat --model ~/Models/DeepSeek-V4.1-Flash
```

Four settings are worth touching on this machine, and the rest of the defaults are
already the measured ones.

| setting | default | what to do with it |
|---|---|---|
| `V41_DIRECT` | 1 | O_DIRECT expert reads, skipping the page cache. Run one turn with `V41_DIRECT=0` and keep whichever is faster on your drive. |
| `V41_READ_DEPTH` | 8 | Expert tensors read at once on a cache miss. Measured 0.358 tok/s at depth 1, 0.566 at depth 8, 0.506 at depth 16. Leave it at 8 unless a sweep says otherwise. |
| `V41_DSPARK` | on | The DSpark draft head, measured at plus 17 per cent cold. `V41_DSPARK_MINACC` holds the acceptance guard at 60 per cent, which is where the measurement put it. |
| `--ram N` | auto | The planner's RAM budget in GiB. It is a budget, not a hard limit. Start by leaving it alone, then try `--ram 24` and `--ram 28`. |

Then let `coli tune` measure the rest on your actual machine and save the profile.

```bash
./coli tune --model ~/Models/DeepSeek-V4.1-Flash
```

## What happens

The engine holds the dense weights, the embeddings and the vision tower resident, about
18 GB. The 15,360 routed experts, 18.8 MB each and 289 GB in total, stream from the SSD
as the router calls for them, six of 384 per layer. The 203 GB n-gram memory is read a
few dozen rows at a time, 264 bytes per row, about 13 KB per token.

That comes to 4.5 GB of expert reads per token, which is the number that makes this
model work on your box. GLM-5.2 reads 12.7 GB per token and has fewer parameters.

The engine writes what your prompts route to as it goes and pins those experts on later
runs, so the same machine gets faster across its first several sessions. The first turn
is the slowest one you will see.

Vision, tool calling and the draft head are all on by default on this checkpoint.

## If something breaks

`./coli doctor --model <dir>` names the missing compiler, file or permission.
`./coli doctor --deep --model <dir>` runs the strict tensor, shard and index preflight.
If `st.h` rejects a shard as out of bounds, compare your local shard sizes against the
Hugging Face repository before blaming the engine, because that is a truncated download.
