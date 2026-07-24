{ pkgs, ... }: {
  programs.git = {
    enable = true;
    
    userName = "DrPacar";
    userEmail = "lukapacar06@gmail.com";

    lfs.enable = true;

    aliases = {
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

      lg = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
      last = "log -1 HEAD";
    };

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

    extraConfig = {
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
