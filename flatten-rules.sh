#!/usr/bin/env bash
# Flatten ~/.claude/CLAUDE.md and every file in ~/.claude/memory/ into one
# AGENTS.md that omp, jcode and Codex all read. Frontmatter is stripped only
# when it is actually present; files that open with a heading are copied whole.
set -euo pipefail
OUT="${1:-$HOME/.omp/agent/AGENTS.md}"
mkdir -p "$(dirname "$OUT")"
{
  cat "$HOME/.claude/CLAUDE.md"
  printf '\n\n# Portable rules\n'
  for f in "$HOME"/.claude/memory/*.md; do
    [ "$(basename "$f")" = index.md ] && continue
    printf '\n## %s\n\n' "$(basename "$f" .md)"
    awk 'NR==1 && $0=="---" {fm=1; next} fm && $0=="---" {fm=0; next} !fm' "$f"
  done
} > "$OUT"
printf '%s\n' "wrote $OUT"
wc -l -w -c "$OUT"
