{lib, ...}: let
  inherit (import ../_lib.nix {inherit lib;}) lua mod;
in {
  wayland.windowManager.hyprland.settings.bind = [
    # Screenshots via Noctalia native suite
    {_args = ["Print" (lua ''hl.dsp.exec_cmd("noctalia msg screenshot-fullscreen")'')];}
    {_args = ["${mod} + SHIFT + S" (lua ''hl.dsp.exec_cmd("noctalia msg screenshot-region")'')];}
    {_args = ["${mod} + SHIFT + Print" (lua ''hl.dsp.exec_cmd("noctalia msg screenshot-annotate")'')];}

    # Audio volume & mute
    {
      _args = [
        "XF86AudioRaiseVolume"
        (lua ''hl.dsp.exec_cmd("noctalia msg volume-up")'')
        {
          locked = true;
          repeating = true;
        }
      ];
    }
    {
      _args = [
        "XF86AudioLowerVolume"
        (lua ''hl.dsp.exec_cmd("noctalia msg volume-down")'')
        {
          locked = true;
          repeating = true;
        }
      ];
    }
    {_args = ["XF86AudioMute" (lua ''hl.dsp.exec_cmd("noctalia msg volume-mute")'') {locked = true;}];}
    {_args = ["XF86AudioMicMute" (lua ''hl.dsp.exec_cmd("noctalia msg mic-mute")'') {locked = true;}];}

    # Brightness
    {
      _args = [
        "XF86MonBrightnessUp"
        (lua ''hl.dsp.exec_cmd("noctalia msg brightness-up")'')
        {
          locked = true;
          repeating = true;
        }
      ];
    }
    {
      _args = [
        "XF86MonBrightnessDown"
        (lua ''hl.dsp.exec_cmd("noctalia msg brightness-down")'')
        {
          locked = true;
          repeating = true;
        }
      ];
    }

    # Media player controls
    {_args = ["XF86AudioPlay" (lua ''hl.dsp.exec_cmd("noctalia msg media play-pause")'') {locked = true;}];}
    {_args = ["XF86AudioNext" (lua ''hl.dsp.exec_cmd("noctalia msg media next")'') {locked = true;}];}
    {_args = ["XF86AudioPrev" (lua ''hl.dsp.exec_cmd("noctalia msg media previous")'') {locked = true;}];}
  ];
}
