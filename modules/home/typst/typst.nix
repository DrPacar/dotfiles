{
  pkgs,
  lib,
  ...
}: let
  templateDirs = lib.filterAttrs (name: type: type == "directory") (builtins.readDir ./templates);

  # Automatically generate local packages for each template directory in ./templates
  mkEntries = templateName: _: let
    templateFile = ./templates + "/${templateName}/template.typ";
    contentFile = ./templates + "/${templateName}/content.typ";
    hasTemplate = builtins.pathExists templateFile;
    hasContent = builtins.pathExists contentFile;
  in
    lib.optionals hasTemplate [
      {
        name = "typst/packages/local/${templateName}/0.1.0/typst.toml";
        value = {
          text = ''
            [package]
            name = "${templateName}"
            version = "0.1.0"
            entrypoint = "template.typ"
          '';
        };
      }
      {
        name = "typst/packages/local/${templateName}/0.1.0/template.typ";
        value = {
          source = templateFile;
        };
      }
    ]
    ++ lib.optionals hasContent [
      {
        name = "typst/packages/local/${templateName}/0.1.0/content.typ";
        value = {
          source = contentFile;
        };
      }
    ];
in {
  home.packages = with pkgs; [
    typst
    tinymist
    typstyle
  ];

  # Expose templates system-wide under @local/<name>:0.1.0
  xdg.dataFile = builtins.listToAttrs (lib.flatten (lib.mapAttrsToList mkEntries templateDirs));
}
