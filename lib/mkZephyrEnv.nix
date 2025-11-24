{ pkgs, west-nix-lib }:

{ # SDK configuration (REQUIRED)
  sdkVersion
, architectures

  # Python configuration
, pythonVersion ? "3.12"

  # Workspace paths
, workspaceRoot ? ".zephyr-nix"
, westWorkspaceRoot ? "${workspaceRoot}/.west-nix"
, venvPath ? "${workspaceRoot}/.venv"
, toolchainPath ? "${workspaceRoot}/.toolchain"
, ccachePath ? "${workspaceRoot}/.ccache"

  # Lockfile paths (users must pass westlockPath = ./westlock.nix from their flake)
, westlockPath
, pylockPath ? "pylock.toml"

  # ccache configuration 
, ccacheMaxSize ? "500M"

  # West integration
, manifestPath ? "."  # Path to manifest directory for westinit
, manifestFile ? "west.yml"  # Name of the manifest file

  # Additional build inputs for the devShell
, extraBuildInputs ? []
}:

let
  # Zephyr SDK
  sdk = pkgs.callPackage ../pkgs/zephyr-sdk {
    version = sdkVersion;
    inherit architectures;
  };

  # Native build tools (cmake, ninja, dtc, etc.)
  dependencies = import ./mkZephyrDependencies.nix { inherit pkgs; };

  # West projects - user must provide westlock.nix as a path
  westProjects = west-nix-lib.mkWestProjects westlockPath;

  # West workspace setup script
  westWorkspaceSetup = west-nix-lib.mkWestWorkspace { inherit westProjects; };

  # Python environment setup script
  pythonEnvSetup = (import ./mkPythonEnv { inherit pkgs; }) {
    workspaceRoot = workspaceRoot;
    inherit pythonVersion;
  };

  # ccache configuration script
  ccacheSetup = (import ./mkCrossCCache.nix { inherit pkgs; }) {
    workspaceRoot = workspaceRoot;
    maxSize = ccacheMaxSize;
  };

  # Main setup script that orchestrates everything (initialization only, no sourcing)
  setupScript = pkgs.writeShellScriptBin "zephyr-env-setup" ''
    set -euo pipefail

    # Create workspace root
    mkdir -p "${workspaceRoot}"

    # Add .gitignore to workspace to ignore all generated content
    cat > "${workspaceRoot}/.gitignore" <<'EOF'
*
EOF

    # 1. Setup SDK symlink
    mkdir -p "$(dirname "${toolchainPath}")"
    rm -f "${toolchainPath}"
    ln -sf "${sdk}" "${toolchainPath}"

    # 2. Setup West workspace (only if not already initialized)
    if [ ! -d "${westWorkspaceRoot}/.west" ]; then
      ${westWorkspaceSetup}/bin/westinit "${manifestPath}" "${manifestFile}" "${westWorkspaceRoot}"
    fi

    # 3. Setup Python environment
    if [ ! -f "${pylockPath}" ]; then
      echo "Error: pylock.toml not found at ${pylockPath}" >&2
      echo "Generate lockfiles with: nix run github:JPHutchins/zephyr-nix#update" >&2
      exit 1
    fi
    ${pythonEnvSetup}/bin/python-env-setup "${workspaceRoot}" "${pylockPath}"
  '';

in
pkgs.mkShell {
  packages = [
    setupScript
    sdk
    pythonEnvSetup
    ccacheSetup
    westWorkspaceSetup
  ]
    ++ dependencies
    ++ extraBuildInputs;

  shellHook = ''
    # Run initialization
    ${setupScript}/bin/zephyr-env-setup

    # Activate environment in the interactive shell
    source ${sdk}/environment-setup-zephyr.sh
    source ${ccacheSetup}/bin/cross-ccache-setup
    source "${westWorkspaceRoot}/env.sh"
    source "${venvPath}/bin/activate"
  '';

  passthru = {
    inherit sdk pythonEnvSetup dependencies setupScript ccacheSetup;
    inherit westProjects westWorkspaceSetup;
    inherit sdkVersion architectures pythonVersion;
    inherit workspaceRoot westWorkspaceRoot venvPath toolchainPath ccachePath;
    inherit westlockPath pylockPath ccacheMaxSize;
  };
}
