---
categories:
- Présentations
redirect_from:
- 2025/04/02/Et_on_recommence/
date: "2025-04-02T01:00:00+02:00"
tags:
- hugo
- CI
title: Mise en place d'une CI github pages pour Hugo
description: "Découvrez comment configurer une intégration continue (CI) pour déployer un site Hugo sur GitHub Pages."
---
Toi aussi, tu veux commencer ton blog, mais tu veux tout automatiser ?

Pour publier sur GitHub Pages, le mieux, c'est encore de passer par la CI.

On crée donc un fichier {{% include displayName="`.github/workflows/mon-site.yml` :" src=gh-pages.yml lang=yaml %}}

Commit et push...

C'est magique, on est en ligne...

Note : penser à mettre à jour la version d'Hugo de temps à autre.