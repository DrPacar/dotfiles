{lib, ...}: let
  inherit (import ../_lib.nix {inherit lib;}) lua mod;
in {
  wayland.windowManager.hyprland.settings.bind = [
    # Window management & lifecycle
    {_args = ["${mod} + Q" (lua "hl.dsp.window.close()")];}
    {_args = ["${mod} + SHIFT + Q" (lua "hl.dsp.window.kill()")];}
    {_args = ["${mod} + SHIFT + Space" (lua ''hl.dsp.window.float({ action = "toggle" })'')];}
    {_args = ["${mod} + SHIFT + C" (lua "hl.dsp.window.center()")];}
    {_args = ["${mod} + F" (lua "hl.dsp.window.fullscreen({ mode = 0 })")];}
    {_args = ["${mod} + M" (lua "hl.dsp.window.fullscreen({ mode = 1 })")];}
    {_args = ["${mod} + P" (lua "hl.dsp.window.pin()")];} # Pin floating window across all workspaces
    {_args = ["${mod} + SHIFT + P" (lua "hl.dsp.window.pin()")];}
    {_args = ["${mod} + T" (lua ''hl.dsp.layout("togglesplit")'')];}

    # Fast native window focus cycling
    {_args = ["ALT + Tab" (lua "hl.dsp.window.cycle_next()")];}
    {_args = ["ALT + SHIFT + Tab" (lua "hl.dsp.window.cycle_next({ prev = true })")];}

    # Group management & natural directional tab cycling (3 keys max)
    {_args = ["${mod} + G" (lua "hl.dsp.group.toggle()")];}
    {_args = ["${mod} + SHIFT + G" (lua "hl.dsp.window.move({ out_of_group = true })")];}
    {_args = ["${mod} + ALT + Left" (lua "hl.dsp.group.prev()")];}
    {_args = ["${mod} + ALT + Right" (lua "hl.dsp.group.next()")];}
    {_args = ["${mod} + ALT + H" (lua "hl.dsp.group.prev()")];}
    {_args = ["${mod} + ALT + L" (lua "hl.dsp.group.next()")];}

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
