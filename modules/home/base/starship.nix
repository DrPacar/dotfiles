{ pkgs, ... }:

{
  programs.starship = {
    enable = true;

    # Auto-integrate with Fish shell (also enables for bash/zsh if needed)
    enableFishIntegration = true;

    # Settings map directly to starship.toml key-value pairs
    settings = {
      # Replace default format to keep it prompt-responsive and clean
      format = ''
        $os$directory$git_branch$git_status$nix_shell
        $character'';

      # -------------------------------------------------------------
      # Nix Shell Indicator (Crucial for NixOS / Nix users)
      # -------------------------------------------------------------
      nix_shell = {
        symbol = "❄️ ";
        format = "via [$symbol$state( \\($name\\))]($style) ";
        style = "bold cyan";
        impure_msg = "[impure](bold red)";
        pure_msg = "[pure](bold green)";
        unknown_msg = "";
      };

      # -------------------------------------------------------------
      # Directory & Pathing
      # -------------------------------------------------------------
      directory = {
        truncation_length = 3;
        truncation_symbol = "…/";
        style = "bold blue";
        read_only = " 🔒";
      };

      # -------------------------------------------------------------
      # Git Integration
      # -------------------------------------------------------------
      git_branch = {
        symbol = " ";
        style = "bold purple";
        format = "on [$symbol$branch]($style) ";
      };

      git_status = {
        format = "([\\[$all_status$ahead_behind\\]]($style) )";
        style = "bold red";
        conflicted = "=";
        ahead = "⇡\${count}";
        behind = "⇣\${count}";
        diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";
        untracked = "?\${count}";
        stashed = "\\$";
        modified = "!\${count}";
        staged = "+\${count}";
        renamed = "»";
        deleted = "✘";
      };

      # -------------------------------------------------------------
      # Execution & Prompt Symbols
      # -------------------------------------------------------------
      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
        vimcmd_symbol = "[❮](bold green)";
      };

      # Show execution time for commands taking longer than 2 seconds
      cmd_duration = {
        min_time = 2000;
        format = "took [$duration]($style) ";
        style = "bold yellow";
      };

      # Disable noisy modules you might not need in prompt
      package.enabled = false;
      aws.enabled = false;
      gcloud.enabled = false;
    };
  };
}
