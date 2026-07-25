{ exclude ? [] }:
let
  extensions = {
    "adguardadblocker@adguard.com" = {
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/adguard-adblocker/latest.xpi";
      installation_mode = "force_installed";
      default_area = "menupanel";
    };
    "{22b0eca1-8c02-4c0d-a5d7-6604ddd9836e}" = {
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/nicothin-space/latest.xpi";
      installation_mode = "force_installed";
      default_area = "menupanel";
    };
    "{446900e4-71c2-419f-a6a7-df9c091e268b}" = {
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/bitwarden-password-manager/latest.xpi";
      installation_mode = "force_installed";
      default_area = "navbar";
    };
    "{74145f27-f039-47ce-a470-a662b129930a}" = {
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/clearurls/latest.xpi";
      installation_mode = "force_installed";
      default_area = "menupanel";
    };
    "{762f9885-5a13-4abd-9c77-433dcd38b8fd}" = {
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/return-youtube-dislikes/latest.xpi";
      installation_mode = "force_installed";
      default_area = "menupanel";
    };
    "sponsorBlocker@ajay.app" = {
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/sponsorblock/latest.xpi";
      installation_mode = "force_installed";
      default_area = "menupanel";
    };
#    "addon@darkreader.org" = {
#      install_url = "https://addons.mozilla.org/firefox/downloads/latest/darkreader/latest.xpi";
#      installation_mode = "force_installed";
#      default_area = "menupanel";
#    };
    "{3c078156-979c-498b-8990-85f7987dd929}" = {
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/sidebery/latest.xpi";
      installation_mode = "force_installed";
      default_area = "navbar";
    };
    "{c2c003ee-bd69-42a2-b0e9-6f34222cb046}" = {
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/auto-tab-discard/latest.xpi";
      installation_mode = "force_installed";
      default_area = "menupanel";
    };
    "{b86e4813-687a-43e6-ab65-0bde4ab75758}" = {
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/localcdn-fork-of-decentraleyes/latest.xpi";
      installation_mode = "force_installed";
      default_area = "menupanel";
    };
    "{531906d3-e22f-4a6c-a102-8057b88a1a63}" = {
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/single-file/latest.xpi";
      installation_mode = "force_installed";
      default_area = "menupanel";
    };
  };
in
{
  ExtensionSettings = builtins.removeAttrs extensions exclude;
}
