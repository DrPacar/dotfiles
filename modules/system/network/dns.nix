{...}: {
  services.resolved = {
    enable = true;
    # Allow single-label hostnames (e.g. "haven") to resolve via unicast DNS (AdGuard)
    settings.Resolve.ResolveUnicastSingleLabel = "yes";
  };
}
