---
title: "Flawless and Reproducible Devshells with Nix Flakes and direnv"
date: "2026-11-07T22:00:00+01:00"
tags:
- nix
- flakes
- direnv
- devops
- tools
- gitops
categories:
- tips
- tools
- devops
description: >-
  "How to create isolated, instantaneous, and reproducible per-project dev
  environments using Nix Flakes and nix-direnv."
---

In my [previous article about Nix](/en/posts/2026/asdf-c-est-cool-nix-c-est-mieux/),
I explained why I gradually moved away from [asdf](/en/tags/asdf/) and Mise in
favor of [Nix](/en/tags/nix/). Later on, we looked at how to
[manage secrets securely with sops-nix](/en/posts/2026/sops-nix-gestion-secrets/).

Today, let's tackle everyday developer friction:
**per-project development environments**.

We have all faced this classic situation:

- Project A requires Node 18 and a specific pnpm version.
- Project B runs on Node 22 with Python 3.12 and compiled C bindings.
- Project C demands Hugo extended, a Markdown linter, and a PostgreSQL client.

The usual outcome? Version conflicts everywhere, forgotten `nvm use` calls,
global installations cluttering your OS, or having to spin up heavy
Docker/devcontainer setups just to run a linter or format code.

Combining **Nix Flakes** with **direnv** solves all of this:
as soon as you `cd` into a project directory, the right tools are loaded.
When you leave, they disappear. Magic? Almost—it is just declarative configuration.

## What is wrong with plain `nix develop`?

With a Nix Flake, the built-in command to jump into a development environment is:

```bash
nix develop
```

While powerful, it comes with two practical drawbacks for daily work:

1. **You have to remember it**: every time you open a new terminal or `cd` into
   the repository, you must run it manually.
2. **It is a subshell**: typing `exit` does not close your terminal tab; it just
   drops you back into your base shell. Furthermore, external processes or IDEs
   do not automatically inherit this nested environment.

This is where **direnv** comes into play.

## direnv + nix-direnv: the winning combination

[direnv](https://direnv.net/) is a shell extension for bash, zsh, and fish.
Its premise is straightforward: automatically load environment variables when
entering a directory with a `.envrc` file, and unload them upon exit.

However, using plain direnv with Nix can introduce a slight lag (1–2 seconds)
each time you enter the directory as the flake gets evaluated.

To make it instantaneous, you need **nix-direnv**.
It provides smart caching: your environment is only rebuilt or re-evaluated
when `flake.nix` or `flake.lock` actually changes!

### Quick installation

On NixOS or with Home-Manager, it is just two lines:

```nix
programs.direnv = {
  enable = true;
  nix-direnv.enable = true;
};
```

On standard Linux distributions or macOS, follow the setup instructions in the
official [nix-direnv](https://github.com/nix-community/nix-direnv) repository.

Once installed, all you need is a one-line `.envrc` file at the root of your
project:

```bash
use flake
```

The first time, direnv requires explicit approval for security reasons:

```bash
direnv allow
```

And that is it! Every time you enter the folder, your environment is loaded
instantly into your primary shell.

---

## Case 1: The universal starter kit

Here is a minimal, boilerplate `flake.nix` you can drop into any repository:

```nix
{
  description = "Minimalist development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      # Supported architectures (Linux x86/ARM, macOS Intel/Apple Silicon)
      allSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs allSystems (system: f {
        pkgs = import nixpkgs { inherit system; };
      });
    in
    {
      devShells = forAllSystems ({ pkgs }: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            git
            curl
            jq
          ];
        };
      });
    };
}
```

Key takeaways:

- `pkgs.mkShell` is a specialized helper designed specifically for building
  development shells.
- The `packages` list declares every binary injected into your `$PATH`.
- The resulting `flake.lock` guarantees that anyone cloning the repository will
  receive the **exact same versions** of `git`, `curl`, and `jq`.

---

## Case 2: A real-world example, this blog

Let's look at a concrete case: the `flake.nix` used to build and maintain this
Hugo blog!

In a blogging or docs project, you rarely want just the runtime. You also want
linters and convenient project-specific CLI commands for contributors and CI.

Here is an excerpt from what powers this repository:

```nix
{
  description = "Julien Noblet's blog development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      allSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
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

            # Utility scripts defined directly in Nix!
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
            echo " Hugo: $(hugo version | cut -d' ' -f2)"
            echo " Git:  $(git --version | cut -d' ' -f3)"
            echo "--------------------------------------------------"
            echo " Available custom commands:"
            echo "   build-hugo - Build Hugo site with --gc and --minify"
            echo "   test-all   - Run Hugo build and markdown linting"
            echo "--------------------------------------------------"

            # Automatically initialize Git submodules if missing
            if [ -d .git ] && [ ! -f "themes/PaperMod/theme.toml" ]; then
              echo "Initializing Git submodules..."
              git submodule update --init --recursive
            fi
          '';
        };
      });
    };
}
```

Notice the `writeShellScriptBin` pattern: no need to maintain an outdated
`Makefile` or scattered shell scripts. Commands are packaged alongside their
dependencies and added to `$PATH`.

Additionally, the `shellHook` fires whenever direnv activates, making it easy
to print reminders or initialize submodules.

---

## Case 3: Polyglot & multi-runtime projects

This is where Nix clearly outperforms alternatives like asdf or language-specific
managers (nvm, pyenv, rbenv, gvm...).

Consider a modern full-stack application:

- A backend in **Go** or **Python**.
- A frontend in **Node.js** with **pnpm**.
- A local database or native CLI client (**PostgreSQL**).
- System C libraries (OpenSSL, zlib) required to compile native packages.

With traditional tooling, you must install each runtime separately, hope your
distribution's C headers match, and configure environment variables by hand.

With Nix, everything is defined in one place:

```nix
devShells = forAllSystems ({ pkgs }: {
  default = pkgs.mkShell {
    packages = with pkgs; [
      # Runtimes
      go_1_24
      nodejs_22
      nodePackages.pnpm
      python312Full

      # Database and CLI tooling
      postgresql_16
      sqls
      jq

      # System libraries
      openssl
      pkg-config
    ];

    # Environment variables injected into the shell
    DATABASE_URL = "postgres://postgres:postgres@localhost:5432/app_dev";
    PORT = "8080";

    shellHook = ''
      # Local cache configuration
      export GOPATH="$PWD/.cache/go"
      export PATH="$GOPATH/bin:$PATH"

      # Ensure pkg-config and C bindings find OpenSSL
      export PKG_CONFIG_PATH="${pkgs.openssl.dev}/lib/pkgconfig:$PKG_CONFIG_PATH"

      echo "Polyglot environment ready!"
      echo "Go: $(go version)"
      echo "Node: $(node -v)"
    '';
  };
});
```

Whenever a teammate clones the project or you switch computers, running
`git clone` followed by `cd` and `direnv allow` brings up the exact same
working setup. No surprises.

---

## Daily best practices and tips

A few lessons learned from real-world usage:

### 1. Commit `flake.lock`, ignore `.direnv`

The `flake.lock` file **must be committed** to Git. It pins exact revisions
of `nixpkgs` and guarantees deterministic environments.

Conversely, make sure `.direnv` is listed in `.gitignore`, as it holds local
caches and symlinks.

### 2. Updating dependencies

To bump all packages to the latest versions from your channel:

```bash
nix flake update
```

Review the diff, run your tests, and commit the updated `flake.lock`.

### 3. Editor & IDE integration (VSCode / Neovim)

To ensure language servers (gopls, ESLint, TypeScript LSP) pick up the tools
inside your flake, install the **direnv** extension in your editor (such as
*direnv* in VSCode). It feeds the loaded environment into your editor workspace.

### 4. Garbage collection protection

By default, `nix-collect-garbage` cleans up derivations unreferenced by your
system profile. Fortunately, `nix-direnv` automatically creates "GC roots"
under `.direnv/` to protect active project shells from being purged.

---

## Wrapping up

Pairing **Nix Flakes** with **direnv** delivers the sweet spot:

- The determinism and reproducibility of Nix.
- The frictionless, invisible workflow of direnv.

No more juggling disparate version managers or waiting on heavy container
runtimes just to get your day started.

How do you manage your development environments? Feel free to share your setups
and feedback!
