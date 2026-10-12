#!/usr/bin/env bash
# Exercise real command routing with fake system/Nix tools. Never activates anything.
set -euo pipefail
SOURCE=$(cd "$(dirname "$0")/.." && pwd)
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/nix-sync-platforms.XXXXXX")
trap 'rm -rf "$TEST_ROOT"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME='Sync test' GIT_COMMITTER_NAME='Sync test'
export GIT_AUTHOR_EMAIL='test@example.com' GIT_COMMITTER_EMAIL='test@example.com'
export TEST_LOG="$TEST_ROOT/commands" TEST_BUILD="$TEST_ROOT/build"
export TEST_OS=Linux TEST_ARCH=x86_64 TEST_USER=tester TEST_FAIL_BUILD=0
mkdir -p "$TEST_ROOT/repo with spaces/scripts" "$TEST_ROOT/bin" "$TEST_BUILD/bin"
cp "$SOURCE/sync.sh" "$TEST_ROOT/repo with spaces/sync.sh"
printf '#!/usr/bin/env bash\nprintf "check\\n" >> "$TEST_LOG"\n' > "$TEST_ROOT/repo with spaces/scripts/check.sh"
chmod +x "$TEST_ROOT/repo with spaces/scripts/check.sh"
git -C "$TEST_ROOT/repo with spaces" init --initial-branch=main -q
git -C "$TEST_ROOT/repo with spaces" add .
git -C "$TEST_ROOT/repo with spaces" commit -qm 'Fixture'
cat > "$TEST_ROOT/bin/mock" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
name=${0##*/}
printf '%s %s\n' "$name" "$*" >> "$TEST_LOG"
case "$name" in
  uname) case "$1" in -s) printf '%s' "$TEST_OS" ;; -m) printf '%s' "$TEST_ARCH" ;; *) exit 90 ;; esac ;;
  id) case "$1" in -u) printf 1000 ;; -un) printf tester ;; *) exit 90 ;; esac ;;
  nix)
    case "$1" in
      eval)
        case "$*" in
          *hostPlatform.system*)
            case "$*" in
              *darwinConfigurations*) printf aarch64-darwin ;;
              *linux-aarch64*) printf aarch64-linux ;;
              *) printf x86_64-linux ;;
            esac ;;
          *homeDirectory*) printf '%s' "$HOME" ;;
          *primaryUser*|*home.username*|*lib.usernames.nixos*) printf '%s' "$TEST_USER" ;;
          *) exit 90 ;;
        esac ;;
      build)
        [ "$TEST_FAIL_BUILD" = 0 ] || exit 42
        case "$*" in *--print-out-paths*) printf '%s\n' "$TEST_BUILD" ;; esac ;;
      *) exit 90 ;;
    esac ;;
  sudo) "$@" ;;
  darwin-rebuild|nixos-rebuild|activate) : ;;
  *) exit 90 ;;
esac
MOCK
chmod +x "$TEST_ROOT/bin/mock"
for tool in uname id nix sudo nixos-rebuild; do ln -s "$TEST_ROOT/bin/mock" "$TEST_ROOT/bin/$tool"; done
ln -s "$TEST_ROOT/bin/mock" "$TEST_BUILD/bin/darwin-rebuild"
ln -s "$TEST_ROOT/bin/mock" "$TEST_BUILD/activate"
export PATH="$TEST_ROOT/bin:$PATH"
passed=0
run() {
  : > "$TEST_LOG"
  bash "$TEST_ROOT/repo with spaces/sync.sh" "$@" > "$TEST_ROOT/output" 2>&1
}
pass() { passed=$((passed + 1)); printf 'PASS %s\n' "$1"; }
blocked() {
  label=$1; shift
  if run "$@"; then cat "$TEST_ROOT/output"; printf 'Unexpected success: %s\n' "$label" >&2; exit 1; fi
  if grep -Eq '^(sudo|activate|darwin-rebuild|nixos-rebuild) ' "$TEST_LOG"; then cat "$TEST_LOG"; exit 1; fi
  pass "$label"
}

export TEST_OS=Darwin TEST_ARCH=arm64
run apply macbook
grep -q '^sudo .*darwin-rebuild switch --flake .*#macbook$' "$TEST_LOG"
pass 'macOS uses the locked darwin-rebuild with sudo'
run build macmini
grep -q '#darwinConfigurations.macmini.config.system.build.toplevel$' "$TEST_LOG"
! grep -q '^sudo ' "$TEST_LOG"
pass 'Build does not activate'

export TEST_OS=Linux TEST_ARCH=x86_64
run apply linux-x86_64
grep -q '#homeConfigurations.linux-x86_64.activationPackage$' "$TEST_LOG"
grep -q '^activate ' "$TEST_LOG"
! grep -q '^sudo ' "$TEST_LOG"
pass 'Standalone Linux activates Home Manager without sudo'

export TEST_ARCH=aarch64
run apply linux-aarch64
grep -q '#homeConfigurations.linux-aarch64.activationPackage$' "$TEST_LOG"
grep -q '^activate ' "$TEST_LOG"
pass 'ARM64 Linux selects its own package set'
blocked 'Architecture mismatch cannot activate' apply linux-x86_64
blocked 'OS mismatch cannot activate' apply macbook

export TEST_ARCH=x86_64
run apply nixos
grep -q '#nixosConfigurations.nixos.config.system.build.toplevel$' "$TEST_LOG"
grep -q '^sudo nixos-rebuild switch --flake .*#nixos$' "$TEST_LOG"
pass 'NixOS builds first and uses nixos-rebuild with sudo'

export TEST_USER=someone-else
blocked 'Account mismatch cannot activate' apply linux-x86_64
export TEST_USER=tester TEST_FAIL_BUILD=1
blocked 'A failed Home Manager build cannot activate' apply linux-x86_64
blocked 'A failed NixOS build cannot reach sudo' apply nixos
export TEST_FAIL_BUILD=0
blocked 'Unknown target is rejected' apply unknown
printf draft > "$TEST_ROOT/repo with spaces/draft"
blocked 'Dirty configuration cannot activate' apply linux-x86_64
[ ! -s "$TEST_LOG" ]
printf '%s platform tests passed.\n' "$passed"
