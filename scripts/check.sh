#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
git diff --check
git diff --cached --check
ignored=$(git ls-files --cached --ignored --exclude-standard)
if [ -n "$ignored" ]; then
  printf 'Ignored files are tracked; remove them from the index:\n%s\n' "$ignored" >&2
  exit 1
fi
bash -n sync.sh scripts/check.sh tests/sync.sh
bash tests/sync.sh
for host in macbook macmini; do
  printf 'Evaluating %s...\n' "$host"
  nix eval --raw ".#darwinConfigurations.$host.config.system.build.toplevel.drvPath"
  printf '\n'
done
printf '%s\n' 'Checks passed. No system configuration was applied.'
