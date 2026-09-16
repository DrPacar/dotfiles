{lib, ...}: let
  inherit (import ../_lib.nix {inherit lib;}) lua mod;
in {
  wayland.windowManager.hyprland.settings.bind = [
    # Window management
    {_args = ["${mod} + Q" (lua "hl.dsp.window.close()")];}
    {_args = ["${mod} + SHIFT + Space" (lua ''hl.dsp.window.float({ action = "toggle" })'')];}
    {_args = ["${mod} + F" (lua "hl.dsp.window.fullscreen({ mode = 0 })")];}
    {_args = ["${mod} + P" (lua "hl.dsp.window.pseudo()")];}
    {_args = ["${mod} + T" (lua ''hl.dsp.layout("togglesplit")'')];}
    {_args = ["${mod} + G" (lua "hl.dsp.group.toggle()")];}
    {_args = ["${mod} + ALT + Tab" (lua "hl.dsp.group.next()")];}

    # Keyboard window resizing (repeatable when held)
    {_args = ["${mod} + CTRL + Right" (lua "hl.dsp.window.resize({ x = 25, y = 0, relative = true })") {repeating = true;}];}
    {_args = ["${mod} + CTRL + Left" (lua "hl.dsp.window.resize({ x = -25, y = 0, relative = true })") {repeating = true;}];}
    {_args = ["${mod} + CTRL + Up" (lua "hl.dsp.window.resize({ x = 0, y = -25, relative = true })") {repeating = true;}];}
    {_args = ["${mod} + CTRL + Down" (lua "hl.dsp.window.resize({ x = 0, y = 25, relative = true })") {repeating = true;}];}
    {_args = ["${mod} + CTRL + L" (lua "hl.dsp.window.resize({ x = 25, y = 0, relative = true })") {repeating = true;}];}
    {_args = ["${mod} + CTRL + H" (lua "hl.dsp.window.resize({ x = -25, y = 0, relative = true })") {repeating = true;}];}
    {_args = ["${mod} + CTRL + K" (lua "hl.dsp.window.resize({ x = 0, y = -25, relative = true })") {repeating = true;}];}
    {_args = ["${mod} + CTRL + J" (lua "hl.dsp.window.resize({ x = 0, y = 25, relative = true })") {repeating = true;}];}

    # Mouse dragging and resizing
    {_args = ["${mod} + mouse:272" (lua "hl.dsp.window.drag()") {mouse = true;}];}
    {_args = ["${mod} + mouse:273" (lua "hl.dsp.window.resize()") {mouse = true;}];}
  ];
}
