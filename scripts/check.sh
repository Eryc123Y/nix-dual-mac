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
bash -n sync.sh scripts/check.sh tests/sync.sh tests/platforms.sh
bash tests/sync.sh
bash tests/platforms.sh
for host in macbook macmini; do
  printf 'Evaluating %s...\n' "$host"
  nix eval --raw ".#darwinConfigurations.$host.config.system.build.toplevel.drvPath"
  printf '\n'
done
for host in linux-x86_64 linux-aarch64; do
  printf 'Evaluating %s user configuration...\n' "$host"
  nix eval --raw ".#homeConfigurations.$host.activationPackage.drvPath"
  printf '\n'
done
printf 'Evaluating shared NixOS module with test-only hardware...\n'
nix eval --raw '.#checks.x86_64-linux.nixos-module.drvPath'
printf '\nReal NixOS hardware is checked by ./sync.sh build nixos on that machine.\n'
printf '%s\n' 'Checks passed. No system configuration was applied.'
