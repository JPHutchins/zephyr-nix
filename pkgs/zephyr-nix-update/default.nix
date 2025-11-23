{ pkgs, west-nix }:

pkgs.writeShellApplication {
  name = "zephyr-nix-update";

  runtimeInputs = [
    pkgs.python3
    pkgs.uv
    west-nix.packages.${pkgs.system}.westupdate
  ];

  text = builtins.readFile ./zephyr-nix-update.sh;

  meta = with pkgs.lib; {
    description = "Update westlock.nix and pylock.toml for Zephyr projects";
    longDescription = ''
      Synchronizes Zephyr project dependencies by:
      1. Generating westlock.nix from west manifest
      2. Creating temporary venv and installing west dependencies
      3. Generating pylock.toml from installed packages
    '';
    license = licenses.mit;
    mainProgram = "zephyr-nix-update";
  };
}
