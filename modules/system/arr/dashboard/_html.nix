{
  pkgs,
  lib,
  cfg,
  hostName,
  servicesList,
}: let
  displayTitle =
    if cfg.domain != null
    then cfg.domain
    else hostName;

  indexHtml = pkgs.writeTextDir "index.html" ''
    <!DOCTYPE html>
    <html lang="de">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>${displayTitle} &bull; Media Hub</title>
      <link rel="icon" type="image/svg+xml" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='%23cba6f7'><path d='M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5'/></svg>">
      <link rel="stylesheet" href="style.css">
    </head>
    <body>
      <div class="container">
        <header>
          <div class="brand">
            <h1>
              <svg width="34" height="34" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2">
                <path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5"/>
              </svg>
              ${displayTitle}
            </h1>
            <p>${
      if cfg.domain != null
      then "Zentraler Arr- & Medienserver • ${hostName}"
      else "Dein zentraler Arr- & Medienserver"
    }</p>
          </div>
          <div class="header-meta">
            <div class="badge net-badge" title="Echtzeit-Netzwerkauslastung">
              <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2">
                <polyline points="23 6 13.5 15.5 8.5 10.5 1 18"/>
                <polyline points="17 6 23 6 23 12"/>
              </svg>
              <span id="netSpeed" style="font-family: monospace; font-weight: 700;">↓ ... &bull; ↑ ...</span>
            </div>
            ${
      if cfg.vpn.enable
      then ''
        <div class="badge">
          <span class="badge-dot"></span>
          <span>ProtonVPN</span>
        </div>
      ''
      else ''
        <div class="badge">
          <span class="badge-dot" style="background: var(--ctp-subtext0); box-shadow: none;"></span>
          <span>Host-Netzwerk</span>
        </div>
      ''
    }
            <div class="badge">
              <span>${cfg.dataDir}</span>
            </div>
            ${lib.optionalString (cfg.domain != null) ''
      <div class="badge">
        <span>${cfg.domain}</span>
      </div>
    ''}
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
              <div class="card-status-badge" data-status-for="${s.serviceKey}">
                <span class="status-dot status-loading"></span>
                <span class="status-label">Prüfe...</span>
              </div>
            </div>
            <div class="card-body">
              <h3><a href="http://${s.subdomain}.${hostName}" class="card-title-link" data-subdomain="${s.subdomain}">${s.name}</a></h3>
              <p>${s.desc}</p>
            </div>
          </div>
          <div class="card-actions">
            <a href="http://${s.subdomain}.${hostName}" class="btn-primary" data-subdomain="${s.subdomain}">
              Öffnen &rarr;
            </a>
            <div class="links-row">
              <a href="http://${s.subdomain}.${hostName}" class="pill-link" data-subdomain-pill="${s.subdomain}" title="Subdomain aufrufen">
                ${s.subdomain}.${hostName}
              </a>
              <span class="pill-info" title="Interner Dienst-Port">
                Port ${toString s.port}
              </span>
            </div>
          </div>
        </div>
      '')
      servicesList}
        </div>

        <footer>
          <p>${displayTitle} &bull; Verwaltet über NixOS Flake &bull; Caddy Subdomain Routing</p>
        </footer>
      </div>

      <script src="app.js"></script>
    </body>
    </html>
  '';
in
  pkgs.symlinkJoin {
    name = "arr-dashboard-web";
    paths = [
      indexHtml
      ./_web
    ];
  }
