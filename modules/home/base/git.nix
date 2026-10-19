{
  osConfig,
  pkgs,
  ...
}: {
  programs.git = {
    enable = true;
    lfs.enable = true;
    ignores = [
      ".DS_Store"
      "Thumbs.db"
      "*.swp"
      "*.swo"
      ".vscode/"
      ".idea/"
      ".direnv/"
      "result"
      "result-*"
    ];

    signing = {
      format = "ssh";
      key = "~/.ssh/${osConfig.networking.hostName}.pub";
      signByDefault = true;
      allowedSigners = ''
        lukapacar06@gmail.com namespaces="git" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII9ahMh0Tcn58e2gANWRpyECO/zGO/At2tk7eD70KGxl luka@lighthouse
        lukapacar06@gmail.com namespaces="git" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEK+FcUtXmUuiDkdlye5eDnlWipnPwzQmBFVGogWvUlM luka@raindrop
      '';
    };

    settings = {
      user.name = "DrPacar";
      user.email = "lukapacar06@gmail.com";

      alias = {
        st = "status -sb";
        co = "checkout";
        sw = "switch";
        cb = "checkout -b";
        br = "branch";
        cm = "commit -m";
        ca = "commit --amend";
        unstage = "restore --staged";
        undo = "reset --soft HEAD~1";
        discard = "checkout --";
        lg = "log --notes='*' --graph --pretty=format:'%C(auto)%h%Creset%C(auto)% d%Creset %s %Cgreen(%ah) %C(bold blue)<%an>%Creset'";
        last = "log -1 HEAD";
      };

      init.defaultBranch = "main";
      push.autoSetupRemote = true;
      pull.rebase = true;
      rerere.enabled = true;
      fetch.prune = true;
      fetch.pruneTags = true;
      column.ui = "auto";
      branch.sort = "-committerdate";
      tag.sort = "version:refname";
    };
  };
}
