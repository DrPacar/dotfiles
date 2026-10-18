{pkgs, ...}: {
  programs.yazi = {
    enable = true;
    shellWrapperName = "y";

    settings = {
      mgr = {
        ratio = [1 4 3];
        sort_by = "natural";
        sort_sensitive = false;
        sort_dir_first = true;
        linemode = "size";
        show_hidden = true;
        show_symlink = true;
      };

      preview = {
        tab_size = 2;
        max_width = 1000;
        max_height = 1000;
      };
    };

    keymap = {
      mgr.prepend_keymap = [
        {
          on = ["!"];
          run = ''shell "$SHELL" --block --confirm'';
          desc = "open shell here";
        }
        {
          on = ["<C-n>"];
          run = "shell -- ${pkgs.ripdrag}/bin/ripdrag -x -a %s";
          desc = "drag and drop files via ripdrag";
        }
        {
          on = ["g" "d"];
          run = "cd ~/dotfiles";
          desc = "go to dotfiles";
        }
        {
          on = ["g" "u"];
          run = "cd ~/uni";
          desc = "go to uni";
        }
      ];
    };
  };
}
