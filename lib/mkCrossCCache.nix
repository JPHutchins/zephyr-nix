{ pkgs }:

{ workspaceRoot
, maxSize
}:

pkgs.writeShellScriptBin "cross-ccache-setup" ''
  export CCACHE_DIR="${workspaceRoot}/.ccache"
  export CCACHE_MAXSIZE="${maxSize}"
  export CCACHE_IGNOREOPTIONS="-specs=* --specs=*"
  mkdir -p "$CCACHE_DIR"
''
