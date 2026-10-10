# Colibri scoping

> Decided 20 September 2026. The model is **DeepSeek V4.1 Flash**, 552B, 510 GB, on a
> 1 TB SSD. The step-by-step install is in [colibri-runbook.md](colibri-runbook.md).
> What follows is the background reading behind that choice.

Scoped 20 September 2026 against the repository at https://github.com/JustVugg/colibri,
release v1.12.0 published 20 September 2026, Apache 2.0, 36,589 stars, 144 open issues.
The project spells itself *colibrì*, Italian for hummingbird, and the command is `coli`.
Everything below is quoted or computed from the repository's own README, `docs/quickstart.md`,
`docs/tuning.md`, `docs/benchmarks.md` and `c/setup.sh` as they stood on that date.

## The idea

A normal local LLM setup is a suitcase that has to close. The whole model must fit in memory,
so a 32 GB machine runs a model small enough to fit in 32 GB. Colibri is a kitchen instead of a
suitcase. It keeps the small part of the model that every token needs on the counter, in RAM,
and leaves the rest in the pantry, on disk, fetching only the ingredients the current token
actually calls for.

That works because these are Mixture-of-Experts models. A 744B-parameter model activates only
about 40B parameters per token, and only about 11 GB of those change from one token to the next.
Colibri holds the dense part, attention and shared experts and embeddings, about 17B parameters
at int4, resident in roughly 9.9 GB of RAM. The 19,456 routed experts, about 19 MB each, sit on
disk as roughly 370 GB and stream in on demand behind a per-layer cache that learns which experts
your own prompts keep asking for.

The engine is one C file, `c/colibri.c`, about 737 KB of source, with no BLAS, no PyTorch and no
Python at runtime. Python is used only by the one-time model converter, the `coli` launcher and
the optional API gateway. No GPU is required.

## The honest cost

Speed is set by your disk, not your CPU or your GPU, because the experts are read from storage
on every token. The project says this plainly and the benchmark table backs it. Expect a fraction
of a token per second on a slow drive and a few tokens per second on a fast NVMe with the cache
warm. This is not a replacement for a hosted API on latency. It is a way to hold a frontier-scale
model locally and watch it work.

## Your machine

32 GB of RAM clears the bar for most of the roster. The constraint that decides the project is
free disk space, and after that whether the disk is NVMe or SATA.

| Model | Disk for weights | RAM stated | GPU |
|---|---|---|---|
| OLMoE, 7B | ~7 GB int8 | 8 GB | not needed |
| Qwen3.6, 35B-A3B | ~20 GB int4-gs64 | 24 GB, full RAM residency | optional |
| DeepSeek V4 Flash, 284B, REAP-pruned 150B | ~85 GB | 16 GB min, 32 GB comfortable | optional |
| DeepSeek V4 Flash, 284B, full | ~167 GB | 16 GB min, 32 GB comfortable | optional |
| Qwen3.8-Flash-Next, 125B | ~185.5 GB | 16 GB min, 24 GB comfortable | CPU only |
| GLM-5.3-Flash, 321B | ~195 GB converted | 25 GB | not needed |
| GLM-5.2, 744B | ~372 GB | 16 GB min, 24 GB comfortable | not needed |
| GLM-5.3, 744B | ~419 GB | 16 GB min, 24 GB comfortable | not needed |
| Inkling, 975B | ~469 GB | 25 GB with int4 dense | not needed |
| Kimi K3, 2.8T | ~1.6 TB | 32 GB+ | not needed |

All ten run through the same `coli chat`, `coli serve` and `coli web` front end. The launcher reads
the model's `config.json` and picks the matching engine binary, so the command line does not change
between models.

## Closest datapoint

The benchmark table carries one machine that matches yours almost exactly, reported in issue #1070.
A Ryzen 7 5800X, 8 cores and 16 threads, Ubuntu 22.04, 32 GB of DDR4-3200, a Samsung 980 PRO NVMe,
running DeepSeek V4 Flash with `--ram 22`, measured **0.93 tok/s** with a 52.5 per cent expert hit
rate and 16.9 seconds to first token. Its disk read at 10.02 GB/s buffered and 2.50 GB/s with
O_DIRECT.

For contrast, the same table's two 32 GB machines running the much larger GLM-5.2 managed far less.
An Intel i5-12600K on native Windows 11 with 32 GB measured 0.08 tok/s cold with a 3.7 per cent hit
rate, because 32 GB forces the expert cache down to about two slots per layer and almost every
expert is a disk read. A Core Ultra 9 185H with 32 GB and an RTX 5070 Ti went from 0.03 tok/s cold to
1.07 tok/s once the cache warmed and the GPU-resident decode pipeline engaged.

The comparison is the finding. On 32 GB, the mid-sized models are usable and GLM-5.2 is a demonstration.
DeepSeek V4 Flash at around 0.9 tok/s is a slow but real conversation. GLM-5.2 at 0.08 tok/s cold is
eighty seconds for a hundred tokens.

## Recommended path

Start with the REAP-pruned DeepSeek V4 Flash at 85 GB, which loads with no conversion step because its
routed experts are already fp4 and its dense set is already fp8. It is the smallest download that still
gives a frontier-class model, it fits a modest disk, and it is the configuration the nearest measured
32 GB Ubuntu box actually ran. If you want something interactive rather than deliberate, Qwen3.6 35B-A3B
at 20 GB sits fully resident in RAM, and OLMoE at 7 GB is a five-minute proof that the whole toolchain
works before you commit hundreds of gigabytes.

Add GLM-5.2 later only if you have 380 GB free on an NVMe and accept sub-tok/s speed.

## Install steps

Two things are needed, the program at a few hundred KB and the model at tens or hundreds of GB.

**One.** Install the build tools. On Ubuntu this is the whole dependency list.

```bash
sudo apt update
sudo apt install -y build-essential git python3
```

`build-essential` supplies gcc, make and OpenMP through libgomp. If you ever move a compiled binary
to a machine that has never had a compiler, install `libgomp1` there alone, because the engine links
`libgomp.so.1` at runtime and exits silently without it.

**Two.** Get the engine. The prebuilt Linux archive needs no compiler.

```bash
mkdir colibri && tar xzf colibri-v1.12.0-linux-x86_64.tar.gz -C colibri && cd colibri
python3 coli info
```

Building from source instead is worth it on your own machine, because `ARCH=native` compiles for the
vector instructions your CPU actually has rather than a portable baseline.

```bash
git clone https://github.com/JustVugg/colibri.git
cd colibri/c
./setup.sh
```

`setup.sh` checks gcc and OpenMP, builds with `ARCH=native`, and runs a self-test that should print
`engine self-test: 32/32`. A result of 30 or 31 out of 32 is still valid, because two positions in the
tiny oracle are floating-point near-ties that depend on the toolchain.

**Three.** Get the model. For DeepSeek V4 Flash REAP-150B, download
`puwaer/DeepSeek-V4-Flash-0731-reap-150b` from Hugging Face into a folder on your fastest disk, and
build the matching engine with `make -C c deepseek-v4`. No conversion is needed.

If you go for GLM-5.2 instead, use only the group-scaled container,
`mastouri/GLM-5.2-colibri-int4-g64-with-int8-mtp`, and not the older per-row mirrors, which measure
about nine percentage points worse on quality and caused the never-terminating generations reported in
issue #455. Check that the MTP head is int8 and not int4, because an int4 head collapses draft
acceptance to near zero. The README gives the exact byte sizes to check with `ls -l <model>/out-mtp-*`.

**Four.** Check before you chat.

```bash
COLI_MODEL=/nvme/dsv4_reap ./coli doctor        # read-only readiness check
COLI_MODEL=/nvme/dsv4_reap ./coli doctor --deep # strict tensor, shard and index preflight
COLI_MODEL=/nvme/dsv4_reap ./coli plan          # where the weights will live and what will bottleneck
COLI_MODEL=/nvme/dsv4_reap ./coli tune          # measure this machine's fastest safe profile
COLI_MODEL=/nvme/dsv4_reap ./coli chat
./coli web --model /nvme/dsv4_reap              # API and dashboard, opens a browser
./coli serve --model /nvme/dsv4_reap            # API and dashboard, headless
```

## Tuning knobs

The defaults are safe on any machine and everything here is opt-in. Five knobs carry most of the
measured gains on a disk-bound Linux box.

`DIRECT=1` turns on O_DIRECT expert reads, which skip the operating system's page cache. It measured
plus 65 per cent alone on one machine and plus 34 per cent decode on another, but it is drive-dependent
and can be neutral or negative on QLC, DRAM-less or virtualised disks. On the 5800X row above, O_DIRECT
read slower than buffered, so measure it rather than assume it.

`--topp 0.7` or `--topp 0.85` reads 30 to 40 per cent fewer expert bytes per token. It is a lossy
override and the engine prints a warning, but the quickstart recommends 0.85 on a disk-bound machine as
costing no quality.

`URING=1` is a Linux-only batched expert I/O path and implies `PIPE=1`. `PILOT=1` runs the router one
layer ahead to prefetch, which the project measures as 71.6 per cent predictable. `--ram N` and `--cap N`
set the RAM budget and the expert cache slots per layer, and `PIN=stats PIN_GB=g` pins the hottest
experts from a measured usage profile.

The learning cache runs on its own. The engine writes `.coli_usage` every turn, recording which experts
your workload routes to, and pins them on later runs. The measured machines in the table get much faster
across their first several sessions for this reason, one going from 0.16 to 0.40 tok/s over five runs.

If you have a second SSD, put a full or partial copy of the model on it and set `COLI_MODEL_MIRROR`.
The engine routes each expert to one drive by a deterministic hash weighted by measured bandwidth, so the
aggregate read bandwidth is the sum of both. A measured pair on independent controllers went from 0.80 to
1.10 tok/s, a 37.5 per cent gain.

## What to check

Before committing to a download, three numbers about the HP machine decide the plan. Free space on the
largest disk, whether that disk is NVMe or SATA, and the CPU model and core count, because the benchmark
table shows AVX-512 and VNNI machines pulling well ahead of AVX2-only ones once the disk stops being the
bottleneck. A discrete NVIDIA GPU, if there is one, makes DeepSeek V4 Flash prefill five to ten times
faster and decode about 2.5 times faster, and anything from the GTX 10 series upward is supported.

## Risks

The project is two and a half months old, created 1 July 2026, and its own README describes it as a
research platform with no service-level guarantee on speed. It guarantees semantics instead, that
placement changes speed and never the model's answers or precision. The 144 open issues are largely
experiment reports rather than defects, which is how the project asks for contributions.

The model downloads are the real commitment. 85 GB is an evening on a good connection. 372 GB is not.
Test the toolchain on OLMoE first.
