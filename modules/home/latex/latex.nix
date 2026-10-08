{pkgs, ...}: {
  home.packages = with pkgs; [
    # TeX Live scheme-medium bundled with academic packages (biber, biblatex, csquotes)
    (texliveMedium.withPackages (ps: [
      ps.biber
      ps.biblatex
      ps.csquotes
    ]))

    # Language Server Protocol for LaTeX
    texlab
  ];
}
