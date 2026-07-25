{
  # ==========================================
  # 1. ZEN-SPECIFIC SETTINGS
  # ==========================================
  "browser.toolbars.bookmarks.visibility" = "always";
  "zen.workspaces.continue-where-left-off" = true;
  "zen.welcome-screen.seen" = true;
  "browser.startup.homepage_override.mstone" = "ignore";
  "zen.watermark.enabled" = false;
  "zen.workspaces.separate-essentials" = false;
  "zen.workspaces.hide-default-container-indicator" = false;
  "extensions.formautofill.creditCards.enabled" = false;
  "extensions.formautofill.addresses.enabled" = false;

  # ==========================================
  # 2. OVERRIDES & GENERAL PREFERENCES
  # ==========================================
  "browser.ctrlTab.sortByRecentlyUsed" = true;
  "media.videocontrols.picture-in-picture.enable-when-switching-tabs.enabled" = true;
  "browser.shell.checkDefaultBrowser" = false;
  "browser.translations.automaticallyPopup" = false;
  "browser.translations.enable" = false;
  "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
  "media.gmp-widevinecdm.enabled" = true;
  "media.eme.enabled" = true;
  "browser.tabs.warnOnClose" = false;
  "full-screen-api.warning.timeout" = 0;
  "browser.compactmode.show" = true;

  # Devtools
  "devtools.jsonview.enabled" = true;
  "devtools.netmonitor.persistlog" = true;
  "devtools.cache.disabled" = true;

  # ==========================================
  # 3. FASTFOX (PERFORMANCE & CACHE)
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

  # Speculative Loading
  "network.http.speculative-parallel-limit" = 0;
  "network.dns.disablePrefetch" = true;
  "network.dns.disablePrefetchFromHTTPS" = true;
  "browser.urlbar.speculativeConnect.enabled" = false;
  "browser.places.speculativeConnect.enabled" = false;
  "network.prefetch-next" = false;
  "network.predictor.enabled" = false;

  # ==========================================
  # 4. SECUREFOX (SECURITY & HARDENING)
  # ==========================================
  "browser.contentblocking.category" = "strict";
  "privacy.trackingprotection.allow_list.baseline.enabled" = true;
  "browser.download.start_downloads_in_tmp_dir" = true;
  "browser.helperApps.deleteTempFileOnExit" = true;
  "browser.uitour.enabled" = false;
  "privacy.globalprivacycontrol.enabled" = true;

  # OCSP & Certs/ HPKP
  "security.OCSP.enabled" = 0;
  "security.csp.reporting.enabled" = false;

  # SSL/TLS
  "security.ssl.treat_unsafe_negotiation_as_broken" = true;
  "browser.xul.error_pages.expert_bad_cert" = true;
  "security.tls.enable_0rtt_data" = false;

  # Shutdown & Sanitizing
  "privacy.history.custom" = true;
  "browser.privatebrowsing.resetPBM.enabled" = true;

  # Search & URL Bar
  "browser.urlbar.trimHttps" = true;
  "browser.urlbar.untrimOnUserInteraction.featureGate" = true;
  "browser.search.separatePrivateDefault.ui.enabled" = true;
  "browser.search.suggest.enabled" = false;
  "browser.urlbar.quicksuggest.enabled" = false;
  "browser.urlbar.groupLabels.enabled" = false;
  "browser.formfill.enable" = false;
  "network.IDN_show_punycode" = true;

  # Passwords & Autofill
  "signon.rememberSignons" = false;
  "signon.autofillForms" = false;
  "signon.generation.enabled" = false;
  "signon.firefoxRelay.feature" = "";
  "signon.management.page.breach-alerts.enabled" = true;
  "signon.formlessCapture.enabled" = false;
  "signon.privateBrowsingCapture.enabled" = false;
  "network.auth.subresource-http-auth-allow" = 1;
  "editor.truncate_user_pastes" = false;

  # Mixed Content & Cross Site
  "security.mixed_content.block_display_content" = true;
  "pdfjs.enableScripting" = false;

  # Extensions
  "extensions.enabledScopes" = 5;

  # Headers / Referers
  "network.http.referer.XOriginTrimmingPolicy" = 2;

  # Containers
  "privacy.userContext.enabled" = true;
  "privacy.userContext.ui.enabled" = true;

  # Safe Browsing
  "browser.safebrowsing.downloads.remote.enabled" = false;

  # Mozilla & Telemetry blocks
  "permissions.default.desktop-notification" = 2;
  "permissions.default.geo" = 2;
  "geo.provider.network.url" = "https://beacondb.net/v1/geolocate";
  "browser.search.update" = false;
  "permissions.manager.defaultsUrl" = "";
  "extensions.getAddons.cache.enabled" = false;

  "datareporting.policy.dataSubmissionEnabled" = false;
  "datareporting.healthreport.uploadEnabled" = false;
  "toolkit.telemetry.unified" = false;
  "toolkit.telemetry.enabled" = false;
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
  "browser.newtabpage.activity-stream.feeds.telemetry" = false;
  "browser.newtabpage.activity-stream.telemetry" = false;
  "datareporting.usage.uploadEnabled" = false;

  # Experiments & Crash Reports
  "app.shield.optoutstudies.enabled" = false;
  "app.normandy.enabled" = false;
  "app.normandy.api_url" = "";
  "breakpad.reportURL" = "";
  "browser.tabs.crashReporting.sendReport" = false;

  # ==========================================
  # 5. PESKYFOX & UI CLEANUP
  # ==========================================
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

  # AI Features
  "browser.ml.enable" = false;
  "browser.ml.chat.enabled" = false;
  "browser.ml.chat.menu" = false;
  "browser.tabs.groups.smart.enabled" = false;
  "browser.ml.linkPreview.enabled" = false;

  # Fullscreen Transition / URL Bar / New Tab
  "full-screen-api.transition-duration.enter" = "0 0";
  "full-screen-api.transition-duration.leave" = "0 0";
  "browser.urlbar.trending.featureGate" = false;

  "browser.newtabpage.activity-stream.default.sites" = "";
  "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
  "browser.newtabpage.activity-stream.feeds.section.topstories" = false;
  "browser.newtabpage.activity-stream.showSponsored" = false;
  "browser.newtabpage.activity-stream.showSponsoredCheckboxes" = false;

  # Downloads & Tabs
  "browser.download.manager.addToRecentDocs" = false;
  "browser.download.open_pdf_attachments_inline" = true;
  "browser.bookmarks.openInTabClosesMenu" = false;
  "browser.menu.showViewImageInfo" = true;
  "findbar.highlightAll" = true;
  "layout.word_select.eat_space_to_next_word" = false;
}
