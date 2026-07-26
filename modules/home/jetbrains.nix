{ pkgs, ... }: {
  home.packages = with pkgs; let
    customVmOpts = writeText "jetbrains.vmoptions" ''
      -Xms256m
      -Xmx2048m
      -XX:ReservedCodeCacheSize=512m
      -XX:+IgnoreUnrecognizedVMOptions
      -XX:+UseG1GC
      -XX:SoftRefLRUPolicyMSPerMB=50
      -XX:CICompilerCount=2
      -XX:+HeapDumpOnOutOfMemoryError
      -XX:-OmitStackTraceInFastThrow
      -Dawt.toolkit.name=XToolkit
    '';

    wrapJetbrains = pkg: executableName: envVar: symlinkJoin {
      name = "${pkg.pname or pkg.name}-xwayland";
      paths = [ pkg ];
      buildInputs = [ makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/${executableName} \
          --set ${envVar} "${customVmOpts}"
      '';
    };

  in [
    (wrapJetbrains jetbrains.idea "idea" "IDEA_VM_OPTIONS")
    (wrapJetbrains jetbrains.pycharm "pycharm" "PYCHARM_VM_OPTIONS")
    (wrapJetbrains jetbrains.datagrip "datagrip" "DATAGRIP_VM_OPTIONS")
  ];

  home.sessionVariables = {
    IDEA_VM_OPTIONS = "$HOME/.config/JetBrains/IntelliJIdea2026.1/idea64.vmoptions";
    _JAVA_AWT_WM_NONREPARENTING = "1";
  };

}
