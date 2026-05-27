---
title: "ASDF is cool, but Nix is better"
date: "2026-05-27T21:18:18+02:00"
tags:
- asdf
- nix
- tools
- devops
categories:
- tips
- tools
description: >-
  "Discover how to use ASDF to easily manage different development tool versions and simplify your workflow."
---

After testing [ASDF](/en/tags/asdf/) for some time,
I decided to switch to [Nix](/en/tags/nix/).
Here is why.

I believe in the GitOps principle: everything needed for a project to run
smoothly must be versioned and easily replicable. For this,
[ASDF](/en/tags/asdf/) is not bad at all, but it still has a few flaws.

## The flaws of ASDF

With [ASDF](/en/tags/asdf/), we have `~/.tool-versions` which allows us
to specify which version to use. And that's cool.

But (and there is a "but"). Often, I used `~/.tool-versions` to define
the global version I was using. I even set up a renovate rule for it:
[renovate.json5](https://github.com/julien-noblet/dotfiles/blob/master/renovate.json5)

So every time, my environment is more or less up to date...

Including my dev tools!

I could have continued using a `.tool-versions` file for my projects
to avoid breaking my local tests. Yes.

Another issue was bothering me: how to ensure I have the exact same version...
And especially if I change machines,
how to be sure I have the exact same tools?

(Yes, node20 can be node 20.0, 20.1, 20.2...)

Another annoying thing: how to install custom tools?

With [ASDF](/en/tags/asdf/), you have to create a new plugin, push it,
add it to your configuration...
A nightmare!

And then there were times when I had to fight with `asdf reshim`.

Last point (which is somewhat related to the previous one),
I needed more and more custom plugins made by third parties.
How to make sure one of the plugins doesn't contain malicious code?

Especially with a plugin used by few people, the risk is higher.
And I don't have time to audit every repo! (Who does?)

## Mise (en place)

Pronounced /meez ahn plahs/

There is [mise](https://mise.jdx.dev/) which can secure this,
and it also allows managing programs via registries like [aqua](https://aquaproj.org/)

The workflow is almost the same as [ASDF](/en/tags/asdf/), but it is faster
(there are no shims, it cleverly adjusts your `$PATH`)

It also allows hooks and plenty of nice features.

I will probably write about it again since I am trying to push this solution
at work.

## Yes, but security is not quite there yet

Yes, because whether it's with [ASDF](/en/tags/asdf/) or Mise,
programs are installed in a folder to which the current user has access.

In a flash, I can break a program, and fixing it is never easy.

## OK, just don't play around with ~/.local and it should be fine, right?

Yes.

In most cases.

But I ran into some obscure cases, especially with annoying programs
using old glibc versions or similar.
And making two different `.so` files cohabitate is never simple.

## Well OK... What about [Nix](/en/tags/nix/) in all this?

[Nix](/en/tags/nix/) is a package manager, but above all, it's a language.

It allows you to define environments declaratively,
with well-defined dependencies.

It saves everything in its store.
A directory that appears as immutable.
This way, it's impossible to break a program by modifying a file.

[Nix](/en/tags/nix/) is pretty cool, but in my opinion, it really shines with Flakes.

Flakes adds an abstraction layer and also pins versions.
(A bit like `go.sum` or `package-lock.json` but for everything!)

Here is an example of a `flake.nix` used for this site:

```nix
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
            nodejs
            git
            gnumake
          ];

          shellHook = ''
            echo "--------------------------------------------------"
            echo " Welcome to the blog development environment!     "
            echo " Hugo: $(hugo version | cut -d' ' -f2)"
            echo " Node: $(node --version)"
            echo " Git:  $(git --version | cut -d' ' -f3)"
            echo " Make: $(make --version | head -n1)"
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
```

## What does it say?

We define our inputs here, and in our case, we "just" use the nixpkgs repo.

Then, we define the list of programs and the commands to run when opening
the shell.

Here, we add a small hook to initialize Git submodules if they are not already.

Note that the `allSystems` part defines the systems for which we want to
build our shell. And `forAllSystems` is just a helper function to avoid
repeating code.

Thanks to this, I make sure the current version will be pinned for Linux, Mac...

In this file, there is really everything you need to compile, test, and
push the site!

The only thing I didn't add is the text editor.

## OK, but I don't see the versions

That's true!

How do I know I am using `hugo v0.161.1`, `Node.js v24.15.0`,
`git version 2.54.0` and `GNU Make 4.4.1`?

It's all in `flake.lock`:

```json
{
  "nodes": {
    "nixpkgs": {
      "locked": {
        "lastModified": 1779560665,
        "narHash": "sha256-tpyBcxPpcQb8ukyNF7DoCwfSY3VPsxHoYwj00Cayv5o=",
        "owner": "NixOS",
        "repo": "nixpkgs",
        "rev": "64c08a7ca051951c8eae34e3e3cb1e202fe36786",
        "type": "github"
      },
      "original": {
        "owner": "NixOS",
        "ref": "nixos-unstable",
        "repo": "nixpkgs",
        "type": "github"
      }
    },
    "root": {
      "inputs": {
        "nixpkgs": "nixpkgs"
      }
    }
  },
  "root": "root",
  "version": 7
}
```

Here, we can see that I must retrieve the version known by `nixpkgs` at commit `64c08a7ca051951c8eae34e3e3cb1e202fe36786`.

I don't really need to know which version I have.
I just need to know that it works on my machine, so it will work elsewhere.

## What about the build?

The build will also use [Nix](/en/tags/nix/), and with the exact same
versions to the byte!
Modulo the OS and CPU architecture (the `allSystems`), but in this case,
they will use the exact same original source code to compile the programs!

And this is true whether I am on Ubuntu, Debian, NixOS, Suse, Fedora...

## NixOS?

NixOS is a Linux distribution based on [Nix](/en/tags/nix/).
It uses [Nix](/en/tags/nix/) to manage packages and configurations.

So here, we no longer configure just dev tools, but the entire system.
From the kernel to the graphics card configuration, disks, and system tools...

This pushes GitOps to its absolute limit!
I can even generate ready-to-use images for my Raspberry Pi.

In short, [ASDF](/en/tags/asdf/) was cool, but [Nix](/en/tags/nix/) is
really better 😉!
