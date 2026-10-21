{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkOption types;
  cfg = config.arr;

  hostName = config.networking.hostName;
  tailscaleFqdn =
    if cfg.tailscaleDomain != null
    then "${hostName}.${cfg.tailscaleDomain}"
    else null;

  # Subdomain definitions: [ { name, subdomain, port, icon, category, desc, color } ]
  # Dynamically filtered to only include services that are currently enabled
  servicesList =
    (lib.optional cfg.seerr.enable {
      name = "Seerr";
      subdomain = "seerr";
      port = cfg.seerr.port;
      category = "Entdecken & Anfragen";
      desc = "Filme und Serien suchen, anfragen und verwalten.";
      color = "#cba6f7";
      tag = "Requests";
      icon = ''<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M19.82 2H4.18C2.97 2 2 2.97 2 4.18v15.64C2 21.03 2.97 22 4.18 22h15.64c1.21 0 2.18-.97 2.18-2.18V4.18C22 2.97 21.03 2 19.82 2zM7 2v20M17 2v20M2 12h20M2 7h5M2 17h5M17 17h5M17 7h5"/></svg>'';
    })
    ++ (lib.optional cfg.jellyfin.enable {
      name = "Jellyfin";
      subdomain = "jellyfin";
      port = cfg.jellyfin.port;
      category = "Streaming & Mediathek";
      desc = "Medienplayer mit Intel QuickSync Hardware-Transcoding.";
      color = "#89b4fa";
      tag = "Streaming";
      icon = ''<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2.25a.75.75 0 0 1 .65.375l8.25 14.25a.75.75 0 0 1-.65 1.125h-4.5a.75.75 0 0 1-.65-.375L12 12.375l-3.1 5.25a.75.75 0 0 1-.65.375h-4.5a.75.75 0 0 1-.65-1.125l8.25-14.25A.75.75 0 0 1 12 2.25z"/></svg>'';
    })
    ++ (lib.optional cfg.radarr.enable {
      name = "Radarr";
      subdomain = "radarr";
      port = cfg.radarr.port;
      category = "Filme";
      desc = "Automatische Suche und Qualitätsverwaltung für Spielfilme.";
      color = "#f9e2af";
      tag = "Movies";
      icon = ''<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="2" y="2" width="20" height="20" rx="2.18" ry="2.18"/><line x1="7" y1="2" x2="7" y2="22"/><line x1="17" y1="2" x2="17" y2="22"/><line x1="2" y1="12" x2="22" y2="12"/><line x1="2" y1="7" x2="7" y2="7"/><line x1="2" y1="17" x2="7" y2="17"/><line x1="17" y1="17" x2="22" y2="17"/><line x1="17" y1="7" x2="22" y2="7"/></svg>'';
    })
    ++ (lib.optional cfg.sonarr.enable {
      name = "Sonarr";
      subdomain = "sonarr";
      port = cfg.sonarr.port;
      category = "Serien";
      desc = "Tracking und automatische Downloads für TV-Serien.";
      color = "#94e2d5";
      tag = "TV Shows";
      icon = ''<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="2" y="7" width="20" height="15" rx="2" ry="2"/><polyline points="17 2 12 7 7 2"/></svg>'';
    })
    ++ (lib.optional (cfg.sonarr.enable && cfg.sonarr.anime.enable) {
      name = "Sonarr Anime";
      subdomain = "anime";
      aliases = ["sonarr-anime"];
      port = cfg.sonarr.anime.port;
      category = "Anime";
      desc = "Spezialisierte Anime-Instanz mit Nyaa.si Integration.";
      color = "#f38ba8";
      tag = "Anime";
      icon = ''<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 4h16M2 8h20M6 8v12M18 8v12M10 12h4"/></svg>'';
    })
    ++ (lib.optional cfg.prowlarr.enable {
      name = "Prowlarr";
      subdomain = "prowlarr";
      port = cfg.prowlarr.port;
      category = "Indexer & Tracker";
      desc = "Zentrale Verwaltung aller Torrent-Tracker und FlareSolverr.";
      color = "#fab387";
      tag = "Indexers";
      icon = ''<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="M12 2a14.5 14.5 0 0 0 0 20 14.5 14.5 0 0 0 0-20"/><path d="M2 12h20"/></svg>'';
    })
    ++ (lib.optional cfg.qbittorrent.enable {
      name = "qBittorrent";
      subdomain = "qbit";
      aliases = ["qbittorrent"];
      port = cfg.qbittorrent.webuiPort;
      category = "Download-Client";
      desc = "BitTorrent-Client im isolierten ProtonVPN-Tunnel.";
      color = "#89dceb";
      tag = "VPN Protected";
      icon = ''<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>'';
    })
    ++ (lib.optional cfg.bazarr.enable {
      name = "Bazarr";
      subdomain = "bazarr";
      port = cfg.bazarr.port;
      category = "Untertitel";
      desc = "Automatischer Abgleich und Download passender Untertitel.";
      color = "#a6e3a1";
      tag = "Subtitles";
      icon = ''<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/><line x1="8" y1="9" x2="16" y2="9"/><line x1="8" y1="13" x2="13" y2="13"/></svg>'';
    });

  # Generate static HTML/CSS/JS dashboard
  dashboardHtml = pkgs.writeTextDir "index.html" ''
    <!DOCTYPE html>
    <html lang="de">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>${hostName} &bull; Media Hub</title>
      <link rel="icon" type="image/svg+xml" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='%23cba6f7'><path d='M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5'/></svg>">
      <style>
        :root {
          --ctp-base: #1e1e2e;
          --ctp-mantle: #181825;
          --ctp-crust: #11111b;
          --ctp-surface0: #313244;
          --ctp-surface1: #45475a;
          --ctp-text: #cdd6f4;
          --ctp-subtext0: #a6adc8;
          --ctp-subtext1: #bac2de;
          --ctp-mauve: #cba6f7;
          --ctp-blue: #89b4fa;
          --ctp-green: #a6e3a1;
          --ctp-peach: #fab387;
          --ctp-red: #f38ba8;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
          background: radial-gradient(circle at 50% 0%, #2b2b42 0%, var(--ctp-crust) 75%);
          color: var(--ctp-text);
          min-height: 100vh;
          padding: 2.5rem 1.5rem;
          display: flex;
          flex-direction: column;
          align-items: center;
        }
        .container {
          max-width: 1200px;
          width: 100%;
        }
        header {
          display: flex;
          justify-content: space-between;
          align-items: flex-end;
          flex-wrap: wrap;
          gap: 1.5rem;
          margin-bottom: 2rem;
          border-bottom: 1px solid var(--ctp-surface0);
          padding-bottom: 1.5rem;
        }
        .brand h1 {
          font-size: 2.4rem;
          font-weight: 800;
          letter-spacing: -0.5px;
          background: linear-gradient(135deg, var(--ctp-mauve), var(--ctp-blue));
          -webkit-background-clip: text;
          -webkit-text-fill-color: transparent;
          display: flex;
          align-items: center;
          gap: 0.75rem;
        }
        .brand p {
          color: var(--ctp-subtext0);
          font-size: 1rem;
          margin-top: 0.25rem;
        }
        .header-meta {
          display: flex;
          align-items: center;
          gap: 1rem;
          flex-wrap: wrap;
        }
        .badge {
          display: inline-flex;
          align-items: center;
          gap: 0.4rem;
          background: rgba(49, 50, 68, 0.6);
          backdrop-filter: blur(8px);
          padding: 0.4rem 0.8rem;
          border-radius: 9999px;
          font-size: 0.82rem;
          font-weight: 600;
          border: 1px solid var(--ctp-surface1);
        }
        .badge-dot {
          width: 8px;
          height: 8px;
          border-radius: 50%;
          background: var(--ctp-green);
          box-shadow: 0 0 8px var(--ctp-green);
        }
        .clock {
          font-family: monospace;
          font-size: 1.1rem;
          color: var(--ctp-subtext1);
        }
        .search-container {
          margin-bottom: 2rem;
          position: relative;
        }
        .search-input {
          width: 100%;
          background: var(--ctp-mantle);
          border: 1px solid var(--ctp-surface0);
          border-radius: 12px;
          padding: 0.9rem 1.25rem;
          font-size: 1rem;
          color: var(--ctp-text);
          transition: all 0.2s ease;
          outline: none;
        }
        .search-input:focus {
          border-color: var(--ctp-mauve);
          box-shadow: 0 0 0 3px rgba(203, 166, 247, 0.2);
        }
        .grid {
          display: grid;
          grid-template-columns: repeat(auto-fill, minmax(270px, 1fr));
          gap: 1.5rem;
        }
        .card {
          background: rgba(24, 24, 37, 0.7);
          backdrop-filter: blur(12px);
          border: 1px solid var(--ctp-surface0);
          border-radius: 16px;
          padding: 1.5rem;
          display: flex;
          flex-direction: column;
          justify-content: space-between;
          transition: all 0.25s cubic-bezier(0.16, 1, 0.3, 1);
          position: relative;
          overflow: hidden;
        }
        .card:hover {
          transform: translateY(-4px);
          border-color: var(--card-color, var(--ctp-mauve));
          box-shadow: 0 12px 30px -10px rgba(0, 0, 0, 0.5);
        }
        .card-header {
          display: flex;
          justify-content: space-between;
          align-items: flex-start;
          margin-bottom: 1rem;
        }
        .card-icon {
          width: 48px;
          height: 48px;
          border-radius: 12px;
          background: rgba(49, 50, 68, 0.5);
          display: flex;
          align-items: center;
          justify-content: center;
          color: var(--card-color, var(--ctp-mauve));
        }
        .card-icon svg {
          width: 26px;
          height: 26px;
        }
        .card-tag {
          font-size: 0.72rem;
          font-weight: 700;
          text-transform: uppercase;
          letter-spacing: 0.5px;
          padding: 0.2rem 0.6rem;
          border-radius: 6px;
          background: rgba(49, 50, 68, 0.5);
          color: var(--card-color, var(--ctp-text));
        }
        .card-body h3 {
          font-size: 1.3rem;
          font-weight: 700;
          margin-bottom: 0.35rem;
          color: var(--ctp-text);
        }
        .card-body p {
          font-size: 0.88rem;
          color: var(--ctp-subtext0);
          line-height: 1.45;
          margin-bottom: 1.25rem;
        }
        .card-actions {
          display: flex;
          flex-direction: column;
          gap: 0.65rem;
        }
        .btn-primary {
          display: flex;
          align-items: center;
          justify-content: center;
          gap: 0.5rem;
          width: 100%;
          background: var(--card-color, var(--ctp-mauve));
          color: var(--ctp-crust);
          font-weight: 700;
          font-size: 0.95rem;
          padding: 0.7rem;
          border-radius: 10px;
          text-decoration: none;
          transition: opacity 0.2s ease;
          border: none;
          cursor: pointer;
        }
        .btn-primary:hover {
          opacity: 0.9;
        }
        .links-row {
          display: flex;
          gap: 0.5rem;
          font-size: 0.78rem;
        }
        .pill-link {
          flex: 1;
          display: inline-flex;
          align-items: center;
          justify-content: center;
          padding: 0.3rem 0.5rem;
          background: var(--ctp-surface0);
          color: var(--ctp-subtext1);
          border-radius: 6px;
          text-decoration: none;
          transition: all 0.15s ease;
          white-space: nowrap;
          overflow: hidden;
          text-overflow: ellipsis;
        }
        .pill-link:hover {
          background: var(--ctp-surface1);
          color: var(--ctp-text);
        }
        footer {
          margin-top: 3.5rem;
          text-align: center;
          color: var(--ctp-subtext0);
          font-size: 0.85rem;
        }
        footer a { color: var(--ctp-mauve); text-decoration: none; }
      </style>
    </head>
    <body>
      <div class="container">
        <header>
          <div class="brand">
            <h1>
              <svg width="34" height="34" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2">
                <path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5"/>
              </svg>
              ${hostName}
            </h1>
            <p>Dein zentraler Arr- & Medienserver</p>
          </div>
          <div class="header-meta">
            <div class="badge">
              <span class="badge-dot"></span>
              <span>ProtonVPN Aktiv</span>
            </div>
            <div class="badge">
              <span>Speicher: /arr_data</span>
            </div>
            <div class="clock" id="clock">00:00:00</div>
          </div>
        </header>

        <div class="search-container">
          <input type="text" class="search-input" id="search" placeholder="Dienst suchen... (Tippe '/' zum Suchen)">
        </div>

        <div class="grid" id="servicesGrid">
          ${lib.concatMapStringsSep "\n" (s: ''
        <div class="card" style="--card-color: ${s.color};" data-search="${lib.toLower s.name} ${lib.toLower s.category} ${lib.toLower s.desc}">
          <div>
            <div class="card-header">
              <div class="card-icon">
                ${s.icon}
              </div>
              <span class="card-tag">${s.tag}</span>
            </div>
            <div class="card-body">
              <h3>${s.name}</h3>
              <p>${s.desc}</p>
            </div>
          </div>
          <div class="card-actions">
            <a href="http://${s.subdomain}.${hostName}" class="btn-primary" data-subdomain="${s.subdomain}" data-port="${toString s.port}">
              Öffnen &rarr;
            </a>
            <div class="links-row">
              <a href="http://${s.subdomain}.${hostName}" class="pill-link" title="Subdomain">
                ${s.subdomain}.${hostName}
              </a>
              <a href="http://${hostName}:${toString s.port}" class="pill-link" data-port-link="${toString s.port}" title="Direkter Port">
                :${toString s.port}
              </a>
            </div>
          </div>
        </div>
      '')
      servicesList}
        </div>

        <footer>
          <p>${hostName} &bull; Verwaltet über NixOS Flake &bull; 100% WireGuard VPN isoliert</p>
        </footer>
      </div>

      <script>
        // Update Live Clock
        function updateClock() {
          const now = new Date();
          document.getElementById('clock').textContent = now.toTimeString().split(' ')[0];
        }
        setInterval(updateClock, 1000);
        updateClock();

        // Smart link resolution: adjust links depending on how user reached the dashboard
        const currentHost = window.location.hostname;
        const isTailscale = currentHost.includes('.ts.net') || currentHost.startsWith('100.');

        document.querySelectorAll('[data-subdomain]').forEach(el => {
          const sub = el.getAttribute('data-subdomain');
          const port = el.getAttribute('data-port');

          if (isTailscale) {
            // Over Tailscale MagicDNS, link directly to the port on the Tailscale hostname
            el.href = 'http://' + currentHost + ':' + port;
          } else {
            // Locally, link to the subdomain
            el.href = 'http://' + sub + '.' + currentHost.replace(/:\d+$/, "");
          }
        });

        document.querySelectorAll('[data-port-link]').forEach(el => {
          const port = el.getAttribute('data-port-link');
          el.href = 'http://' + currentHost + ':' + port;
        });

        // Instant Live Filter
        const searchInput = document.getElementById('search');
        const cards = document.querySelectorAll('.card');

        searchInput.addEventListener('input', (e) => {
          const q = e.target.value.toLowerCase().trim();
          cards.forEach(card => {
            const text = card.getAttribute('data-search');
            card.style.display = text.includes(q) ? 'flex' : 'none';
          });
        });

        // Keyboard Shortcut '/'
        window.addEventListener('keydown', (e) => {
          if (e.key === '/' && document.activeElement !== searchInput) {
            e.preventDefault();
            searchInput.focus();
          }
        });
      </script>
    </body>
    </html>
  '';

  # Helper to generate virtual host definitions for Caddy (strictly plain HTTP to avoid ACME / TLS handshake errors)
  mkSubdomainVhost = s: {
    "http://${s.subdomain}.${hostName}${lib.optionalString (tailscaleFqdn != null) ", http://${s.subdomain}.${tailscaleFqdn}"}" = {
      extraConfig = ''
        reverse_proxy 127.0.0.1:${toString s.port} {
          header_up Host {host}
          header_up X-Real-IP {remote_host}
          header_up X-Forwarded-For {remote_host}
          header_up X-Forwarded-Proto {scheme}
        }
      '';
    };
  };

  # Flatten all subdomain vhosts
  allSubdomainVhosts = lib.foldl' lib.mergeAttrs {} (map mkSubdomainVhost servicesList);

  # Additional aliases (e.g. anime.lighthouse -> sonarr-anime)
  extraAliasVhosts =
    lib.optionalAttrs (cfg.sonarr.enable && cfg.sonarr.anime.enable) {
      "http://sonarr-anime.${hostName}${lib.optionalString (tailscaleFqdn != null) ", http://sonarr-anime.${tailscaleFqdn}"}" = {
        extraConfig = ''
          reverse_proxy 127.0.0.1:${toString cfg.sonarr.anime.port}
        '';
      };
    }
    // lib.optionalAttrs cfg.qbittorrent.enable {
      "http://qbittorrent.${hostName}${lib.optionalString (tailscaleFqdn != null) ", http://qbittorrent.${tailscaleFqdn}"}" = {
        extraConfig = ''
          reverse_proxy 127.0.0.1:${toString cfg.qbittorrent.webuiPort}
        '';
      };
    };

  # Main Landing Page Virtual Host
  mainDashboardVhost = {
    "${lib.optionalString (tailscaleFqdn != null) "http://${tailscaleFqdn}, "}http://${hostName}, http://localhost, http://127.0.0.1" = {
      extraConfig = ''
        root * ${dashboardHtml}
        file_server
      '';
    };
  };

  # Generate /etc/hosts entries for all subdomains
  allSubdomainNames =
    (map (s: "${s.subdomain}.${hostName}") servicesList)
    ++ lib.optionals (tailscaleFqdn != null) (map (s: "${s.subdomain}.${tailscaleFqdn}") servicesList)
    ++ lib.optionals (cfg.sonarr.enable && cfg.sonarr.anime.enable) (
      ["sonarr-anime.${hostName}"]
      ++ lib.optional (tailscaleFqdn != null) "sonarr-anime.${tailscaleFqdn}"
    )
    ++ lib.optionals cfg.qbittorrent.enable (
      ["qbittorrent.${hostName}"]
      ++ lib.optional (tailscaleFqdn != null) "qbittorrent.${tailscaleFqdn}"
    );
in {
  options.arr.dashboard = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Caddy reverse proxy with subdomains and a unified landing page dashboard.";
    };
  };

  config = mkIf (cfg.enable && cfg.dashboard.enable) {
    # Open HTTP (80) in firewall
    networking.firewall.allowedTCPPorts = [80];

    # Map all subdomains to localhost in /etc/hosts
    networking.hosts."127.0.0.1" = allSubdomainNames;

    # Caddy Reverse Proxy
    services.caddy = {
      enable = true;
      globalConfig = ''
        auto_https off
      '';
      virtualHosts = lib.mkMerge [
        mainDashboardVhost
        allSubdomainVhosts
        extraAliasVhosts
      ];
    };
  };
}
