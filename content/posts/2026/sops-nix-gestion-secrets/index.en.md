---
title: "GitOps all the way: managing secrets with sops-nix and age"
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
  "How to declaratively and securely manage secrets in a Git repository using
  sops-nix, age, and ssh-to-age across both NixOS and Home-Manager."
---

In my [previous article about Nix](/en/posts/2026/asdf-c-est-cool-nix-c-est-mieux/),
I explained why I switched to [Nix](/en/tags/nix/) and Flakes to push the
[GitOps](/en/tags/gitops/) philosophy all the way: my entire system and tools
are defined in versioned code.

However, as soon as you start putting everything into Git (especially in a
public repository or one shared across multiple machines), you quickly hit a
wall: **what do we do with secrets?**

## The secrets paradox in Nix

On [NixOS](/en/tags/nixos/), there are two major pitfalls when handling a
password, a private key, or an API token:

1. **The Git repository**: obviously, you don't want to commit a cleartext
   token into your `flake.nix` or `configuration.nix`.
2. **The Nix Store (`/nix/store`)**: even if a file isn't pushed to GitHub,
   anything evaluated and copied into `/nix/store` by Nix becomes
   **world-readable by every user on the machine** (`chmod 444`)!

For a long time, I tinkered with files manually copied onto each machine or
used `git-crypt`. However, `git-crypt` encrypts entire files opaquely (say
goodbye to clean `git diff`s), is tedious to configure per secret, and does
not solve the `/nix/store` permissions issue.

That is where **[sops-nix](https://github.com/Mic92/sops-nix)** comes in.

## Why sops-nix + age?

[SOPS](https://github.com/getsops/sops) (Secrets OPerationS), originally
developed by Mozilla, encrypts only the **values** in a YAML or JSON file
while leaving the **keys** in cleartext. You always know exactly which secret
changed in a commit without ever exposing its value.

Combined with **[age](https://github.com/FiloSottile/age)** (the modern,
minimalist successor to GPG) and **sops-nix**, the workflow becomes seamless:

- Secrets are stored encrypted inside Git (`secrets.yaml`).
- At boot time or during a `nixos-rebuild switch`, `sops-nix` decrypts the
  secrets on the fly into `/run/secrets/` (in RAM via `tmpfs`).
- Secrets **never** touch `/nix/store` in cleartext and get strict permissions
  (`0400`, dedicated owner).

## Zero extra keys thanks to `ssh-to-age`

Rather than generating and backing up yet another keyring, the most pragmatic
approach is to rely on the `ed25519` keys we already have:

1. **My personal SSH key** (`~/.ssh/id_ed25519`): allows me to edit and encrypt
   secrets from my workstation.
2. **The machine's host SSH key** (`/etc/ssh/ssh_host_ed25519_key`): allows
   [NixOS](/en/tags/nixos/) to decrypt its secrets automatically at boot
   without human intervention.

Using `ssh-to-age`, we can derive the `age` public keys with a single command:

```bash
# Get my user's age public key
nix run nixpkgs#ssh-to-age -- -i ~/.ssh/id_ed25519.pub
# -> age1userxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Get the target machine's age public key
nix run nixpkgs#ssh-to-age -- -i /etc/ssh/ssh_host_ed25519_key.pub
# -> age1hostyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy
```

To edit encrypted files with the `sops` CLI on my workstation, I convert my
private SSH key into an `age` private key once:

```bash
mkdir -p ~/.config/sops/age
nix run nixpkgs#ssh-to-age -- -private-key -i ~/.ssh/id_ed25519 \
  > ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt
```

## Configuring `.sops.yaml`

At the root of my Nix repository, I create a `.sops.yaml` file that tells SOPS
which keys are allowed to decrypt which files:

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

## Creating and editing the vault (`secrets.yaml`)

To create or edit the secrets file, simply run `sops`:

```bash
nix run nixpkgs#sops -- secrets/secrets.yaml
```

SOPS opens `$EDITOR` with the cleartext content. Let's store two secrets:

- `backup_api_token`: an S3/Cloudflare token used by a system backup service.
- `github_pat_token`: my GitHub Personal Access Token used by user-level CLI
  tools.

```yaml
backup_api_token: "cf_secret_token_987654321"
github_pat_token: "ghp_1234567890abcdefghijklmnopqrstuv"
```

As soon as we save and close the editor, SOPS encrypts the file. Here is what
is actually written to disk and committed to Git:

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

## Case #1: Injecting a system secret on NixOS

First, we add `sops-nix` to the `inputs` of our `flake.nix`:

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

Next, in `configuration.nix`, we declare where the encrypted file lives, which
host key to use, and how to expose `backup_api_token`:

```nix
{ config, pkgs, ... }:

{
  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    # Directly use the machine's SSH host key to decrypt
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    secrets."backup_api_token" = {
      owner = "restic";
      group = "restic";
      mode = "0400";
    };
  };

  # Example usage in a systemd service
  systemd.services.mon-backup = {
    description = "Daily backup";
    serviceConfig = {
      User = "restic";
      # config.sops.secrets."backup_api_token".path resolves to /run/secrets/backup_api_token
      EnvironmentFile = [ ];
      ExecStart = pkgs.writeShellScript "run-backup" ''
        export API_TOKEN="$(cat ${config.sops.secrets."backup_api_token".path})"
        echo "Running backup with token..."
      '';
    };
  };
}
```

On the next `nixos-rebuild switch`, `/run/secrets/backup_api_token` appears in
memory with `0400` permissions owned exclusively by the `restic` user.

## Case #2: Injecting a user secret with Home-Manager

For secrets scoped to our user session (such as a GitHub token, an API key for
CLI tools, or a `.config/` file), `sops-nix` also provides a
**[Home-Manager](/en/tags/home-manager/)** module that runs without `root`
privileges.

In our Home-Manager configuration (`home.nix`):

```nix
{ config, pkgs, ... }:

{
  imports = [
    # Assuming sops-nix is passed via extraSpecialArgs
    sops-nix.homeManagerModules.sops
  ];

  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    # Private key generated earlier via ssh-to-age
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";

    secrets."github_pat_token" = {
      # Decrypted to $XDG_RUNTIME_DIR/secrets/github_pat_token
      path = "${config.xdg.configHome}/gh/token";
    };
  };

  # Example: expose the token in the shell on startup
  programs.zsh.initContent = ''
    if [ -f "${config.sops.secrets."github_pat_token".path}" ]; then
      export GITHUB_TOKEN="$(cat ${config.sops.secrets."github_pat_token".path})"
    fi
  '';
}
```

Here, a systemd *user* service (`sops-nix.service`) automatically decrypts our
secrets upon login into `$XDG_RUNTIME_DIR/secrets/` (or the target `path` we
defined).

## Daily workflow

Once this plumbing is in place, day-to-day secret management comes down to
three commands:

1. **Add or update a secret**:

   ```bash
   sops secrets/secrets.yaml
   ```

2. **Add a new machine in `.sops.yaml` and re-encrypt the vaults**:

   ```bash
   sops updatekeys secrets/secrets.yaml
   ```

3. **Deploy**:

   ```bash
   sudo nixos-rebuild switch --flake .
   ```

No more forgotten `.env` files lying around on disk, no more fear of making a
dotfiles repository public, and full reproducibility when rebuilding a machine
from scratch.

In short, with `sops-nix` and `age`, the [GitOps](/en/tags/gitops/) loop is
finally complete 🔒!
