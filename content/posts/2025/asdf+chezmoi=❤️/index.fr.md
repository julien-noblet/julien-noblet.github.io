---
title: asdf + chezmoi = ❤️
date: "2025-08-20T08:00:00+02:00"
tags:
- asdf
- Linux
- tools
- devops
- chezmoi
- dotfiles
- configuration
ShowToc: false
categories:
- tips
- tools
description: "Un aperçu de l'utilisation de chezmoi pour gérer vos versions d'outils avec asdf"
---

Lors d'un précédent billet, j'avais dit qu'on reviendrait sur les templates de [chezmoi](/posts/2025/chezmoi). Aujourd'hui, nous allons explorer comment utiliser ces templates pour gérer vos versions d'outils avec [asdf](/posts/2025/asdf).

## Les data

Chezmoi permet de définir une mini base de données pour stocker ce que vous voulez !
Ces données doivent être définies dans le dossier [.chezmoidata/](https://www.chezmoi.io/reference/special-directories/chezmoidata/).

Commençons par créer un fichier `asdf.yaml` dans ce dossier pour stocker les versions de nos outils.

{{% include displayName="`.chezmoidata/asdf.yaml` :" src=asdf.yaml lang=yaml %}}

## Les templates

Chezmoi permet d'utiliser des templates pour personnaliser vos fichiers de configuration. Vous pouvez utiliser des variables pour remplacer des valeurs dans vos fichiers.

Les templates chezmoi utilisent le langage de template Go. Plus précisément, ils utilisent la bibliothèque [text/template](https://pkg.go.dev/text/template) de Go pour le rendu des templates. Cela signifie que vous pouvez utiliser toutes les fonctionnalités de cette bibliothèque, y compris les fonctions, les pipelines et les conditions. [Voir la documentation](https://www.chezmoi.io/reference/templates/)

Ici, nous allons générer le fichier `~/.tool-versions` à partir des données définies dans `asdf.yaml`.

Petit rappel : le fichier commence par un point 👉 on devra donc utiliser `dot` pour le symboliser. On ajoute un `.tmpl` pour indiquer qu'il s'agit d'un template.

{{% include displayName="`~/dot_tool-versions.tmpl` :" src=dot_tool-versions.tmpl lang=yaml %}}

Simple, non ?

### Explication du template

- `{{ range .asdf.tools -}}` crée une boucle pour itérer sur chaque outil défini dans `asdf.yaml`.
- `{{ .name }} {{ .version }}` affiche le nom et la version de chaque outil.
- `{{ end }}` termine la boucle.

## Les scripts

Là où chezmoi excelle, c'est dans la gestion des scripts. Vous pouvez facilement définir des scripts à exécuter lors de la modification de certains fichiers.

Dans notre cas, chezmoi va bien mettre à jour notre `.tool-versions`, mais il peut aussi lancer les commandes nécessaires pour qu'asdf installe les outils !

En prime, on peut combiner la notion de templates et de scripts pour automatiser encore plus notre flux de travail.

Créons le fichier `run_onchange_dot_tool-versions.sh.tmpl` dans le dossier `.chezmoiscripts/`.

{{% include displayName="`.chezmoiscripts/run_onchange_dot_tool-versions.sh.tmpl` :" src=run_onchange_dot_tool-versions.sh.tmpl lang=bash %}}

### Explication du script

Je ne vais pas tout détailler mais seulement les grandes lignes :

- Le script commence par vérifier si le système d'exploitation est Linux.
- Il définit une fonction pour installer asdf.
- Il s'assure que le dossier nécessaire à l'installation d'asdf est présent.
- Il regarde si asdf est déjà installé, et si ce n'est pas le cas, il lance l'installation.
- Pour chaque outil, il contrôle que le plugin est installé et à jour.
- Pour chaque outil, il s'assure que la version spécifiée dans `~/.tool-versions` est installée.
- Enfin, pour chaque outil, il nettoie les anciennes versions.

## Conclusion

Nous avons vu comment utiliser chezmoi pour gérer les versions d'outils avec asdf. En combinant les templates et les scripts, nous pouvons automatiser notre flux de travail et nous assurer que nos outils sont toujours à jour. N'hésitez pas à explorer davantage les fonctionnalités de chezmoi et à les adapter à vos besoins.

Notez que les datas ne peuvent pas être templatisées (pour l'instant en tout cas).

Encore une fois, vous pouvez vous inspirer de [mes dotfiles](https://github.com/julien-noblet/dotfiles).
