---
categories:
- tips
date: "2025-04-02T23:00:00+02:00"
tags:
- wsl
Language: fr
title: Réduire la taille du disque WSL
---
Au fur et à mesure de l'utilisation, l'image disque VHDX va grossir. Il faut alors la compacter !

## 1. Nettoyage

On va nettoyer un peu le disque. Pour le coup, chacun sa méthode.

## 2. fstrim

Maintenant que tout est propre, on peut forcer le système à vider les éléments non supprimés de l'image.
```shell
sudo fstrim -av
```

## 3. Installation de wslcompact

Le projet [wslcompact](https://github.com/okibcn/wslcompact), c'est un module PowerShell qui permet de compacter le disque efficacement.

```posh
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
iwr -useb https://raw.githubusercontent.com/okibcn/wslcompact/main/setup | iex
```

*Attention : sur les dernières versions de WSL (2.5.4.0 ?), il faut patcher le fichier comme dans [ce commit](https://github.com/gotenksIN/wslcompact/commit/8a39e5375b202848a03f122311f94fa7c01add86).*

## 4. Lancer le script

Cela va éteindre WSL, copier les données du disque dans un nouveau VHDX, puis le remplacer.

```posh
WslCompact -c -d
```
