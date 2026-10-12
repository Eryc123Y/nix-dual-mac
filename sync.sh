#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")" && pwd)
cd "$ROOT"

die() { printf '%s\n' "$*" >&2; exit 1; }
clean_tree() {
  [ -z "$(git status --porcelain --untracked-files=all)" ] ||
    die "Local changes found. Review and commit them before continuing."
}
pull_config() {
  clean_tree
  branch=$(git symbolic-ref --quiet --short HEAD) || die "Check out a branch first."
  remote=$(git config --get "branch.$branch.remote") || die "Set an upstream remote first."
  ref=$(git config --get "branch.$branch.merge") || die "Set an upstream branch first."
  [ "$remote" != . ] || die "Use a remote repository as the upstream."
  git fetch --no-tags "$remote" "$ref"
  # Stop for both divergence and unpublished local commits. Never reset or stash.
  git merge-base --is-ancestor HEAD FETCH_HEAD ||
    die "Local commits are not on the remote. Push them or resolve divergence first."
  git merge --ff-only FETCH_HEAD
}
select_host() {
  host=${1:-}
  case "$host" in macbook|macmini) ;; *) die "Choose macbook or macmini explicitly." ;; esac
}
check_machine() {
  [ "$(uname -s)" = Darwin ] && [ "$(uname -m)" = arm64 ] ||
    die "This template targets Apple Silicon macOS."
  [ "$(id -u)" != 0 ] || die "Run this script as your normal user; it requests sudo when needed."
  username=$(nix eval --raw "$ROOT#darwinConfigurations.$host.config.system.primaryUser")
  [ "$username" = "$(id -un)" ] || die "Edit users.nix: $host must use the current macOS account."
}
apply_config() {
  clean_tree
  check_machine
  "$ROOT/scripts/check.sh"
  # Build first as the user. Only system activation needs sudo.
  rebuild=$(nix build --no-link --print-out-paths "$ROOT#darwin-rebuild")
  sudo "$rebuild/bin/darwin-rebuild" switch --flake "$ROOT#$host"
}

case "${1:-help}" in
  pull) [ "$#" = 1 ] || die "Usage: ./sync.sh pull"; pull_config ;;
  check) [ "$#" = 1 ] || die "Usage: ./sync.sh check"; "$ROOT/scripts/check.sh" ;;
  build)
    [ "$#" = 2 ] || die "Usage: ./sync.sh build macbook|macmini"
    select_host "$2"
    check_machine
    "$ROOT/scripts/check.sh"
    nix build --no-link "$ROOT#darwinConfigurations.$host.config.system.build.toplevel"
    ;;
  apply)
    [ "$#" = 2 ] || die "Usage: ./sync.sh apply macbook|macmini"
    select_host "$2"; apply_config
    ;;
  sync)
    [ "$#" = 2 ] || die "Usage: ./sync.sh sync macbook|macmini"
    select_host "$2"; pull_config; apply_config
    ;;
  help|--help|-h)
    printf '%s\n' 'Usage: ./sync.sh {pull|check|build HOST|apply HOST|sync HOST}' \
      'HOST: macbook or macmini. sync = pull then apply.' \
      'Commit and push reviewed changes yourself. No automatic commits or force pushes.'
    ;;
  *) die "Unknown command. Run ./sync.sh --help." ;;
esac
