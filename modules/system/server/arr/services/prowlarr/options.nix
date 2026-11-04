{lib, ...}: let
  inherit (lib) mkOption types;
in {
  options.server.arr.prowlarr = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Prowlarr indexer manager and proxy synchronizer.";
    };

    port = mkOption {
      type = types.port;
      default = 9696;
      description = "Port for Prowlarr web interface.";
    };

    subdomain = mkOption {
      type = types.str;
      default = "prowlarr";
      description = "Subdomain name for Prowlarr reverse proxy routing.";
    };

    indexers = mkOption {
      type = types.listOf types.attrs;
      default = [];
      example = [
        {name = "Nyaa.si";}
        {name = "1337x";}
        {name = "The Pirate Bay";}
      ];
      description = "Declarative list of Prowlarr indexers managed by Nixflix. Any indexer not listed here will be removed on rebuild.";
    };
  };
}
