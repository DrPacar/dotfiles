{lib, ...}: let
  inherit (import ../_lib.nix {inherit lib;}) lua mod;
in {
  wayland.windowManager.hyprland.settings.bind =
    [
      # Focus navigation
      {_args = ["${mod} + Left" (lua ''hl.dsp.focus({ direction = "l" })'')];}
      {_args = ["${mod} + Right" (lua ''hl.dsp.focus({ direction = "r" })'')];}
      {_args = ["${mod} + Up" (lua ''hl.dsp.focus({ direction = "u" })'')];}
      {_args = ["${mod} + Down" (lua ''hl.dsp.focus({ direction = "d" })'')];}
      {_args = ["${mod} + H" (lua ''hl.dsp.focus({ direction = "l" })'')];}
      {_args = ["${mod} + L" (lua ''hl.dsp.focus({ direction = "r" })'')];}
      {_args = ["${mod} + K" (lua ''hl.dsp.focus({ direction = "u" })'')];}
      {_args = ["${mod} + J" (lua ''hl.dsp.focus({ direction = "d" })'')];}

      # Cross-monitor navigation & window moving
      {_args = ["${mod} + O" (lua ''hl.dsp.focus({ monitor = "+1" })'')];}
      {_args = ["${mod} + SHIFT + O" (lua ''hl.dsp.window.move({ monitor = "+1" })'')];}

      # Window movement
      {_args = ["${mod} + SHIFT + Left" (lua ''hl.dsp.window.move({ direction = "l" })'')];}
      {_args = ["${mod} + SHIFT + Right" (lua ''hl.dsp.window.move({ direction = "r" })'')];}
      {_args = ["${mod} + SHIFT + Up" (lua ''hl.dsp.window.move({ direction = "u" })'')];}
      {_args = ["${mod} + SHIFT + Down" (lua ''hl.dsp.window.move({ direction = "d" })'')];}
      {_args = ["${mod} + SHIFT + H" (lua ''hl.dsp.window.move({ direction = "l" })'')];}
      {_args = ["${mod} + SHIFT + L" (lua ''hl.dsp.window.move({ direction = "r" })'')];}
      {_args = ["${mod} + SHIFT + K" (lua ''hl.dsp.window.move({ direction = "u" })'')];}
      {_args = ["${mod} + SHIFT + J" (lua ''hl.dsp.window.move({ direction = "d" })'')];}

      # Special workspace (scratchpad)
      {_args = ["${mod} + S" (lua ''hl.dsp.workspace.toggle_special("magic")'')];}
      {_args = ["${mod} + CTRL + S" (lua ''hl.dsp.window.move({ workspace = "special:magic" })'')];}

      # Workspace mouse scrolling
      {_args = ["${mod} + mouse_down" (lua ''hl.dsp.focus({ workspace = "e+1" })'')];}
      {_args = ["${mod} + mouse_up" (lua ''hl.dsp.focus({ workspace = "e-1" })'')];}
    ]
    # Workspaces 1..10 switch and move
    ++ builtins.concatLists (builtins.genList (
        i: let
          ws = toString (
            if i == 9
            then 10
            else i + 1
          );
          key = toString (
            if i == 9
            then 0
            else i + 1
          );
        in [
          {_args = ["${mod} + ${key}" (lua "hl.dsp.focus({ workspace = ${ws} })")];}
          {_args = ["${mod} + SHIFT + ${key}" (lua "hl.dsp.window.move({ workspace = ${ws} })")];}
        ]
      )
      10);
}
