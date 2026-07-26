{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # Python
    python3
    python3Packages.pip
    
    # Java 21 with JavaFX
    (jdk21.override { enableJavaFX = true; })
    
    # Go & Rust
    go
    rustup
    
    # Compilation tools
    gnumake
    gcc
    pkg-config
  ];
}
