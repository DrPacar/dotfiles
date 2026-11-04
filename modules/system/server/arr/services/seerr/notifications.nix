{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.server.arr;
in {
  config = mkIf (cfg.enable && cfg.seerr.enable && (config.server.notify.enable or false)) {
    systemd.services.seerr-notifications = {
      description = "Configure Seerr ntfy webhook notifications";
      after = ["seerr-setup.service" "seerr.service"];
      requires = ["seerr-setup.service" "seerr.service"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Slice = "arr.slice";
      };

      script = let
        notifyPort = toString (config.server.notify.port or 2586);
        notifyTopic = config.server.notify.topic or "media";
        seerrDomain =
          if cfg.domain != null
          then "https://${cfg.seerr.subdomain}.${cfg.domain}"
          else "http://${config.networking.hostName}:${toString cfg.seerr.port}";
      in ''
        for i in $(seq 1 30); do
          if [ -f /run/seerr/api-key-header ]; then
            break
          fi
          sleep 1
        done

        ${pkgs.curl}/bin/curl -s -X POST \
          --header @"/run/seerr/api-key-header" \
          -H "Content-Type: application/json" \
          -d '{"enabled":true,"types":130,"options":{"webhookUrl":"http://127.0.0.1:${notifyPort}","jsonPayload":"{\"topic\":\"${notifyTopic}\",\"title\":\"🍿 Jellyseerr: {{subject}}\",\"message\":\"{{message}}\",\"click\":\"${seerrDomain}/requests\",\"actions\":[{\"action\":\"view\",\"label\":\"In Jellyseerr öffnen\",\"url\":\"${seerrDomain}/requests\"}]}"}}' \
          "http://127.0.0.1:${toString cfg.seerr.port}/api/v1/settings/notifications/webhook"
      '';
    };
  };
}
