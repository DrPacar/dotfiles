{...}: {
  programs.wlogout = {
    enable = false; # Handled by Noctalia
    layout = [
      {
        label = "lock";
        action = "hyprlock";
        text = "󰌾\nLock (l)";
        keybind = "l";
      }
      {
        label = "logout";
        action = "hyprctl dispatch exit";
        text = "󰍃\nLogout (e)";
        keybind = "e";
      }
      {
        label = "suspend";
        action = "systemctl suspend";
        text = "󰒲\nSuspend (u)";
        keybind = "u";
      }
      {
        label = "reboot";
        action = "systemctl reboot";
        text = "󰜉\nReboot (r)";
        keybind = "r";
      }
      {
        label = "shutdown";
        action = "systemctl poweroff";
        text = "󰐥\nShutdown (s)";
        keybind = "s";
      }
    ];

    style = ''
      * {
        background-image: none;
        box-shadow: none;
        font-family: "JetBrainsMono Nerd Font", monospace;
      }

      window {
        background-color: rgba(22, 22, 30, 0.85);
      }

      button {
        border-radius: 16px;
        border: 2px solid #414868;
        color: #c0caf5;
        background-color: #1a1b26;
        margin: 12px;
        font-size: 16px;
        font-weight: bold;
        transition: all 0.2s ease-in-out;
      }

      button:hover {
        background-color: #24283b;
        border-color: #7aa2f7;
        color: #7aa2f7;
      }

      button:focus {
        background-color: #3b4261;
        border-color: #bb9af7;
        color: #bb9af7;
      }
    '';
  };
}
