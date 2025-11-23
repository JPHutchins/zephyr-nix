{ pkgs }:

pkgs.writeShellApplication {
  name = "pylock";

  runtimeInputs = [
    pkgs.uv
  ];

  text = builtins.readFile ./pylock.sh;

  meta = with pkgs.lib; {
    description = "Generate pylock.toml from Python virtual environment";
    license = licenses.mit;
    mainProgram = "pylock";
  };
}
