---
categories:
- Réparation
- Tutoriel
- BIOS
comments: true
date: "2015-05-10T00:00:00Z"
editDate: "2025-04-03T00:00:00Z"
cover:
  image: /assets/images/insyde_h2o_bios.png
  alt: insyde h2o bios logo
tags:
- ACER
- BIOS
- Tutoriel
- Réparation
- Installation
title: Restauration du BIOS ACER Aspire E1-572
description: Ce tutoriel explique comment restaurer le BIOS d'un ordinateur portable ACER Aspire E1-572 en cas de panne, connue sous le nom de "Black Screen of the Death". Il détaille les étapes nécessaires pour préparer une clé USB, télécharger le BIOS approprié, et effectuer le flashage en toute sécurité.
---

Ce week-end, alors que j'installais **ArchLinux** sur mon PC portable, le drame s'est produit : le BIOS m'a lâché.

Cette panne est connue sous le nom de "**Black Screen of the Death**". Cela se traduit par un écran noir avec le rétroéclairage, mais rien ne se produit. Il ne faut pas la confondre avec la panne sur Windows qui apparaît après le chargement de Windows et qui affiche un écran noir avec le pointeur de la souris. <!--more--> ![Black Screen](/assets/images/ACER-Aspire_E1-572-black.jpg)

Après quelques recherches sur Internet, cela semble être un problème récurrent chez ACER sur les modèles compatibles EFI fonctionnant avec les BIOS _InsydeH2O_.

Très vite, je trouve la manipulation. Elle est simple à condition d'avoir le BIOS dans le bon format...

Oui, mais voilà, trouver le BIOS dans le bon format n'est pas si simple. ACER ne fournit plus qu'un exécutable sous Windows pour flasher le BIOS.

Impossible d'en extraire le BIOS au format image ROM _(.fd pour les intimes)_.

Après de nombreuses recherches, voici le **BIOS pour l'E1-572**, connu aussi sous le doux nom de **V5WE2** : [V5WE2X64.fd](https://mega.nz/#!F4IDSCpB!c5R0cQYoThvwyxXynpmmbxkhDu8ublTN-4PxLPyv8c8)

## Comment fait-on pour restaurer cela ?
### Préparation ###
Tout d'abord, il faut vérifier que l'on a bien le bon modèle.

Au dos du PC, il y a une étiquette ACER où l'on peut lire "Model: V5WE2".

Si votre version est différente, ce n'est pas grave, notez-la bien quand même.

Ensuite, il faut un deuxième PC connecté à Internet et une clé USB vierge < 8 Go, car on va devoir la formater.

### On télécharge le BIOS
Si vous avez la même version que moi (E1-572, soit V5WE2), téléchargez ce fichier : **[V5WE2X64.fd](https://mega.nz/#!F4IDSCpB!c5R0cQYoThvwyxXynpmmbxkhDu8ublTN-4PxLPyv8c8)**

Sinon, tentez de faire une recherche avec le modèle suivi de **x64.fd**.

### C'est parti
Tout d'abord, on va formater la clé USB en FAT32, puis copier le fichier précédemment téléchargé sur cette clé.

Une fois terminé, déconnectez la clé "proprement".

On a fini la préparation.

### On FLASH !
**_ATTENTION !!! Flasher le BIOS peut endommager votre ordinateur. Si vous abîmez votre matériel, je ne peux pas être tenu pour responsable !_**

On prend l'ordinateur à réparer :

- Débranchez le cordon d'alimentation.
- Débranchez tous les périphériques (DD externe, clé USB, souris...).
- Appuyez 10 secondes sur le bouton "**POWER**" _cela videra les condensateurs_.
- Branchez la clé USB que l'on a préparée juste avant.
- Branchez le cordon d'alimentation.
- Pressez simultanément les touches _**Fn**_ et _**Échap**_.
- Tout en maintenant pressées les touches, pressez la touche "**POWER**", puis relâchez-la.
- Le ventilateur s'affole, tout va bien :) Vous pouvez relâcher _**Fn**_ et _**Échap**_.
- Après quelques secondes : 2 options :
  - Vous entendez une série de bips et l'ordinateur redémarre sans améliorations :
    - Le BIOS que vous avez préparé ne fonctionne pas ou n'est pas bien nommé.
  - L'ordinateur redémarre et vous sautez de joie au plafond 🙂

**_ATTENTION !!! Le BIOS fourni ici contient un mot de passe. Pour le retrouver, faites 2 ou 3 essais. Vous verrez alors une clé numérique s'afficher. Consultez ce site : [bios-pw.org](http://bios-pw.org) et entrez la clé pour connaître votre mot de passe._**

Dans l'espoir que ce tutoriel vous aura aidé.