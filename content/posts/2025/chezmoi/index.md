---
title: Chezmoi, comment je gère mes dotfiles
date: "2025-04-03T08:00:00+02:00"
tags:
- chezmoi
- dotfiles
- configuration
- Linux
ShowToc: true
---
Il y a quelques temps, j'ai dû réinstaller mon environnement de travail Linux.

Comme d'habitude, j'ai commencé par configurer mes outils :
- git
- neovim
- rclone
- remettre mes clés SSH
- reconfigurer mon .bashrc 
- ...

Au bout de quelques ~~heures~~ jours, mon environnement était utilisable comme j'aime.

Quelques semaines passent, je passe d'un Raspberry à un autre, d'une machine à une autre en pestant car mon environnement n'était pas forcément présent sur ces machines (à tort ou à raison).

Et puis ma machine me lâche. Je remplace le poste et c'est reparti pour configurer mon environnement.

Je change de disque, rebelote... Une carte SD crame dans un Raspberry... On recommence...

J'adopte un nouvel outil et je regrette de ne pas le retrouver sur mes autres machines...

Jusqu'au jour où j'ai décidé de ne plus laisser le sort décider de ma productivité !

## J'ai découvert Chezmoi ##
[Chezmoi](https://www.chezmoi.io/) c'est un outil qui va simplifier la maintenance et le déploiement de vos environnements que ce soit à la maison, au travail, sur votre poste de dev, une session d'admin...

OK, mais ça se présente comment ?

Chezmoi, c'est un gestionnaire de DOTFILES, vous savez les fichiers qui commencent par un `.` dans votre `$HOME`.

En fait, Chezmoi va vous permettre de stocker vos fichiers de configuration dans un git.

Oui enfin pousser des fichiers dans un repo git, pas besoin d'un outil pour ça...

Détrompe-toi ! 
Là où est la magie, c'est qu'il va te permettre de scripter, de templater, de chiffrer ces dotfiles.

Il va aussi te permettre de te prévenir que ton environnement n'est plus synchronisé avec le repo distant et te proposer de mettre à jour ton environnement.

## Installation ##

On va l'installer avec [ASDF](/posts/2025/asdf) 

```bash
asdf plugin install chezmoi && asdf install chezmoi latest && asdf set -u chezmoi latest
```
On va aussi installer [AGE](https://age-encryption.org/), il nous servira pour chiffrer nos secrets.
```bash
asdf plugin install age && asdf install age latest && asdf set -u age latest
```

On va aussi préparer le repo git que l'on va utiliser pour publier/sauvegarder nos fichiers.
Si vous avez un compte github, je vous invite à créer un repository "dotfiles".

Maintenant on initialise:
```bash
chezmoi init --ssh <mon_user_github> --apply
```
(Si vous n'avez pas de compte github, ou souhaitez mettre vos dotfile ailleur, [consultez la doc](https://www.chezmoi.io/reference/commands/init/))

