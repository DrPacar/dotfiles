{ lib }:

root: baseDir: path:
let
  fullPath = root + "/${baseDir}/${path}";
  nixFile  = root + "/${baseDir}/${path}.nix";
in
if builtins.pathExists nixFile then
  [ nixFile ]
else if builtins.pathExists fullPath then
  if builtins.pathExists (fullPath + "/default.nix") then
    [ fullPath ]
  else
    let
      content  = builtins.readDir fullPath;
      isNix    = name: type: type == "regular" && lib.hasSuffix ".nix" name;
      nixFiles = lib.filterAttrs isNix content;
    in
    map (file: fullPath + "/${file}") (builtins.attrNames nixFiles)
else
  throw "Module path '${baseDir}/${path}' does not exist!"
