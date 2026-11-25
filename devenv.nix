{
  pkgs,
  lib,
  ...
}:

let
  mermaidJs = pkgs.fetchurl {
    url = "https://cdn.jsdelivr.net/npm/mermaid@11.4.1/dist/mermaid.min.js";
    sha256 = "17kgvdnqvy47yw7fqi2kzhk5xmp809fx8pdccv6c9ya6sjpw2fx4";
  };

  axeJs = pkgs.fetchurl {
    url = "https://cdn.jsdelivr.net/npm/axe-core@4.10.2/axe.min.js";
    sha256 = "1qvmggpdja8qdq3rklafxg1d8dyvnrk3nwni595nziq1xjfws4dm";
  };
in
{
  # https://devenv.sh/basics/
  env.AXE_JS_PATH = "${axeJs}";

  # https://devenv.sh/packages/
  packages = with pkgs; [
    hugo
    git
    markdownlint-cli2
    yamllint
    actionlint
    typos
    gitleaks
    lychee
    ruff
    chromium
    (python3.withPackages (ps: [ ps.playwright ]))
  ];

  # https://devenv.sh/processes/
  processes.hugo.exec = "hugo server -D --buildFuture --navigateToChanged";

  # https://devenv.sh/integrations/treefmt/
  treefmt = {
    enable = true;
    config = {
      settings.global.excludes = [
        "themes/**"
        "public/**"
        "resources/**"
        "static/vendor/**"
        "devenv.lock"
        ".devenv/**"
      ];

      programs = {
        nixfmt.enable = true;
        statix.enable = true;
        deadnix.enable = true;
        yamlfmt.enable = true;
        ruff-format.enable = true;
        ruff-check.enable = true;
        prettier = {
          enable = true;
          includes = [ "*.json" ];
        };
      };
    };
  };

  # https://devenv.sh/git-hooks/
  git-hooks.hooks = {
    treefmt.enable = true;
    yamllint.enable = true;
    actionlint.enable = true;
    typos.enable = true;
    gitleaks.enable = true;
    ruff.enable = true;
    ruff-format.enable = true;
    markdownlint-cli2 = {
      enable = true;
      name = "markdownlint-cli2";
      entry = "${pkgs.markdownlint-cli2}/bin/markdownlint-cli2";
      types = [ "markdown" ];
      excludes = [
        "^themes/"
        "^public/"
      ];
    };
  };

  # Prevent concurrent treefmt cache lock contention during `devenv test`
  tasks."devenv:git-hooks:run".after = [ "devenv:treefmt:run" ];

  # https://devenv.sh/scripts/
  scripts = {
    sync-vendor.exec = ''
      mkdir -p static/vendor
      if [ ! -f static/vendor/mermaid.min.js ] || ! cmp -s "${mermaidJs}" static/vendor/mermaid.min.js; then
        cp -f "${mermaidJs}" static/vendor/mermaid.min.js
        chmod u+w static/vendor/mermaid.min.js
      fi
    '';

    build-hugo.exec = ''
      sync-vendor
      exec hugo --gc --minify "$@"
    '';

    lint-all.exec = ''
      echo "==> Running treefmt..."
      treefmt --fail-on-change
      echo "==> Running yamllint..."
      yamllint .
      echo "==> Running actionlint..."
      actionlint
      echo "==> Running typos..."
      typos
      echo "==> Running markdownlint-cli2..."
      markdownlint-cli2
    '';

    check-links.exec = ''
      echo "==> Running lychee link checker..."
      lychee --config lychee.toml \
        --root-dir "$PWD/public" \
        --remap "https://julien-noblet.github.io/ file://$PWD/public/" \
        ./public
    '';

    test-e2e.exec = ''
      echo "==> Running Playwright E2E & accessibility tests..."
      python3 tests/e2e_site.py
    '';

    test-all.exec = ''
      echo "==> Running Hugo build..."
      build-hugo
      lint-all
      test-e2e
      check-links
    '';
  };

  # https://devenv.sh/basics/
  enterShell = ''
    if [ -z "''${PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH:-}" ]; then
      export PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH="${lib.getExe pkgs.chromium}"
    fi

    sync-vendor

    echo "--------------------------------------------------"
    echo " Welcome to the blog development environment!     "
    echo " Hugo:    $(hugo version | cut -d' ' -f2)"
    echo " Git:     $(git --version | cut -d' ' -f3)"
    echo "--------------------------------------------------"
    echo " Available custom commands:"
    echo "   build-hugo      - Build Hugo site (with --gc and --minify)"
    echo "   lint-all        - Run all formatters and linters"
    echo "   test-e2e        - Run Playwright E2E + axe-core tests"
    echo "   check-links     - Check broken links in ./public"
    echo "   test-all        - Run all tests (hugo + linters + e2e + links)"
    echo "   devenv up       - Start local Hugo server with live reload"
    echo "--------------------------------------------------"

    # Automatically initialize Git submodules if they are missing
    if [ -e .git ] && [ ! -f "themes/PaperMod/theme.toml" ]; then
      echo "Initializing Git submodules..."
      git submodule update --init --recursive
    fi
  '';

  # https://devenv.sh/tests/
  enterTest = ''
    test-all
  '';
}
