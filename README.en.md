# nix-dual-mac

**Two Macs, one shared configuration.** Change your tools and terminal setup on a MacBook, push the reviewed changes, then pull and apply them on a Mac mini. Each machine keeps its own settings.

[中文](README.md) · [Configuration](flake.nix) · [Sync script](sync.sh)

Built for **Apple Silicon MacBook + Mac mini**, using Nix, nix-darwin, and Home Manager. The two Macs can have different account names.

This is a small reference template extracted from a personal two-Mac workflow. It synchronizes declared tools and settings when you run the command. Documents, browser data, app logins, and secrets are managed separately.

## Structure

| File | Purpose |
| --- | --- |
| `modules/macos.nix` | Shared macOS settings |
| `modules/home.nix` | Shared packages, Zsh, Git, and SSH |
| `hosts/macbook.nix` | Laptop-specific settings |
| `hosts/macmini.nix` | Desktop-specific settings |
| `users.nix` | Existing macOS account name on each Mac |
| `flake.lock` | Dependency versions shared by both Macs |

The baseline includes Git, ripgrep, fd, jq, tree, Zsh, and a few Dock / Finder preferences. Add packages gradually in your own copy. There is no Homebrew installation or server deployment configuration.

## Set up both Macs

Use **Use this template → Create a new repository** on GitHub. A **private** personal repository is recommended. Clone your own repository on both Macs:

```bash
git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git ~/nix-dual-mac
cd ~/nix-dual-mac
```

Install a flake-capable Nix implementation on each machine; see the [official nix-darwin prerequisites](https://github.com/nix-darwin/nix-darwin#prerequisites). If needed, add `experimental-features = nix-command flakes` to `~/.config/nix/nix.conf`.

Already using nix-darwin or Home Manager? Merge the modules you need into your setup and preserve your existing `stateVersion` values. This template manages shell, Git, and SSH configuration files, machine names, and some system preferences. Back up existing files first; inspect and migrate conflicting files before retrying activation.

Run `id -un` on each Mac and enter the existing account names in `users.nix`. Adjust the computer names in `hosts/` if desired. No macOS account is created by the script.

On the first Mac:

```bash
git add users.nix hosts/macbook.nix hosts/macmini.nix
./sync.sh check
git diff --cached
git commit -m "Configure my two Macs"
git push
./sync.sh apply macbook
```

Activation prepares `darwin-rebuild` from the locked dependency, then requests sudo. After cloning the same personal repository on the second Mac:

```bash
./sync.sh sync macmini
```

Choose `macbook` or `macmini` explicitly. The script checks the platform and current account, but cannot verify which physical Mac you intended to configure.

## Everyday synchronization

For example, add a shared package on the MacBook:

```bash
./sync.sh pull
# Edit home.packages in modules/home.nix.
git add modules/home.nix
./sync.sh check
git diff --cached
git commit -m "Add a shared tool"
./sync.sh apply macbook
git push
```

Then on the Mac mini:

```bash
./sync.sh sync macmini
```

Changes can travel in either direction. Once both Macs apply the same commit and lockfile, they share the declared configuration and Nix dependency versions while retaining their host-specific settings.

| Command | Effect |
| --- | --- |
| `./sync.sh pull` | Fetch and fast-forward from the configured upstream |
| `./sync.sh check` | Check files, run Git sync tests, and evaluate both hosts |
| `./sync.sh build macbook` | Build without activation |
| `./sync.sh apply macbook` | Apply the current committed configuration without pulling or pushing |
| `./sync.sh sync macmini` | Pull, check, and apply |

Pull stops for uncommitted changes, untracked files, unpublished commits, divergent histories, or fetch failure. Inspect `git status` and `git log --oneline --graph --all -12`, then commit, push, or reconcile changes manually. The script never auto-commits, force-pushes, stashes, or resets your work.

New Nix files must be added to Git before Nix can see them. Existing tracked edits can be checked before committing; activation requires a clean working tree.

## Keep private data local

Git reads `~/.config/nix-dual-mac/gitconfig` on each Mac for your identity. SSH reads `~/.ssh/config.local` for personal hosts. Use `examples/` as a starting point and merge existing files instead of overwriting them. Keep actual keys in `~/.ssh/` or a password manager.

These files are read at runtime, outside the repository. Do not import credentials with `builtins.readFile`: generated content can enter the Nix store and become readable by other local users.

`.gitignore` excludes `private/`, `.env`, common key files, and databases. It cannot detect secrets pasted into ordinary configuration files or remove them from Git history. Review staged changes before pushing; [Gitleaks](https://github.com/gitleaks/gitleaks) can provide an additional scan.

## Dependency updates and verification

Updating dependencies is explicit:

```bash
nix flake update
git add flake.lock
./sync.sh check
git diff --cached
git commit -m "Update locked dependencies"
./sync.sh apply macbook
git push
# On the other Mac: ./sync.sh sync macmini
```

Keep `system.stateVersion` and `home.stateVersion` unchanged for routine updates. They control compatibility behavior; see the [Home Manager upgrade guide](https://nix-community.github.io/home-manager/usage/upgrading.html).

Both host configurations were evaluated before publication, and local Git fixtures test synchronization and failure handling. This minimal template has not been activated on real hardware. Run `./sync.sh build <host>` before first activation. GitHub Actions runs the Git tests; it does not test macOS activation.

Upstream projects: [Nix](https://nix.dev/) · [nix-darwin](https://github.com/nix-darwin/nix-darwin) · [Home Manager](https://nix-community.github.io/home-manager/)

MIT License.
