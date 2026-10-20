{...}: {
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableFishIntegration = true;
    config.global.warn_timeout = "0s";
  };
}
