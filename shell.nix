{
  pkgs ? import <nixpkgs> { },
}:

pkgs.mkShell {
  buildInputs = with pkgs; [
    cmake
    pkg-config
    gtk3
    libsecret
    xz
    clang
    ninja
    libGLU
    libsysprof-capture
    pcre2.dev
    util-linux.dev
    libselinux
    libsepol
    libthai
    libdatrie
    libxdmcp
    libxtst
    lerc.dev
    libxkbcommon
    libepoxy
    zlib
    libgcrypt
    libdeflate
  ];

  shellHook = ''
    export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath [
      pkgs.libepoxy
      pkgs.fontconfig
      pkgs.gtk3
      pkgs.glib
      pkgs.libGL
      pkgs.libsecret
      pkgs.libgcrypt
    ]}"
    unset NIX_LD_LIBRARY_PATH
    export CHROME_EXECUTABLE="${pkgs.ungoogled-chromium}/bin/chromium"
  '';

}
