{
  description = "Julien Noblet's blog development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      allSystems = [
        "x86_64-linux" # 64-bit Intel/AMD Linux
        "aarch64-linux" # 64-bit ARM Linux
        "x86_64-darwin" # 64-bit Intel macOS
        "aarch64-darwin" # 64-bit ARM macOS
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs allSystems (system: f {
        pkgs = import nixpkgs { inherit system; };
      });
    in
    {
      devShells = forAllSystems ({ pkgs }: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            hugo
            git
            markdownlint-cli2

            (writeShellScriptBin "build-hugo" ''
              exec hugo --gc --minify "$@"
            '')
            (writeShellScriptBin "test-all" ''
              echo "==> Running Hugo build..."
              hugo --gc --minify
              echo "==> Running markdown linting..."
              markdownlint-cli2
            '')
          ];

          shellHook = ''
            echo "--------------------------------------------------"
            echo " Welcome to the blog development environment!     "
            echo " Hugo:    $(hugo version | cut -d' ' -f2)"
            echo " Git:     $(git --version | cut -d' ' -f3)"
            echo "--------------------------------------------------"
            echo " Available custom commands:"
            echo "   build-hugo      - Build Hugo site (with --gc and --minify)"
            echo "   test-all        - Run all tests (hugo + markdown)"
            echo "--------------------------------------------------"

            # Automatically initialize Git submodules if they are missing
            if [ -d .git ] && [ ! -f "themes/PaperMod/theme.toml" ]; then
              echo "Initializing Git submodules..."
              git submodule update --init --recursive
            fi
          '';
        };
      });
    };
}
