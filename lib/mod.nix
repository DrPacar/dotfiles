{ lib }:

let
  # recursive helper function to go through directories
  getModulesRec = dir:
    let
      content = builtins.readDir dir;
      # ignore files starting with "_".
      validEntries = lib.filterAttrs (name: type: !(lib.hasPrefix "_" name)) content;
    in
    lib.flatten (lib.mapAttrsToList (name: type:
      let
        fullItemPath = dir + "/${name}";
      in
      if type == "regular" && lib.hasSuffix ".nix" name then
        [ fullItemPath ]
      else if type == "directory" then
        getModulesRec fullItemPath
      else
        []
    ) validEntries);
in
root: baseDir: path:
let
  fullPath = root + "/${baseDir}/${path}";
  nixFile  = root + "/${baseDir}/${path}.nix";
in
# check if it's a direct file path
if builtins.pathExists nixFile then
  [ nixFile ]

# check if it's a directory
else if builtins.pathExists fullPath then
  getModulesRec fullPath

else
  throw "Module path '${baseDir}/${path}' does not exist!"
