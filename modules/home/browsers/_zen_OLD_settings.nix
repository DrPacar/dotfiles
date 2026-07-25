{ pkgs, ... }:
{
  settings = {
    "browser.toolbars.bookmarks.visibility" = "always";
    "zen.workspaces.continue-where-left-off" = true;
    "zen.welcome-screen.seen" = true;
    "browser.startup.homepage_override.mstone" = "ignore";
    "zen.watermark.enabled" = false;
    "zen.workspaces.separate-essentials" = false;
    "zen.workspaces.hide-default-container-indicator" = false;
    "extensions.formautofill.creditCards.enabled" = false;
    "extensions.formautofill.addresses.enabled" = false;
  };
}
