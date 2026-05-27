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

            # Custom development scripts
            (writeShellScriptBin "build-hugo" ''
              exec hugo --gc --minify "$@"
            '')
            (writeShellScriptBin "lint-md" ''
              exec bash scripts/lint-markdown.sh --changed "$@"
            '')
            (writeShellScriptBin "lint-md-all" ''
              exec bash scripts/lint-markdown.sh --all "$@"
            '')
            (writeShellScriptBin "lint-md-backlog" ''
              exec bash scripts/lint-markdown.sh --backlog "$@"
            '')
            (writeShellScriptBin "test-md-batch" ''
              exec bash scripts/lint-markdown.sh --batch "$@"
            '')
            (writeShellScriptBin "test-all" ''
              echo "==> Running Hugo build..."
              build-hugo
              echo "==> Running markdown linting (changed files)..."
              lint-md
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
            echo "   lint-md         - Lint changed markdown files"
            echo "   lint-md-all     - Lint all markdown files"
            echo "   lint-md-backlog - List markdown files with lint errors"
            echo "   lint-md-batch   - Lint a batch of backlog files (args: <offset> <size>)"
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
