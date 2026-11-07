---
title: "GitOps jusqu'au bout : gérer ses secrets avec sops-nix et age"
date: "2026-11-07T16:40:00+01:00"
tags:
- nix
- nixos
- sops
- gitops
- security
- home-manager
categories:
- tips
- tools
- devops
description: >-
  "Comment gérer ses secrets de manière déclarative et sécurisée dans un dépôt
  Git avec sops-nix, age et ssh-to-age, aussi bien sous NixOS qu'avec
  Home-Manager."
---

Dans mon [article précédent sur Nix](/posts/2026/asdf-c-est-cool-nix-c-est-mieux/),
j'expliquais pourquoi j'avais adopté [Nix](/tags/nix/) et les Flakes pour
pousser la logique [GitOps](/tags/gitops/) jusqu'au bout : tout mon système
et mes outils sont décrits dans du code versionné.

Mais dès qu'on commence à tout mettre sur Git (surtout sur un dépôt public
ou partagé entre plusieurs machines), on se heurte très vite à un mur :
**qu'est-ce qu'on fait des secrets ?**

## Le paradoxe des secrets dans Nix

Sous [NixOS](/tags/nixos/), il y a deux pièges majeurs quand on manipule
un mot de passe, une clé privée ou un token d'API :

1. **Le dépôt Git** : on ne veut évidemment pas commiter un token en clair
   dans son `flake.nix` ou son `configuration.nix`.
2. **Le Nix Store (`/nix/store`)** : même si un fichier n'est pas poussé sur
   GitHub, tout ce qui est évalué et copié dans `/nix/store` par Nix devient
   **lisible par tous les utilisateurs de la machine** (`chmod 444`) !

Pendant longtemps, j'ai bricolé avec des fichiers déposés à la main sur chaque
machine ou avec `git-crypt`. Mais `git-crypt` chiffre des fichiers entiers de
manière opaque (adieu les `git diff` propres), se configure difficilement
par secret et ne résout pas le problème des permissions dans `/nix/store`.

C'est là qu'intervient **[sops-nix](https://github.com/Mic92/sops-nix)**.

## Pourquoi sops-nix + age ?

[SOPS](https://github.com/getsops/sops) (Secrets OPerationS), développé à
l'origine par Mozilla, permet de chiffrer uniquement les **valeurs** d'un
fichier YAML ou JSON tout en laissant les **clés** en clair. On sait donc
exactement quel secret a changé dans un commit, sans jamais exposer son contenu.

Couplé à **[age](https://github.com/FiloSottile/age)** (le successeur moderne
et minimaliste de GPG) et à **sops-nix**, le workflow devient magique :

- Les secrets sont stockés chiffrés dans Git (`secrets.yaml`).
- Au démarrage de la machine ou lors d'un `nixos-rebuild switch`, `sops-nix`
  déchiffre les secrets à la volée dans `/run/secrets/` (en RAM via `tmpfs`).
- Les secrets ne touchent **jamais** `/nix/store` en clair et ont des
  permissions strictes (`0400`, propriétaire dédié).

## Zéro clé supplémentaire grâce à `ssh-to-age`

Plutôt que de générer et sauvegarder un énième trousseau de clés, l'approche
la plus pragmatique consiste à s'appuyer sur des clés `ed25519` qui existent
déjà :

1. **Ma clé SSH personnelle** (`~/.ssh/id_ed25519`) : me permet d'éditer et
   chiffrer les secrets depuis mon poste de travail.
2. **La clé SSH hôte de la machine** (`/etc/ssh/ssh_host_ed25519_key`) : permet
   à [NixOS](/tags/nixos/) de déchiffrer ses secrets tout seul au boot, sans
   intervention humaine.

Avec l'outil `ssh-to-age`, on récupère les clés publiques au format `age` en
une commande :

```bash
# Récupérer la clé publique age de mon utilisateur
nix run nixpkgs#ssh-to-age -- -i ~/.ssh/id_ed25519.pub
# -> age1userxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Récupérer la clé publique age d'une machine cible (ici en local)
nix run nixpkgs#ssh-to-age -- -i /etc/ssh/ssh_host_ed25519_key.pub
# -> age1hostyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy
```

Et pour pouvoir éditer les fichiers avec la CLI `sops` sur mon poste, je
convertis une seule fois ma clé privée SSH en clé privée `age` :

```bash
mkdir -p ~/.config/sops/age
nix run nixpkgs#ssh-to-age -- -private-key -i ~/.ssh/id_ed25519 \
  > ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt
```

## Configurer `.sops.yaml`

À la racine de mon dépôt Nix, je crée un fichier `.sops.yaml` qui indique à
SOPS quelles clés ont le droit de déchiffrer quels fichiers :

```yaml
keys:
  - &user_julien age1userxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  - &host_serveur age1hostyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy

creation_rules:
  - path_regex: secrets/secrets\.yaml$
    key_groups:
      - age:
          - *user_julien
          - *host_serveur
```

## Créer et éditer le coffre-fort (`secrets.yaml`)

Pour créer ou modifier le fichier de secrets, on lance simplement `sops` :

```bash
nix run nixpkgs#sops -- secrets/secrets.yaml
```

SOPS ouvre alors `$EDITOR` avec le contenu en clair. Imaginons que l'on
veuille stocker deux secrets :

- `backup_api_token` : un token S3/Cloudflare utilisé par un service système
  de sauvegarde.
- `github_pat_token` : mon Personal Access Token GitHub utilisé par mes outils
  CLI côté utilisateur.

```yaml
backup_api_token: "cf_secret_token_987654321"
github_pat_token: "ghp_1234567890abcdefghijklmnopqrstuv"
```

Dès qu'on sauvegarde et quitte l'éditeur, SOPS chiffre le fichier. Voici ce qui
est réellement écrit sur le disque et commité dans Git :

```yaml
backup_api_token: ENC[AES256_GCM,data:3k8f...,type:str]
github_pat_token: ENC[AES256_GCM,data:9a1b...,type:str]
sops:
    age:
        - recipient: age1userxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
          enc: |
            -----BEGIN AGE ENCRYPTED FILE-----
            ...
```

## Cas n°1 : Injecter un secret système sous NixOS

On commence par ajouter `sops-nix` dans les `inputs` de notre `flake.nix` :

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, sops-nix, ... }: {
    nixosConfigurations.mon-serveur = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        sops-nix.nixosModules.sops
        ./configuration.nix
      ];
    };
  };
}
```

Ensuite, dans `configuration.nix`, on déclare où se trouve le fichier chiffré,
quelle clé hôte utiliser, et comment exposer `backup_api_token` :

```nix
{ config, pkgs, ... }:

{
  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    # Utilise directement la clé SSH de la machine pour déchiffrer
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    secrets."backup_api_token" = {
      owner = "restic";
      group = "restic";
      mode = "0400";
    };
  };

  # Exemple d'utilisation dans un service systemd
  systemd.services.mon-backup = {
    description = "Sauvegarde quotidienne";
    serviceConfig = {
      User = "restic";
      # config.sops.secrets."backup_api_token".path vaut /run/secrets/backup_api_token
      EnvironmentFile = [ ];
      ExecStart = pkgs.writeShellScript "run-backup" ''
        export API_TOKEN="$(cat ${config.sops.secrets."backup_api_token".path})"
        echo "Lancement du backup avec le token..."
      '';
    };
  };
}
```

Au prochain `nixos-rebuild switch`, le fichier `/run/secrets/backup_api_token`
apparaît en mémoire avec les droits `0400` appartenant uniquement à
l'utilisateur `restic`.

## Cas n°2 : Injecter un secret utilisateur avec Home-Manager

Pour les secrets propres à notre session utilisateur (comme un token GitHub,
une clé API pour ses outils CLI ou une config `.config/`), `sops-nix` fournit
également un module **[Home-Manager](/tags/home-manager/)** qui tourne sans
privilèges `root`.

Dans sa configuration Home-Manager (`home.nix`) :

```nix
{ config, pkgs, ... }:

{
  imports = [
    # Si sops-nix est passé dans extraSpecialArgs
    sops-nix.homeManagerModules.sops
  ];

  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    # Clé privée générée plus haut via ssh-to-age
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";

    secrets."github_pat_token" = {
      # Déchiffré dans $XDG_RUNTIME_DIR/secrets/github_pat_token
      path = "${config.xdg.configHome}/gh/token";
    };
  };

  # Exemple : exposer le token dans son shell à la demande
  programs.zsh.initContent = ''
    if [ -f "${config.sops.secrets."github_pat_token".path}" ]; then
      export GITHUB_TOKEN="$(cat ${config.sops.secrets."github_pat_token".path})"
    fi
  '';
}
```

Ici, un service systemd *user* (`sops-nix.service`) déchiffre automatiquement
nos secrets à l'ouverture de session dans `$XDG_RUNTIME_DIR/secrets/` (ou à
l'emplacement cible défini par `path`).

## Le workflow au quotidien

Une fois cette plomberie en place, la gestion des secrets au quotidien se
résume à trois commandes :

1. **Ajouter ou modifier un secret** :

   ```bash
   sops secrets/secrets.yaml
   ```

2. **Ajouter une nouvelle machine dans `.sops.yaml` et rechiffrer** :

   ```bash
   sops updatekeys secrets/secrets.yaml
   ```

3. **Déployer** :

   ```bash
   sudo nixos-rebuild switch --flake .
   ```

Plus aucun fichier `.env` oublié sur un coin de disque, plus de peur de rendre
son dépôt de dotfiles public, et une reproductibilité totale quand on réinstalle
une machine de zéro.

Bref, avec `sops-nix` et `age`, la boucle [GitOps](/tags/gitops/) est enfin
bouclée 🔒 !
