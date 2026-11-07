---
title: "Des devshells parfaits et reproductibles avec Nix Flakes et direnv"
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
  "Comment créer des environnements de développement isolés, instantanés et
  reproductibles par projet grâce à Nix Flakes et nix-direnv."
---

Dans mon [article précédent sur Nix](/posts/2026/asdf-c-est-cool-nix-c-est-mieux/),
j'expliquais pourquoi j'avais progressivement abandonné [asdf](/tags/asdf/)
et Mise au profit de [Nix](/tags/nix/). Puis, nous avons vu comment
[sécuriser nos secrets avec sops-nix](/posts/2026/sops-nix-gestion-secrets/).

Aujourd'hui, on s'attaque au nerf de la guerre du dev au quotidien :
**l'environnement de travail par projet**.

On a tous connu ce scénario :

- Le projet A a besoin de Node 18 et d'une version spécifique de pnpm.
- Le projet B tourne sous Node 22 avec Python 3.12 et des bindings C compilés.
- Le projet C exige Hugo version extended, un linter Markdown et un client
  PostgreSQL.

Résultat habituel ? Des conflits de versions partout, des `nvm use` oubliés,
des installations globales qui polluent l'OS, ou le recours à de lourds
conteneurs Docker/devcontainers juste pour formater du code ou lancer un test.

Avec **Nix Flakes** combiné à **direnv**, on résout tout ça d'un coup :
dès qu'on entre dans le dossier d'un projet, les bons outils sont là.
Quand on en sort, ils disparaissent. Magique ? Presque, c'est juste déclaratif.

## Le problème avec `nix develop` tout seul

Quand on utilise un Flake Nix, la commande native pour entrer dans un
environnement de dev est :

```bash
nix develop
```

C'est très puissant, mais au quotidien, ça a deux défauts majeurs :

1. **Il faut y penser** : à chaque fois qu'on ouvre un terminal ou qu'on fait
   un `cd` dans le projet, il faut retaper la commande.
2. **C'est un sous-shell** : taper `exit` ne ferme pas votre terminal,
   ça vous sort juste du shell Nix. Et si vous lancez votre IDE ou un script
   externe, il n'hérite pas forcément de cet environnement.

C'est là qu'intervient **direnv**.

## direnv + nix-direnv : le duo gagnant

[direnv](https://direnv.net/) est un utilitaire génial pour votre shell
(bash, zsh, fish). Son rôle est simple : charger automatiquement des
variables d'environnement quand vous entrez dans un dossier contenant un
fichier `.envrc`, et les décharger quand vous le quittez.

Mais attention : si on utilise simplement le hook Nix de base dans direnv,
l'évaluation du Flake à chaque `cd` peut prendre une ou deux secondes.
C'est agaçant.

Pour rendre l'expérience instantanée, il faut installer **nix-direnv**.
Il ajoute un mécanisme de cache intelligent : l'environnement n'est
réévalué que si votre fichier `flake.nix` ou `flake.lock` a bougé !

### Installation rapide

Si vous êtes sous NixOS ou utilisez Home-Manager, cela tient en
deux lignes :

```nix
programs.direnv = {
  enable = true;
  nix-direnv.enable = true;
};
```

Sur d'autres distributions ou macOS, suivez simplement les instructions du
dépôt officiel [nix-direnv](https://github.com/nix-community/nix-direnv).

Une fois installé, il suffit d'un fichier `.envrc` d'une seule ligne à la racine
de votre projet :

```bash
use flake
```

La première fois, direnv bloque l'exécution par sécurité. Il suffit de taper :

```bash
direnv allow
```

Et voilà ! Désormais, chaque `cd` dans votre projet charge instantanément vos
outils dans votre shell principal.

---

## Cas 1 : Le starter kit universel

Voyons à quoi ressemble un `flake.nix` minimaliste que vous pouvez copier-coller
dans n'importe lequel de vos dépôts.

```nix
{
  description = "Mon environnement de développement minimaliste";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      # Systèmes supportés (Linux Intel/ARM, macOS Intel/Apple Silicon)
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

Quelques remarques sur ce modèle :

- `pkgs.mkShell` est la fonction magique de Nix conçue spécifiquement pour
  fabriquer des shells de développement.
- La variable `packages` liste tous les binaires qui seront injectés dans
  votre `$PATH`.
- Le fichier `flake.lock` généré garantit que chaque personne qui clone le
  dépôt aura **au bit près** les mêmes versions de `git`, `curl` et `jq`.

---

## Cas 2 : En situation réelle, l'exemple de ce blog

Passons à un cas concret : le `flake.nix` utilisé pour faire tourner et builder
ce blog Hugo !

Dans un projet de blog ou de documentation, on ne veut pas seulement des
runtimes. On veut aussi des linters et des commandes personnalisées simples
pour l'équipe ou la CI.

Voici un extrait de ce qu'on utilise ici :

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

            # Des scripts utilitaires déclarés directement en Nix !
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
            echo " Bienvenue dans l'environnement du blog !        "
            echo " Hugo: $(hugo version | cut -d' ' -f2)"
            echo " Git:  $(git --version | cut -d' ' -f3)"
            echo "--------------------------------------------------"
            echo " Commandes disponibles :"
            echo "   build-hugo - Construit le site en mode optimisé"
            echo "   test-all   - Valide le build et passe le linter"
            echo "--------------------------------------------------"

            # Initialisation automatique des sous-modules Git si besoin
            if [ -d .git ] && [ ! -f "themes/PaperMod/theme.toml" ]; then
              echo "Initialisation des sous-modules..."
              git submodule update --init --recursive
            fi
          '';
        };
      });
    };
}
```

Notez l'astuce de `writeShellScriptBin` : plus besoin de maintenir un vieux
`Makefile` ou des scripts bash éparpillés à la racine du projet. Vos commandes
de build et de test sont packagées avec leurs dépendances et directement
accessibles dans le terminal.

Et le `shellHook` s'exécute automatiquement dès que direnv s'active, pratique
pour vérifier l'état du dépôt ou afficher un mémo des commandes.

---

## Cas 3 : Projet polyglotte & multi-runtimes

C'est ici que Nix enterre définitivement les alternatives comme asdf ou les
gestionnaires par langage (nvm, pyenv, rbenv, gvm...).

Imaginez une application complète :

- Un backend en **Go** ou **Python**.
- Un frontend en **Node.js** avec **pnpm**.
- Une base de données locale ou un client natif (**PostgreSQL**).
- Des bibliothèques C système (OpenSSL, zlib) nécessaires pour compiler
  certains modules natifs.

Avec un gestionnaire traditionnel, vous devez installer les outils un par un,
prier pour que les headers C correspondent à ce que votre distribution fournit,
et configurer manuellement vos variables d'environnement.

Avec Nix, tout tient dans une seule déclaration :

```nix
devShells = forAllSystems ({ pkgs }: {
  default = pkgs.mkShell {
    packages = with pkgs; [
      # Runtimes
      go_1_24
      nodejs_22
      nodePackages.pnpm
      python312Full

      # Outils CLI et bases de données
      postgresql_16
      sqls
      jq

      # Bibliothèques système
      openssl
      pkg-config
    ];

    # Variables d'environnement injectées dans le shell
    DATABASE_URL = "postgres://postgres:postgres@localhost:5432/app_dev";
    PORT = "8080";

    shellHook = ''
      # Configuration locale pour les outils qui écrivent des caches
      export GOPATH="$PWD/.cache/go"
      export PATH="$GOPATH/bin:$PATH"

      # Pour que pkg-config et les bindings C trouvent OpenSSL
      export PKG_CONFIG_PATH="${pkgs.openssl.dev}/lib/pkgconfig:$PKG_CONFIG_PATH"

      echo "Environnement polyglotte prêt !"
      echo "Go: $(go version)"
      echo "Node: $(node -v)"
    '';
  };
});
```

Vous changez de machine ou un nouveau développeur arrive sur le projet ?
Il tape `git clone`, fait un `cd`, valide avec `direnv allow`, et tout
fonctionne immédiatement. Aucun "chez moi ça marchait".

---

## Les bonnes pratiques au quotidien

Voici quelques astuces issues du terrain pour profiter de ce setup sans accroc :

### 1. Versionner `flake.lock`, ignorer `.direnv`

Le fichier `flake.lock` **doit être commité** dans Git : c'est lui qui verrouille
les commits précis de `nixpkgs` et garantit la reproductibilité.

En revanche, n'oubliez pas d'ajouter `.direnv` à votre `.gitignore` :
c'est le répertoire local où direnv stocke ses liens de cache.

### 2. Mettre à jour ses dépendances

Pour mettre à jour tous vos outils vers les dernières versions stables ou
instables fournies par votre canal :

```bash
nix flake update
```

Comme pour un `package-lock.json`, testez ensuite votre projet avant de pusher
la mise à jour du `flake.lock`.

### 3. Intégration IDE (VSCode / Neovim)

Pour que vos extensions d'éditeurs (LSP Go, ESLint, TypeScript, gopls...)
trouvent les bons binaires, installez l'extension **direnv** dans votre éditeur
(ex: *direnv* sur VSCode). Elle appliquera automatiquement les variables
d'environnement au workspace sans configuration supplémentaire.

### 4. Empêcher le garbage collector d'effacer vos devshells

Par défaut, `nix-collect-garbage` supprime tout ce qui n'est pas référencé par
votre système principal. Heureusement, `nix-direnv` enregistre automatiquement
des "racines GC" (gcroots) dans `.direnv/` pour que vos environnements de dev
actifs ne soient pas purgés lors d'un nettoyage.

---

## En résumé

Associer **Nix Flakes** et **direnv**, c'est s'offrir le meilleur des deux
mondes :

- La rigueur et la reproductibilité absolue de Nix.
- La simplicité invisible et sans friction de direnv au quotidien.

Plus besoin de jongler entre dix gestionnaires de versions différents ni de
lourds conteneurs pour travailler sereinement.

Et vous, quel est votre setup pour vos environnements de dev par projet ?
N'hésitez pas à partager vos retours ou vos astuces !
