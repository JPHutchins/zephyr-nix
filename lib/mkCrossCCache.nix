{ pkgs }:

{ workspaceRoot
, maxSize
}:

pkgs.symlinkJoin {
  name = "cross-ccache";
  paths = [
    pkgs.ccache
    (pkgs.writeShellScriptBin "cross-ccache-setup" ''
      export CCACHE_DIR="${workspaceRoot}/.ccache"
      export CCACHE_MAXSIZE="${maxSize}"
      export CCACHE_IGNOREOPTIONS="-specs=* --specs=*"
      export CMAKE_C_COMPILER_LAUNCHER="ccache"
      export CMAKE_CXX_COMPILER_LAUNCHER="ccache"
      mkdir -p "$CCACHE_DIR"
    '')
  ];
}
