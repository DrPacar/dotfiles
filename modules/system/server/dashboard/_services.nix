{
  lib,
  config,
}: let
  serverCfg = config.server;
  arrCfg = config.server.arr or {};
  arrEnabled = arrCfg.enable or false;
in
  # Uptime Kuma (Monitoring & Status)
  (lib.optional (serverCfg.enable && (serverCfg.uptime-kuma.enable or false)) {
    name = "Uptime Kuma";
    serviceKey = "uptime-kuma";
    subdomain = serverCfg.uptime-kuma.subdomain;
    domain = serverCfg.domain;
    aliases = ["status"];
    port = serverCfg.uptime-kuma.port;
    category = "Monitoring & Status";
    desc = "Uptime- und Service-Monitoring mit Alarmierung und Status-Seite.";
    color = "#5cdb95";
    icon = ''<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="22 12 18 12 15 21 9 3 6 12 2 12"/></svg>'';
  })
  # Beszel (Hardware- & System-Ressourcen)
  ++ (lib.optional (serverCfg.enable && (serverCfg.beszel.enable or false)) {
    name = "Beszel";
    serviceKey = "beszel";
    subdomain = serverCfg.beszel.subdomain;
    domain = serverCfg.domain;
    aliases = ["system"];
    port = serverCfg.beszel.port;
    category = "Monitoring & Status";
    desc = "Leichtgewichtiges System-, CPU-, RAM- und Festplatten-Monitoring.";
    color = "#f59e0b";
    icon = ''<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="4" y="4" width="16" height="16" rx="2"/><rect x="9" y="9" width="6" height="6"/><line x1="9" y1="1" x2="9" y2="4"/><line x1="15" y1="1" x2="15" y2="4"/><line x1="9" y1="20" x2="9" y2="23"/><line x1="15" y1="20" x2="15" y2="23"/><line x1="20" y1="9" x2="23" y2="9"/><line x1="20" y1="14" x2="23" y2="14"/><line x1="1" y1="9" x2="4" y2="9"/><line x1="1" y1="14" x2="4" y2="14"/></svg>'';
  })
  # Ntfy (Benachrichtigungs-Server)
  ++ (lib.optional (serverCfg.enable && (serverCfg.notify.enable or false)) {
    name = "Benachrichtigungen";
    serviceKey = "notify";
    subdomain = serverCfg.notify.subdomain;
    domain = serverCfg.domain;
    aliases = ["notify" "alerts"];
    port = serverCfg.notify.port;
    category = "Monitoring & Status";
    desc = "Selbst gehosteter Push-Benachrichtigungsdienst und Live Web-App.";
    color = "#3b82f6";
    icon = ''<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/></svg>'';
  })
  # AdGuard Home (Netzwerk & Sicherheit)
  ++ (lib.optional (serverCfg.enable && serverCfg.adguard.enable) {
    name = "AdGuard Home";
    serviceKey = "adguard";
    subdomain = serverCfg.adguard.subdomain;
    domain = serverCfg.domain;
    port = serverCfg.adguard.port;
    category = "Netzwerk & Sicherheit";
    desc = "Netzwerkweiter DNS-Werbeblocker und Tracking-Schutz.";
    color = "#68bc71";
    icon = ''<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><path d="m9 12 2 2 4-4"/></svg>'';
  })
  # Vaultwarden (Passwort-Manager)
  ++ (lib.optional (serverCfg.enable && (serverCfg.vaultwarden.enable or false)) {
    name = "Vaultwarden";
    serviceKey = "vaultwarden";
    subdomain = serverCfg.vaultwarden.subdomain;
    domain = serverCfg.domain;
    aliases = ["vaultwarden" "bitwarden"];
    port = serverCfg.vaultwarden.port;
    category = "Sicherheit & Passwörter";
    desc = "Sicherer, selbst gehosteter Passwort-Manager (Bitwarden-kompatibel).";
    color = "#175ddc";
    icon = ''<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><rect x="9" y="11" width="6" height="5" rx="1"/><path d="M10 11V9a2 2 0 1 1 4 0v2"/></svg>'';
  })
  # Immich (Fotos & Videos)
  ++ (lib.optional (serverCfg.enable && (serverCfg.immich.enable or false)) {
    name = "Immich";
    serviceKey = "immich";
    subdomain = serverCfg.immich.subdomain;
    domain = serverCfg.domain;
    aliases = ["photos"];
    port = serverCfg.immich.port;
    category = "Fotos & Medien";
    desc = "Selbst gehostetes Backup und Verwaltung von Fotos und Videos.";
    color = "#4285F4";
    icon = ''<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="18" height="18" rx="2" ry="2"/><circle cx="8.5" cy="8.5" r="1.5"/><polyline points="21 15 16 10 5 21"/></svg>'';
  })
  # Paperless-ngx (Dokumente & Archiv)
  ++ (lib.optional (serverCfg.enable && (serverCfg.paperless.enable or false)) {
    name = "Paperless-ngx";
    serviceKey = "paperless";
    subdomain = serverCfg.paperless.subdomain;
    domain = serverCfg.domain;
    aliases = ["docs"];
    port = serverCfg.paperless.port;
    category = "Dokumente & Archiv";
    desc = "Dokumentenmanagement mit automatischer OCR-Texterkennung und Volltextsuche.";
    color = "#107c41";
    icon = ''<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/><polyline points="10 9 9 9 8 9"/></svg>'';
  })
  # Arr Stack (Medien)
  ++ (lib.optional (arrEnabled && arrCfg.seerr.enable) {
    name = "Seerr";
    serviceKey = "seerr";
    subdomain = arrCfg.seerr.subdomain;
    domain = arrCfg.domain;
    aliases = ["jellyseerr"];
    port = arrCfg.seerr.port;
    category = "Entdecken & Anfragen";
    desc = "Filme und Serien suchen, anfragen und verwalten.";
    color = "#cba6f7";
    icon = ''<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M19.82 2H4.18C2.97 2 2 2.97 2 4.18v15.64C2 21.03 2.97 22 4.18 22h15.64c1.21 0 2.18-.97 2.18-2.18V4.18C22 2.97 21.03 2 19.82 2zM7 2v20M17 2v20M2 12h20M2 7h5M2 17h5M17 17h5M17 7h5"/></svg>'';
  })
  ++ (lib.optional (arrEnabled && arrCfg.jellyfin.enable) {
    name = "Jellyfin";
    serviceKey = "jellyfin";
    subdomain = arrCfg.jellyfin.subdomain;
    domain = arrCfg.domain;
    port = arrCfg.jellyfin.port;
    category = "Streaming & Mediathek";
    desc = "Medienplayer mit Intel QuickSync Hardware-Transcoding.";
    color = "#89b4fa";
    icon = ''<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2.25a.75.75 0 0 1 .65.375l8.25 14.25a.75.75 0 0 1-.65 1.125h-4.5a.75.75 0 0 1-.65-.375L12 12.375l-3.1 5.25a.75.75 0 0 1-.65.375h-4.5a.75.75 0 0 1-.65-1.125l8.25-14.25A.75.75 0 0 1 12 2.25z"/></svg>'';
  })
  ++ (lib.optional (arrEnabled && arrCfg.radarr.enable) {
    name = "Radarr";
    serviceKey = "radarr";
    subdomain = arrCfg.radarr.subdomain;
    domain = arrCfg.domain;
    port = arrCfg.radarr.port;
    category = "Filme";
    desc = "Automatische Suche und Qualitätsverwaltung für Spielfilme.";
    color = "#f9e2af";
    icon = ''<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="2" y="2" width="20" height="20" rx="2.18" ry="2.18"/><line x1="7" y1="2" x2="7" y2="22"/><line x1="17" y1="2" x2="17" y2="22"/><line x1="2" y1="12" x2="22" y2="12"/><line x1="2" y1="7" x2="7" y2="7"/><line x1="2" y1="17" x2="7" y2="17"/><line x1="17" y1="17" x2="22" y2="17"/><line x1="17" y1="7" x2="22" y2="7"/></svg>'';
  })
  ++ (lib.optional (arrEnabled && arrCfg.sonarr.enable) {
    name = "Sonarr";
    serviceKey = "sonarr";
    subdomain = arrCfg.sonarr.subdomain;
    domain = arrCfg.domain;
    port = arrCfg.sonarr.port;
    category = "Serien";
    desc = "Tracking und automatische Downloads für TV-Serien und Anime.";
    color = "#94e2d5";
    icon = ''<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="2" y="7" width="20" height="15" rx="2" ry="2"/><polyline points="17 2 12 7 7 2"/></svg>'';
  })
  ++ (lib.optional (arrEnabled && arrCfg.sonarr.enable && arrCfg.sonarr.anime.enable) {
    name = "Sonarr Anime";
    serviceKey = "sonarr-anime";
    subdomain = arrCfg.sonarr.anime.subdomain;
    domain = arrCfg.domain;
    aliases = ["sonarr-anime"];
    port = arrCfg.sonarr.anime.port;
    category = "Anime";
    desc = "Spezialisierte Anime-Instanz mit Nyaa.si Integration.";
    color = "#f38ba8";
    icon = ''<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 4h16M2 8h20M6 8v12M18 8v12M10 12h4"/></svg>'';
  })
  ++ (lib.optional (arrEnabled && arrCfg.prowlarr.enable) {
    name = "Prowlarr";
    serviceKey = "prowlarr";
    subdomain = arrCfg.prowlarr.subdomain;
    domain = arrCfg.domain;
    port = arrCfg.prowlarr.port;
    category = "Indexer & Tracker";
    desc = "Zentrale Verwaltung aller Torrent-Tracker und FlareSolverr.";
    color = "#fab387";
    icon = ''<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="M12 2a14.5 14.5 0 0 0 0 20 14.5 14.5 0 0 0 0-20"/><path d="M2 12h20"/></svg>'';
  })
  ++ (lib.optional (arrEnabled && arrCfg.qbittorrent.enable) {
    name = "qBittorrent";
    serviceKey = "qbittorrent";
    subdomain = arrCfg.qbittorrent.subdomain;
    domain = arrCfg.domain;
    aliases = ["qbittorrent"];
    port = arrCfg.qbittorrent.webuiPort;
    category = "Download-Client";
    desc = "BitTorrent-Client im isolierten ProtonVPN-Tunnel.";
    color = "#89dceb";
    icon = ''<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>'';
  })
  ++ (lib.optional (arrEnabled && arrCfg.bazarr.enable) {
    name = "Bazarr";
    serviceKey = "bazarr";
    subdomain = arrCfg.bazarr.subdomain;
    domain = arrCfg.domain;
    port = arrCfg.bazarr.port;
    category = "Untertitel";
    desc = "Automatischer Abgleich und Download passender Untertitel für Filme, Serien und Anime.";
    color = "#a6e3a1";
    icon = ''<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/><line x1="8" y1="9" x2="16" y2="9"/><line x1="8" y1="13" x2="13" y2="13"/></svg>'';
  })
  ++ (lib.optional (arrEnabled && arrCfg.bazarr.enable && arrCfg.bazarr.anime.enable) {
    name = "Bazarr Anime";
    serviceKey = "bazarr-anime";
    subdomain = arrCfg.bazarr.anime.subdomain;
    domain = arrCfg.domain;
    port = arrCfg.bazarr.anime.port;
    category = "Untertitel";
    desc = "Automatischer Abgleich und Download von Anime-Untertiteln.";
    color = "#cba6f7";
    icon = ''<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/><line x1="8" y1="9" x2="16" y2="9"/><line x1="8" y1="13" x2="13" y2="13"/></svg>'';
  })
  ++ (lib.optional (arrEnabled && arrCfg.flaresolverr.enable) {
    name = "FlareSolverr";
    serviceKey = "flaresolverr";
    subdomain = arrCfg.flaresolverr.subdomain;
    domain = arrCfg.domain;
    port = arrCfg.flaresolverr.port;
    category = "Indexer Proxy";
    desc = "Bypass-Proxy für Cloudflare-geschützte Indexer.";
    color = "#f2cdcd";
    icon = ''<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>'';
  })
