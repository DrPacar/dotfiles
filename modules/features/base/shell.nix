{ ... }:
{
  flake.homeModules.shell =
    { pkgs, lib, ... }:
    {
      programs.fish = {
        enable = true;

        interactiveShellInit = ''
          set fish_greeting

          fish_vi_key_bindings
          set -g fish_key_bindings fish_vi_key_bindings
          set -U fish_cursor_insert block
          bind -M insert -m default vj cancel repaint-mode
          set -g fish_sequence_key_delay_ms 200
        '';
      };
    };
}