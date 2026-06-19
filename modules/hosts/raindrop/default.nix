{ self, inputs, ... }:
{
  flake.nixosConfigurations.raindrop = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = { inherit self inputs; };
    modules = [
      self.nixosModules.raindropConfiguration
    ];
  };

  flake.homeConfigurations.luka = inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = import inputs.nixpkgs { system = "x86_64-linux"; };
    extraSpecialArgs = { inherit self inputs; }; # Überlebenswichtig für deine Modul-Struktur!
    modules = [
      self.homeModules.raindropHome
    ];
  };
}