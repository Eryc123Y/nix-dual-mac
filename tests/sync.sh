#!/usr/bin/env bash
# Local Git fixtures only. No network, Nix build, sudo, or activation.
set -euo pipefail
SOURCE=$(cd "$(dirname "$0")/.." && pwd)
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/nix-dual-mac-test.XXXXXX")
trap 'rm -rf "$TEST_ROOT"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME='Sync test' GIT_COMMITTER_NAME='Sync test'
export GIT_AUTHOR_EMAIL='test@example.com' GIT_COMMITTER_EMAIL='test@example.com'
passed=0
fixture() {
  case_dir="$TEST_ROOT/$1"
  mkdir -p "$case_dir"
  git init --bare --initial-branch=main -q "$case_dir/remote.git"
  git clone -q "$case_dir/remote.git" "$case_dir/a" 2>/dev/null
  cp "$SOURCE/sync.sh" "$case_dir/a/sync.sh"
  printf 'private/\n' > "$case_dir/a/.gitignore"
  git -C "$case_dir/a" add .
  git -C "$case_dir/a" commit -qm 'Initial fixture'
  git -C "$case_dir/a" push -qu origin main
  git clone -q "$case_dir/remote.git" "$case_dir/b"
  before=$(git -C "$case_dir/b" rev-parse HEAD)
}
remote_change() {
  printf 'remote\n' > "$case_dir/a/remote.txt"
  git -C "$case_dir/a" add remote.txt
  git -C "$case_dir/a" commit -qm 'Remote edit'
  git -C "$case_dir/a" push -q
}
local_commit() {
  printf 'local\n' > "$case_dir/b/local.txt"
  git -C "$case_dir/b" add local.txt
  git -C "$case_dir/b" commit -qm 'Local edit'
  before=$(git -C "$case_dir/b" rev-parse HEAD)
}
run_pull() { bash "$case_dir/b/sync.sh" pull > "$case_dir/output" 2>&1; }
pass() { passed=$((passed + 1)); printf 'PASS %s\n' "$1"; }
blocked() {
  if run_pull; then cat "$case_dir/output"; printf 'Unexpected success: %s\n' "$1" >&2; exit 1; fi
  [ "$(git -C "$case_dir/b" rev-parse HEAD)" = "$before" ]
  pass "$1"
}

fixture unchanged
run_pull
[ "$(git -C "$case_dir/b" rev-parse HEAD)" = "$before" ]
pass 'Already synchronized'

fixture fast_forward
remote_change
run_pull
cmp "$case_dir/a/remote.txt" "$case_dir/b/remote.txt"
[ "$(git -C "$case_dir/a" rev-parse HEAD)" = "$(git -C "$case_dir/b" rev-parse HEAD)" ]
pass 'Second Mac receives the exact commit'

fixture dirty
remote_change
printf '\n# Local edit\n' >> "$case_dir/b/sync.sh"
blocked 'Uncommitted edits are preserved'
tail -1 "$case_dir/b/sync.sh" | grep -q 'Local edit'

fixture staged
printf 'draft\n' > "$case_dir/b/draft"
git -C "$case_dir/b" add draft
blocked 'Staged edits are preserved'
git -C "$case_dir/b" diff --cached --name-only | grep -qx draft

fixture untracked
printf 'draft\n' > "$case_dir/b/draft"
blocked 'Untracked files stop synchronization'

fixture ahead
local_commit
blocked 'Unpublished local commits stop synchronization'

fixture divergent
local_commit
remote_change
blocked 'Divergent histories are preserved'

fixture detached
git -C "$case_dir/b" checkout -q --detach
blocked 'Detached HEAD stops synchronization'

fixture no_upstream
git -C "$case_dir/b" branch --unset-upstream
blocked 'Missing upstream stops synchronization'

fixture fetch_failure
git -C "$case_dir/b" remote set-url origin "$case_dir/missing.git"
blocked 'Fetch failure stops synchronization'

fixture ignored
mkdir "$case_dir/b/private"
printf 'local-only\n' > "$case_dir/b/private/note"
remote_change
run_pull
[ "$(cat "$case_dir/b/private/note")" = local-only ]
pass 'Ignored local files stay on this machine'

fixture sync_failure
mkdir "$case_dir/bin"
printf '#!/bin/sh\nprintf called > "%s"\nexit 99\n' "$case_dir/called" > "$case_dir/bin/nix"
chmod +x "$case_dir/bin/nix"
printf draft > "$case_dir/b/draft"
if PATH="$case_dir/bin:$PATH" bash "$case_dir/b/sync.sh" sync macbook > "$case_dir/output" 2>&1; then exit 1; fi
[ ! -e "$case_dir/called" ]
pass 'A failed pull cannot reach Nix or activation'

printf '%s sync tests passed.\n' "$passed"
