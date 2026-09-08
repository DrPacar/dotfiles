{pkgs, ...}: {
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
        lg = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
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
