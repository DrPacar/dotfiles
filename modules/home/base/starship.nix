{pkgs, ...}: {
  programs.starship = {
    enable = true;
    enableFishIntegration = true;

    settings = {
      palette = "tokyonight";

      palettes.tokyonight = {
        bg = "#1a1b26";
        fg = "#c0caf5";
        blue = "#7aa2f7";
        cyan = "#7dcfff";
        purple = "#bb9af7";
        red = "#f7768e";
        yellow = "#e0af68";
        green = "#9ece6a";
        orange = "#ff9e64";
        comment = "#565f89";
      };

      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
        vimcmd_symbol = "[❮](bold blue)";
      };

      directory = {
        style = "bold blue";
        truncation_length = 3;
        truncate_to_repo = true;
        read_only = " 󰌾";
        home_symbol = "~";
      };

      git_branch = {
        symbol = " ";
        style = "bold purple";
        format = "[$symbol$branch]($style) ";
      };

      git_status = {
        style = "bold red";
        format = "([\\[$all_status$ahead_behind\\]]($style) )";
        ahead = "⇡";
        behind = "⇣";
        diverged = "⇕";
        untracked = "?";
        modified = "!";
        staged = "+";
        renamed = "»";
        deleted = "✘";
      };

      nix_shell = {
        symbol = " ";
        style = "bold cyan";
        format = "via [$symbol$state( \\($name\\))]($style) ";
        impure_msg = "impure";
        pure_msg = "pure";
      };

      cmd_duration = {
        min_time = 2000;
        format = "took [$duration]($style) ";
        style = "bold yellow";
      };

      hostname = {
        ssh_only = true;
        format = "on [$hostname]($style) ";
        style = "bold cyan";
      };
    };
  };
}
