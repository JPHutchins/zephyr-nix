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

  # Lockfile paths
, westlockPath ? "westlock.nix"
, pylockPath ? "pylock.toml"

  # ccache configuration 
, ccacheMaxSize ? "500M"

  # West integration
, manifestPath ? "."  # Path to manifest directory for westinit

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

  # West projects - converts string path to absolute path
  westProjects = west-nix-lib.mkWestProjects (/. + "/${westlockPath}");

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

  # Main setup script that orchestrates everything
  setupScript = pkgs.writeShellScriptBin "zephyr-env-setup" ''
    set -euo pipefail

    # Create workspace root
    mkdir -p "${workspaceRoot}"

    # 1. Setup SDK symlink
    mkdir -p "$(dirname "${toolchainPath}")"
    rm -f "${toolchainPath}"
    ln -sf "${sdk}" "${toolchainPath}"

    # 2. Setup West workspace (only if not already initialized)
    if [ ! -d "${westWorkspaceRoot}/.west" ]; then
      ${westWorkspaceSetup}/bin/westinit "${manifestPath}" "${westWorkspaceRoot}"
    fi

    # 3. Setup Python environment
    if [ ! -f "${pylockPath}" ]; then
      echo "Error: pylock.toml not found at ${pylockPath}" >&2
      echo "Generate lockfiles with: nix run github:JPHutchins/zephyr-nix#update" >&2
      exit 1
    fi
    ${pythonEnvSetup}/bin/python-env-setup "${workspaceRoot}" "${pylockPath}"

    # 4. Source component environment scripts
    source ${sdk}/environment-setup-zephyr.sh
    source ${ccacheSetup}/bin/cross-ccache-setup
    ${if westProjects != null then ''
    source "${westWorkspaceRoot}/env.sh"
    '' else ""}

    # 5. Activate Python venv
    source "${venvPath}/bin/activate"
  '';

in
pkgs.buildEnv {
  name = "zephyr-env-${sdkVersion}";

  paths = [
    setupScript
    sdk
    pythonEnvSetup
    ccacheSetup
  ]
    ++ dependencies
    ++ extraBuildInputs
    ++ [ westWorkspaceSetup ];

  # Expose components for advanced use cases
  passthru = {
    inherit sdk pythonEnvSetup dependencies setupScript ccacheSetup;
    inherit westProjects westWorkspaceSetup;
    inherit sdkVersion architectures pythonVersion;
    inherit workspaceRoot westWorkspaceRoot venvPath toolchainPath ccachePath;
    inherit westlockPath pylockPath ccacheMaxSize;
  };

  meta = with pkgs.lib; {
    description = "Complete Zephyr RTOS build environment with SDK, toolchain, and dependencies";
    longDescription = ''
      A unified build environment for Zephyr RTOS projects that includes:
      - Zephyr SDK ${sdkVersion} with cross-compilation toolchains for: ${builtins.concatStringsSep ", " architectures}
      - Native build tools (cmake, ninja, dtc, etc.)
      - Python ${pythonVersion} environment setup
      - West workspace integration (if westlock.nix exists)
      - ccache support (${ccacheMaxSize} cache)

      Run 'zephyr-env-setup' to initialize the workspace, or add to devShell's shellHook.

      Workspace structure:
        ${workspaceRoot}/
          ${builtins.baseNameOf westWorkspaceRoot}/  - West workspace (symlinks to Nix store)
          ${builtins.baseNameOf venvPath}/           - Python virtual environment (cached)
          ${builtins.baseNameOf toolchainPath}/      - Zephyr SDK (symlink to Nix store)
          ${builtins.baseNameOf ccachePath}/         - ccache directory
          env.sh                                      - Environment activation script
    '';
    platforms = platforms.linux;
  };
}
