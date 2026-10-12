{ config, pkgs, ... }:
{
  home.stateVersion = "26.05";
  home.packages = with pkgs; [ ripgrep fd jq tree ];
  programs.zsh = {
    enable = true;
    shellAliases = { ll = "ls -lah"; };
  };
  programs.git = {
    enable = true;
    settings = {
      init.defaultBranch = "main";
      pull.ff = "only";
      fetch.prune = true;
    };
    # A string path: Git reads the local file at runtime.
    # Never use builtins.readFile here; secrets must not enter the Nix store.
    includes = [ { path = "${config.home.homeDirectory}/.config/nix-dual-mac/gitconfig"; } ];
  };
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    includes = [ "${config.home.homeDirectory}/.ssh/config.local" ];
  };
}
