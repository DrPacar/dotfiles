{pkgs, ...}: {
  home.packages = with pkgs; [
    (symlinkJoin {
      name = "sweethome3d-fixed";
      paths = [sweethome3d.application];
      buildInputs = [makeWrapper];
      postBuild = ''
        wrapProgram $out/bin/sweethome3d \
          --set GTK_THEME Adwaita
      '';
    })
  ];
}
