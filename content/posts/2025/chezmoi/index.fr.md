---
title: Chezmoi, comment je gère mes dotfiles
date: "2025-04-06T16:00:00+02:00"
tags:
- chezmoi
- dotfiles
- configuration
- Linux
ShowToc: true
---
Il y a quelque temps, j'ai dû réinstaller mon environnement de travail Linux.

Comme d'habitude, j'ai commencé par configurer mes outils :
- git
- neovim
- rclone
- remettre mes clés SSH
- reconfigurer mon .bashrc 
- ...

Au bout de quelques ~~heures~~ jours, mon environnement était utilisable comme je l'aime.

Quelques semaines passent, je passe d'un Raspberry à un autre, d'une machine à une autre en pestant car mon environnement n'était pas forcément présent sur ces machines (à tort ou à raison).

Et puis ma machine me lâche. Je remplace le poste et c'est reparti pour configurer mon environnement.

Je change de disque, rebelote... Une carte SD crame dans un Raspberry... On recommence...

J'adopte un nouvel outil et je regrette de ne pas le retrouver sur mes autres machines...

Jusqu'au jour où j'ai décidé de ne plus laisser le sort décider de ma productivité !

## J'ai découvert Chezmoi ##
[Chezmoi](https://www.chezmoi.io/) est un outil qui va simplifier la maintenance et le déploiement de vos environnements que ce soit à la maison, au travail, sur votre poste de dev, une session d'admin...

OK, mais ça se présente comment ?

Chezmoi, c'est un gestionnaire de DOTFILES, vous savez les fichiers qui commencent par un `.` dans votre `$HOME`.

En fait, Chezmoi va vous permettre de stocker vos fichiers de configuration dans un git.

Oui enfin, pousser des fichiers dans un repo git, pas besoin d'un outil pour ça...

Détrompez-vous ! 
Là où est la magie, c'est qu'il va vous permettre de scripter, de templater, de chiffrer ces dotfiles.

Il va aussi vous permettre de vous prévenir que votre environnement n'est plus synchronisé avec le repo distant et vous proposer de mettre à jour votre environnement.

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
Si vous avez un compte GitHub, je vous invite à créer un repository "dotfiles".

Maintenant, on initialise :
```bash
chezmoi init --ssh <mon_user_github> --apply
```
(Si vous n'avez pas de compte GitHub, ou souhaitez mettre vos dotfiles ailleurs, [consultez la doc](https://www.chezmoi.io/reference/commands/init/))


Maintenant :
```bash
chezmoi add ~/.bashrc
```

Faites une modification sur le fichier, puis faites un `chezmoi apply`, le fichier est revenu comme à l'origine !

Allez dans le dossier de travail de chezmoi `chezmoi cd`, vous y trouverez votre bashrc sous le nom `dot_bashrc`.

Chezmoi utilise une norme de nommage pour mettre des attributs sur vos fichiers, si cela vous intéresse, [direction la doc](https://www.chezmoi.io/reference/target-types/)

Vous pouvez aussi templater et scripter tout cela !

(On y reviendra)

# Si vous voulez des exemples : 
 - [felipecrs/dotfiles](https://github.com/felipecrs/dotfiles) (dont je me suis pas mal inspiré)
 - [renemarc/dotfiles](https://github.com/renemarc/dotfiles) (idem)
 - [Mes dotfiles](https://github.com/julien-noblet/dotfiles)