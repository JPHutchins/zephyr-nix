{ pkgs }:

{ workspaceRoot
, maxSize
}:

pkgs.symlinkJoin {
  name = "cross-ccache";
  paths = [
    pkgs.ccache
    (pkgs.writeShellScriptBin "cross-ccache-setup" ''
      export CCACHE_DIR="$PWD/${workspaceRoot}/.ccache"
      export CCACHE_MAXSIZE="${maxSize}"
      export CCACHE_IGNOREOPTIONS="-specs=* --specs=*"
      mkdir -p "$CCACHE_DIR"
    '')
  ];
}
