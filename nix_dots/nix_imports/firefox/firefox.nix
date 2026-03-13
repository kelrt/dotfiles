{ config, pkgs, ... }:

let
  lock-false = {
    Value = false;
    Status = "locked";
  };
  lock-true = {
    Value = true;
    Status = "locked";
  };
in
{
  # hardware.graphics = {
  #   enable = true;
  #   extraPackages = with pkgs; [
  #     intel-media-driver
  #     vaapiIntel
  #     libvdpau-va-gl
  #   ];
  # };

  environment.variables = {
    MOZ_ENABLE_WAYLAND = "1";
  };

  programs = {
    firefox = {
      enable = true;
      languagePacks = [ "en-US" ];

      /* ---- POLICIES ---- */
      # Check about:policies#documentation for options.
      policies = {
        DisableTelemetry = true;
        DisableFirefoxStudies = true;
        EnableTrackingProtection = {
          Value= true;
          Locked = true;
          Cryptomining = true;
          Fingerprinting = true;
        };
        DisablePocket = true;
        DisableFirefoxAccounts = true;
        DisableAccounts = true;
        DisableFirefoxScreenshots = true;
        OverrideFirstRunPage = "";
        OverridePostUpdatePage = "";
        DontCheckDefaultBrowser = true;
        DisplayBookmarksToolbar = "newtab"; # alternatives: "always" or "newtab"
        DisplayMenuBar = "default-off"; # alternatives: "always", "never" or "default-on"
        SearchBar = "unified"; # alternative: "separate"

        /* ---- EXTENSIONS ---- */
        # Check about:support for extension/add-on ID strings.
        # Valid strings for installation_mode are "allowed", "blocked",
        # "force_installed" and "normal_installed".
        ExtensionSettings = {
          "*".installation_mode = "blocked"; # blocks all addons except the ones specified below
          # uBlock Origin:
          "uBlock0@raymondhill.net" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
            installation_mode = "force_installed";
          };

          # Privacy Badger:
          # "jid1-MnnxcxisBPnSXQ@jetpack" = {
          #   install_url = "https://addons.mozilla.org/firefox/downloads/latest/privacy-badger17/latest.xpi";
          #   installation_mode = "force_installed";
          # };

          # Dark Reader:
          "addon@darkreader.org" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/darkreader/latest.xpi";
            installation_mode = "force_installed";
          };

          # Sidebery extension:
          "{3c078156-979c-498b-8990-85f7987dd929}" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/sidebery/latest.xpi";
            installation_mode = "force_installed";
          };

          # Youtube feed blocker
          "{6782d9f6-c579-40d3-be1b-6b42542d7ba1}" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/block-youtube-feed/latest.xpi";
            installation_mode = "force_installed";
          };

        };
  
        /* ---- PREFERENCES ---- */
        # Check about:config for options.
        Preferences = {
          # Enables loading of custom CSS (userChrome.css & userContent.css)
          "toolkit.legacyUserProfileCustomizations.stylesheets" = {
            Value = true;
            Status = "locked";
          };

          # UI dark theme
          "ui.systemUsesDarkTheme" = { Value = 1; Status = "locked"; };

          # Content blocking
          "browser.contentblocking.category" = { Value = "strict"; Status = "locked"; };

          # Disable unwanted features
          "extensions.pocket.enabled" = lock-false;
          "extensions.screenshots.disabled" = lock-true;
          "browser.topsites.contile.enabled" = lock-false;
          "browser.formfill.enable" = lock-false;
          "browser.search.suggest.enabled" = lock-false;
          "browser.search.suggest.enabled.private" = lock-false;
          "browser.urlbar.suggest.searches" = lock-false;
          "browser.urlbar.showSearchSuggestionsFirst" = lock-false;
          "browser.newtabpage.activity-stream.feeds.section.topstories" = lock-false;
          "browser.newtabpage.activity-stream.feeds.snippets" = lock-false;
          "browser.newtabpage.activity-stream.section.highlights.includePocket" = lock-false;
          "browser.newtabpage.activity-stream.section.highlights.includeBookmarks" = lock-false;
          "browser.newtabpage.activity-stream.section.highlights.includeDownloads" = lock-false;
          "browser.newtabpage.activity-stream.section.highlights.includeVisited" = lock-false;
          "browser.newtabpage.activity-stream.showSponsored" = lock-false;
          "browser.newtabpage.activity-stream.system.showSponsored" = lock-false;
          "browser.newtabpage.activity-stream.showSponsoredTopSites" = lock-false;

          # --- PERFORMANCE TWEAKS --- (cus 32GB goes brrrr)
          # Increase content process limit (more processes, more RAM use, smoother performance with 32GB RAM)
          "dom.ipc.processCount" = {
            Value = 16;
            Status = "locked";
          };

          # Cache more in memory (less CPU-intensive disk reads)
          "browser.cache.memory.capacity" = {
            Value = 131072; # 128 MB
            Status = "locked";
          };

          # Decode images on load to reduce CPU usage while scrolling
          "image.mem.decodeondraw" = {
            Value = false;
            Status = "locked";
          };

          # Enable hardware acceleration if possible (reduces CPU load)
          "layers.acceleration.force-enabled" = {
            Value = true;
            Status = "locked";
          };
        };
      };
    };
  };

  # Activation script snippet: Copy Firefox styling
  # Copies userChrome.css and sidebery.css into Firefox's profile chrome directory
  #cp /home/relz/.dotfiles/programs/firefox/styling/sidebery.css "$profile_dir/chrome/"
  system.activationScripts.copyFirefoxStyles.text = ''
    profile_dir=$(find /home/relz/.mozilla/firefox -maxdepth 1 -type d -name "*.default" | head -n 1)
    if [ -d "$profile_dir" ]; then
      mkdir -p "$profile_dir/chrome"
      cp /home/relz/.dotfiles/nix_imports/firefox/styling/userChrome.css "$profile_dir/chrome/"
      
      echo "✅ Firefox styles copied to $profile_dir/chrome/"
    else
      echo "⚠️ Could not find Firefox profile directory. Skipping style copy."
    fi
  '';
}

