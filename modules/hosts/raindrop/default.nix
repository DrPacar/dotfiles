{ self, inputs, ... }:
{
  flake.nixosConfigurations.raindrop = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = { inherit self inputs; };
    modules = [
      self.nixosModules.raindropConfiguration

      # Integriert Home-Manager direkt in den NixOS-System-Build
      inputs.home-manager.nixosModules.home-manager
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.extraSpecialArgs = { inherit self inputs; };
        home-manager.users.luka = self.homeModules.raindropHome;
      }
    ];
  };
}