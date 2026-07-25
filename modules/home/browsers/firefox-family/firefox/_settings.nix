{
  # ==========================================
  # 1. UI, LAYOUT & GENERAL PREFERENCES
  # ==========================================
  "browser.tabs.inTitlebar" = 1;
  "sidebar.position_start" = false;
  "browser.compactmode.show" = true;
  "browser.shell.checkDefaultBrowser" = false;
  "browser.tabs.warnOnClose" = false;
  "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
  "browser.ctrlTab.sortByRecentlyUsed" = true;
  "media.videocontrols.picture-in-picture.enable-when-switching-tabs.enabled" = true;
  "browser.bookmarks.openInTabClosesMenu" = false;
  "browser.menu.showViewImageInfo" = true;
  "findbar.highlightAll" = true;
  "layout.word_select.eat_space_to_next_word" = false;

  # Fullscreen Notice Adjustments
  "full-screen-api.warning.timeout" = 0;
  "full-screen-api.transition-duration.enter" = "0 0";
  "full-screen-api.transition-duration.leave" = "0 0";

  # Translations & Media Codecs
  "browser.translations.enable" = false;
  "browser.translations.automaticallyPopup" = false;
  "media.gmp-widevinecdm.enabled" = true;
  "media.eme.enabled" = true;

  # Devtools
  "devtools.jsonview.enabled" = true;
  "devtools.netmonitor.persistlog" = true;
  "devtools.cache.disabled" = true;


  # ==========================================
  # 2. NEW TAB PAGE & PINNED SITES
  # ==========================================
  "browser.newtabpage.activity-stream.topSitesRows" = 2;
  "browser.newtabpage.activity-stream.default.sites" = "";
  "browser.newtabpage.activity-stream.showSponsored" = false;
  "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
  "browser.newtabpage.activity-stream.showSponsoredCheckboxes" = false;
  "browser.newtabpage.activity-stream.feeds.section.topstories" = false;

  "browser.newtabpage.pinned" = builtins.toJSON [
    { url = "https://github.com/DrPacar?tab=repositories"; label = "GitHub"; }
    { url = "https://claude.ai"; label = "Claude"; }
    { url = "https://gemini.google.com"; label = "Gemini"; }
    { url = "https://chatgpt.com"; label = "ChatGPT"; }
    { url = "https://oesterreich.gv.at"; label = "ID"; }
    { url = "https://finanzonline.bmf.gv.at"; label = "FinanzOnline"; }
    { url = "https://www.e-brief.at/fe/deliveries"; label = "Post-Briefkasten"; }
    { url = "https://web.whatsapp.com/"; label = "WhatsApp"; }
    { url = "https://mail.google.com/"; label = "Gmail"; }
    { url = "https://www.reddit.com"; label = "Reddit"; }
    { url = "https://www.netflix.com"; label = "Netflix"; }
    { url = "https://youtube.com"; label = "Youtube"; }
    { url = "https://twitch.tv"; label = "Twitch"; }
    { url = "https://www.amazon.de"; label = "Amazon"; }
    { url = "https://dash.cloudflare.com"; label = "Cloudflare"; }
    { url = "https://www.chess.com/play/online"; label = "Chess.com"; }
    { url = "https://lichess.org/study"; label = "Lichess Studies"; }
    { url = "https://chesstempo.com"; label = "Chesstempo"; }
    { url = "https://www.tuwien.at/"; label = "TU Wien"; }
  ];


  # ==========================================
  # 3. PASSWORDS, AUTOFILL & CREDENTIALS
  # ==========================================
  "signon.rememberSignons" = false;
  "signon.autofillForms" = false;
  "signon.generation.enabled" = false;
  "signon.formlessCapture.enabled" = false;
  "signon.privateBrowsingCapture.enabled" = false;
  "signon.firefoxRelay.feature" = "";
  "signon.management.page.breach-alerts.enabled" = true;
  "extensions.formautofill.creditCards.enabled" = false;
  "extensions.formautofill.addresses.enabled" = false;
  "browser.formfill.enable" = false;


  # ==========================================
  # 4. FASTFOX (PERFORMANCE & CACHE)
  # ==========================================
  "gfx.content.skia-font-cache-size" = 32;
  "gfx.canvas.accelerated.cache-items" = 32768;
  "gfx.canvas.accelerated.cache-size" = 4096;
  "webgl.max-size" = 16384;

  # Disk & Memory Cache
  "browser.cache.disk.enable" = false;
  "browser.cache.memory.capacity" = 131072;
  "browser.cache.memory.max_entry_size" = 20480;
  "browser.sessionhistory.max_total_viewers" = 4;
  "browser.sessionstore.max_tabs_undo" = 10;
  "browser.sessionstore.interval" = 60000;
  "browser.privatebrowsing.forceMediaMemoryCache" = true;

  # Media Cache
  "media.memory_cache_max_size" = 262144;
  "media.memory_caches_combined_limit_kb" = 1048576;
  "media.cache_readahead_limit" = 600;
  "media.cache_resume_threshold" = 300;

  # Image Cache
  "image.cache.size" = 10485760;
  "image.mem.decode_bytes_at_a_time" = 65536;

  # Network & Connections
  "network.http.max-connections" = 1800;
  "network.http.max-persistent-connections-per-server" = 10;
  "network.http.max-urgent-start-excessive-connections-per-host" = 5;
  "network.http.request.max-start-delay" = 5;
  "network.http.pacing.requests.enabled" = false;
  "network.dnsCacheEntries" = 10000;
  "network.dnsCacheExpiration" = 3600;
  "network.ssl_tokens_cache_capacity" = 10240;

  # Speculative Loading (Disabled)
  "network.http.speculative-parallel-limit" = 0;
  "network.dns.disablePrefetch" = true;
  "network.dns.disablePrefetchFromHTTPS" = true;
  "browser.urlbar.speculativeConnect.enabled" = false;
  "browser.places.speculativeConnect.enabled" = false;
  "network.prefetch-next" = false;
  "network.predictor.enabled" = false;


  # ==========================================
  # 5. SECUREFOX (SECURITY, PRIVACY & HARDENING)
  # ==========================================
  "browser.contentblocking.category" = "strict";
  "privacy.trackingprotection.allow_list.baseline.enabled" = true;
  "privacy.globalprivacycontrol.enabled" = true;
  "browser.download.start_downloads_in_tmp_dir" = true;
  "browser.helperApps.deleteTempFileOnExit" = true;
  "browser.uitour.enabled" = false;

  # OCSP, SSL/TLS & Certificates
  "security.OCSP.enabled" = 0;
  "security.csp.reporting.enabled" = false;
  "security.ssl.treat_unsafe_negotiation_as_broken" = true;
  "browser.xul.error_pages.expert_bad_cert" = true;
  "security.tls.enable_0rtt_data" = false;

  # Shutdown & Sanitizing
  "privacy.history.custom" = true;
  "browser.privatebrowsing.resetPBM.enabled" = true;

  # Search, URL Bar & Headers
  "browser.urlbar.trimHttps" = true;
  "browser.urlbar.untrimOnUserInteraction.featureGate" = true;
  "browser.search.separatePrivateDefault.ui.enabled" = true;
  "browser.search.suggest.enabled" = false;
  "browser.urlbar.quicksuggest.enabled" = false;
  "browser.urlbar.groupLabels.enabled" = false;
  "browser.urlbar.trending.featureGate" = false;
  "network.IDN_show_punycode" = true;
  "network.http.referer.XOriginTrimmingPolicy" = 2;
  "network.auth.subresource-http-auth-allow" = 1;
  "editor.truncate_user_pastes" = false;

  # Mixed Content, PDF & Safe Browsing
  "security.mixed_content.block_display_content" = true;
  "pdfjs.enableScripting" = false;
  "browser.safebrowsing.downloads.remote.enabled" = false;

  # Containers & Extensions Scopes
  "privacy.userContext.enabled" = true;
  "privacy.userContext.ui.enabled" = true;
  "extensions.enabledScopes" = 5;


  # ==========================================
  # 6. PESKYFOX (MOZILLA BLOAT & TELEMETRY REMOVAL)
  # ==========================================
  # Telemetry & Diagnostics
  "toolkit.telemetry.enabled" = false;
  "toolkit.telemetry.unified" = false;
  "toolkit.telemetry.server" = "data:,";
  "toolkit.telemetry.archive.enabled" = false;
  "toolkit.telemetry.newProfilePing.enabled" = false;
  "toolkit.telemetry.shutdownPingSender.enabled" = false;
  "toolkit.telemetry.updatePing.enabled" = false;
  "toolkit.telemetry.bhrPing.enabled" = false;
  "toolkit.telemetry.firstShutdownPing.enabled" = false;
  "toolkit.telemetry.coverage.opt-out" = true;
  "toolkit.coverage.opt-out" = true;
  "toolkit.coverage.endpoint.base" = "";
  "datareporting.policy.dataSubmissionEnabled" = false;
  "datareporting.healthreport.uploadEnabled" = false;
  "datareporting.usage.uploadEnabled" = false;
  "browser.newtabpage.activity-stream.feeds.telemetry" = false;
  "browser.newtabpage.activity-stream.telemetry" = false;

  # Experiments & Crash Reports
  "app.shield.optoutstudies.enabled" = false;
  "app.normandy.enabled" = false;
  "app.normandy.api_url" = "";
  "breakpad.reportURL" = "";
  "browser.tabs.crashReporting.sendReport" = false;

  # Mozilla UI Promos & Recommendations
  "browser.privatebrowsing.vpnpromourl" = "";
  "extensions.getAddons.showPane" = false;
  "extensions.htmlaboutaddons.recommendations.enabled" = false;
  "browser.discovery.enabled" = false;
  "browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons" = false;
  "browser.newtabpage.activity-stream.asrouter.userprefs.cfr.features" = false;
  "browser.preferences.moreFromMozilla" = false;
  "browser.aboutConfig.showWarning" = false;
  "browser.aboutwelcome.enabled" = false;
  "browser.profiles.enabled" = true;
  "extensions.pocket.enabled" = false;

  # AI Features (Disabled)
  "browser.ml.enable" = false;
  "browser.ml.chat.enabled" = false;
  "browser.ml.chat.menu" = false;
  "browser.tabs.groups.smart.enabled" = false;
  "browser.ml.linkPreview.enabled" = false;

  # Permissions & Defaults
  "permissions.default.desktop-notification" = 2;
  "permissions.default.geo" = 2;
  "geo.provider.network.url" = "https://beacondb.net/v1/geolocate";
  "browser.search.update" = false;
  "permissions.manager.defaultsUrl" = "";
  "extensions.getAddons.cache.enabled" = false;

  # Downloads & PDFs
  "browser.download.manager.addToRecentDocs" = false;
  "browser.download.open_pdf_attachments_inline" = true;
}
