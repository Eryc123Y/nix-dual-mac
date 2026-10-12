{
  description = "Two Macs, one shared Nix configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nix-darwin, home-manager, ... }:
    let
      people = import ./users.nix;
      mkMac = host: nix-darwin.lib.darwinSystem {
        specialArgs = { username = people.${host}; };
        modules = [
          ./modules/macos.nix
          ./hosts/${host}.nix
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.${people.${host}} = import ./modules/home.nix;
          }
        ];
      };
    in {
      darwinConfigurations = {
        macbook = mkMac "macbook";
        macmini = mkMac "macmini";
      };
      # Bootstrap with the same locked nix-darwin used by both machines.
      packages.aarch64-darwin.darwin-rebuild =
        nix-darwin.packages.aarch64-darwin.darwin-rebuild;
    };
}
