{
  description = "One repository for macOS, NixOS, and Linux with Nix";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nix-darwin, home-manager, ... }:
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
      mkLinuxHome = system: home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.${system};
        modules = [
          ./modules/home.nix
          ./hosts/linux.nix
          {
            home.username = people.linux;
            home.homeDirectory = "/home/${people.linux}";
            targets.genericLinux.enable = true;
          }
        ];
      };
    in {
      lib.usernames = people;
      darwinConfigurations = {
        macbook = mkMac "macbook";
        macmini = mkMac "macmini";
      };
      homeConfigurations = {
        linux-x86_64 = mkLinuxHome "x86_64-linux";
        linux-aarch64 = mkLinuxHome "aarch64-linux";
      };
      nixosModules.default = {
        imports = [ home-manager.nixosModules.home-manager ./modules/nixos.nix ];
        _module.args.username = people.nixos;
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.users.${people.nixos} = import ./modules/home.nix;
      };
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        modules = [ self.nixosModules.default ./hosts/nixos/default.nix ];
      };
      # Evaluation fixture, never a deployment target. Real disk/boot settings
      # must come from the user's already working NixOS installation.
      checks.x86_64-linux.nixos-module = (nixpkgs.lib.nixosSystem {
        modules = [ self.nixosModules.default ./tests/nixos-fixture.nix ];
      }).config.system.build.toplevel;
      # Bootstrap with the same locked nix-darwin used by both machines.
      packages.aarch64-darwin.darwin-rebuild =
        nix-darwin.packages.aarch64-darwin.darwin-rebuild;
    };
}
