{lib, ...}: let
  inherit (import ../_lib.nix {inherit lib;}) lua mod;
in {
  wayland.windowManager.hyprland.settings.bind = [
    # Core Applications
    {_args = ["${mod} + Return" (lua ''hl.dsp.exec_cmd("ghostty")'')];}
    {_args = ["${mod} + E" (lua ''hl.dsp.exec_cmd("nautilus")'')];}
    {_args = ["${mod} + B" (lua ''hl.dsp.exec_cmd("zen-beta")'')];}

    # Noctalia Shell Surfaces & Actions
    {_args = ["${mod} + Space" (lua ''hl.dsp.exec_cmd("noctalia msg panel-toggle launcher")'')];}
    {_args = ["${mod} + period" (lua ''hl.dsp.exec_cmd("noctalia msg panel-toggle launcher /emo")'')];}
    {_args = ["${mod} + slash" (lua ''hl.dsp.exec_cmd("noctalia msg panel-toggle launcher /calc")'')];}
    {_args = ["${mod} + V" (lua ''hl.dsp.exec_cmd("noctalia msg panel-toggle clipboard")'')];}
    {_args = ["${mod} + N" (lua ''hl.dsp.exec_cmd("noctalia msg panel-toggle control-center")'')];}
    {_args = ["${mod} + comma" (lua ''hl.dsp.exec_cmd("noctalia msg settings-toggle")'')];}
    {_args = ["ALT + Tab" (lua ''hl.dsp.exec_cmd("noctalia msg window-switcher")'')];}
    {_args = ["${mod} + L" (lua ''hl.dsp.exec_cmd("noctalia msg session lock")'')];}
    {_args = ["${mod} + Escape" (lua ''hl.dsp.exec_cmd("noctalia msg panel-toggle session")'')];}
    {_args = ["${mod} + W" (lua ''hl.dsp.exec_cmd("noctalia msg wallpaper-random")'')];}
  ];
}
