---
title: "ASDF, c'est cool mais Nix, c'est mieux"
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
  "Découvrez comment utiliser asdf pour gérer facilement différentes versions
  d'outils de développement et simplifier votre workflow."
---

Après avoir testé [asdf](/tags/asdf/) pendant quelque temps,
j'ai décidé de passer à [Nix](/tags/nix/).
Voici pourquoi.

Je crois au **principe** GitOps, à savoir que tout ce qui est nécessaire au bon
fonctionnement d'un projet doit être versionné et facilement réplicable.
Pour cela, [ASDF](/tags/asdf/) n'est pas mal du tout, mais il présente tout de
même quelques défauts.

## Les défauts d'ASDF

Avec [ASDF](/tags/asdf/), on a le `~/.tool-versions` qui nous permet de dire
quelle version utiliser. Et c'est cool.

Mais (et il y en a). Souvent, j'utilisais le `~/.tool-versions` pour définir
la version globale que j'utilisais. J'ai même fait une règle renovate pour
cela : [renovate.json5](https://github.com/julien-noblet/dotfiles/blob/master/renovate.json5)

Donc à chaque fois, j'ai mon environnement +/- à jour...

Dont mes outils de dev !

J'aurais pu continuer avec un `.tool-versions` pour mes projets afin de ne pas
casser mes tests en local. Oui.

Un autre souci me tracassait : comment m'assurer d'avoir exactement la même version...
Et surtout, si je change de poste,
comment être sûr d'avoir exactement les mêmes outils ?

(Oui node20, ça peut être node 20.0, 20.1, 20.2...)

Un autre truc relou : comment installer des outils customs ?

Avec [ASDF](/tags/asdf/), il faut faire un nouveau plugin, le pousser,
l'ajouter dans sa configuration...
Un enfer!

Et puis j'ai eu des fois où j'ai dû me battre avec `asdf reshim`.

Dernier point (qui est un peu lié au précédent),
j'ai eu besoin de plus en plus de plugins customs faits par des tiers.
Comment m'assurer que l'un des plugins n'embarque pas de code malicieux ?

Surtout avec un plugin utilisé par peu de monde, le risque est plus élevé.
Et je n'ai pas le temps d'auditer tous les repos ! (Qui l'a ?)

## Mise (en place)

Il y a [mise](https://mise.jdx.dev/) qui peut sécuriser cela,
en plus il permet de gérer aussi des programmes via des registries comme [aqua](https://aquaproj.org/)

Le workflow est quasi le même que [ASDF](/tags/asdf/), mais c'est plus rapide
(on n'a pas de shim, il ajuste astucieusement votre `$PATH`)

Il permet aussi de faire des `hooks` et plein de fonctionnalités sympas.

Je reviendrai dessus, je pense, car j'essaie de pousser cette solution au bureau.

## Oui mais la sécurité n'est pas encore là

Oui, car que ce soit avec [ASDF](/tags/asdf/) ou Mise,
les programmes sont installés dans un dossier auquel l'utilisateur courant a accès.

En un éclair, je peux casser un programme et pour le remettre, ce n'est jamais simple.

## OK, il suffit de ne pas jouer avec le `~/.local` et ça passe, non ?

Oui.

Dans la plupart des cas.

Mais je suis tombé sur quelques cas obscurs, notamment avec des programmes relous
utilisant de vieilles glibc ou autres.
Et faire cohabiter deux `.so` différents, ce n'est jamais si simple.

## Bon OK... Et [Nix](/tags/nix/) dans tout ça ?

[Nix](/tags/nix/), c'est un gestionnaire de paquets, mais c'est surtout un langage.

Il permet de définir des environnements de manière déclarative,
avec des dépendances bien définies.

Il enregistre tout dans son store.
Un dossier qui apparaît comme immuable.
Comme ça, il est impossible de casser un programme en modifiant un fichier.

[Nix](/tags/nix/), ce n'est pas mal, mais c'est avec les Flakes que cela prend
tout son sens selon moi.

Flakes va ajouter une couche d'abstraction et permettre également de figer
les versions.
(Un peu comme le `go.sum` ou `package-lock.json` mais pour tout !)

Voici un exemple de `flake.nix` utilisé pour ce site :

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

## Ça dit quoi ?

On définit ici nos entrées, et dans notre cas, on utilise "juste" le repo
nixpkgs.

Ensuite, on définit la liste des programmes, et les commandes à exécuter lors de
l'ouverture du shell.

Ici, on ajoute un petit hook pour initialiser les sous-modules Git si ce n'est pas
déjà fait.

Notez que la partie `allSystems` permet de définir les systèmes pour lesquels on
veut builder notre shell. Et `forAllSystems` est juste une fonction helper pour
éviter de répéter du code.

Grâce à cela, je m'assure que la version actuelle sera figée pour Linux, Mac...

Dans ce fichier, il y a vraiment tout ce qu'il faut pour compiler, tester, pousser
le site !

Il n'y a que l'éditeur de texte que je n'ai pas ajouté.

## OK mais je ne vois pas les versions

C'est vrai !

Comment savoir que je suis avec `hugo v0.161.1`,
`Node.js v24.15.0`, `git version 2.54.0` et `GNU Make 4.4.1` ?

Tout est dans `flake.lock` :

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

Ici on peut comprendre que je dois récupérer la version connue par `nixpkgs`,
sur le commit `64c08a7ca051951c8eae34e3e3cb1e202fe36786`.

Je n'ai pas vraiment besoin de connaître la version que j'ai.
J'ai simplement besoin de savoir que ça marche sur mon poste,
donc ça va marcher ailleurs.

## Et le build?

Le build aussi utilisera [Nix](/tags/nix/), et avec les mêmes versions
à l'octet près !
Modulo l'OS et l'architecture CPU (les `allSystems`) mais dans ce cas,
ils utiliseront exactement le même code source d'origine pour
la compilation des programmes !

Et cela que je sois sous Ubuntu, Debian, NixOS, Suse, Fedora ...

## NixOS ?

NixOS est une distribution Linux basée sur [Nix](/tags/nix/).
Elle utilise [Nix](/tags/nix/) pour gérer les paquets et les configurations.

Donc on ne charge plus ici que les outils de dev, mais vraiment tout le système.
Du noyau, en passant par la configuration de la carte graphique, des disques,
des outils système...

Cela permet de pousser le GitOps à son paroxysme !
Je peux même générer des images prêtes à l'emploi pour mes Raspberry Pi.

Bref, [ASDF](/tags/asdf/), c'était cool, [Nix](/tags/nix/) c'est vraiment
mieux 😉 !
