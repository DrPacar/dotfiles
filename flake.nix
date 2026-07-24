{
  description = "Pacar's dotfiles";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
    nixpkgs-stable.url = "https://channels.nixos.org/nixos-26.05/nixexprs.tar.xz";
    systems.url = "github:nix-systems/default-linux"; 
    
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ flake-parts, nixpkgs, home-manager, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];

      flake = {
        nixosConfigurations = 
          let
            hostDir = ./configurations/hosts;
            hosts = builtins.attrNames (builtins.readDir hostDir);
            lib = nixpkgs.lib;

            mkMod = import ./lib/mod.nix { inherit lib; } ./.;
            modSys  = mkMod "modules/system";
            modHome = mkMod "modules/home";
          in
          nixpkgs.lib.genAttrs hosts (host: nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            specialArgs = {
              inherit inputs;
              mod = modSys;
            };

            modules = [
              (hostDir + "/${host}/configuration.nix")
              
              home-manager.nixosModules.home-manager
              {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.extraSpecialArgs = {
                  inherit inputs; 
                  mod = modHome;
                };
              }
            ];
          });
      };
    };
}
