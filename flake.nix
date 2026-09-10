{
  description = "Pacar's dotfiles";

  nixConfig = {
    extra-substituters = ["https://noctalia.cachix.org"];
    extra-trusted-public-keys = ["noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="];
  };

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

    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak";

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs = {
        home-manager.follows = "home-manager";
        nixpkgs.follows = "nixpkgs";
      };
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    git-hooks-nix = {
      url = "github:cachix/git-hooks.nix";
      inputs = {
        flake-compat.follows = "";
        nixpkgs.follows = "nixpkgs";
      };
    };

    noctalia = {
      url = "github:noctalia-dev/noctalia/cachix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    nixpkgs,
    flake-parts,
    home-manager,
    zen-browser,
    treefmt-nix,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux"];

      imports = [
        ./modules/flake/treefmt.nix
        ./modules/flake/checks.nix
        ./modules/flake/shell.nix
      ];

      flake = {
        nixosConfigurations = let
          hostDir = ./configurations/hosts;
          hosts = builtins.attrNames (
            lib.filterAttrs
            (_name: type: type == "directory")
            (builtins.readDir hostDir)
          );
          lib = nixpkgs.lib;

          mkMod = import ./lib/mod.nix {inherit lib;} ./.;
          modSys = mkMod "modules/system";
          modHome = mkMod "modules/home";
        in
          nixpkgs.lib.genAttrs hosts (host:
            nixpkgs.lib.nixosSystem {
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
                  home-manager.backupFileExtension = "backup";
                  home-manager.sharedModules = [
                    inputs.nix-flatpak.homeManagerModules.nix-flatpak
                    inputs.noctalia.homeModules.default
                  ];

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
