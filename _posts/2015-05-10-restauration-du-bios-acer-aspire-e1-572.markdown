---
layout: post
title: Restauration du BIOS ACER Aspire E1-572
date: '2015-05-10 01:20'
tags:
  - ACER
  - BIOS
  - Tutoriel
  - Réparation
  - Installation
categories:
  - Réparation
  - Tutoriel
  - BIOS
icon: 'https://cr-48.wikispaces.com/file/view/insyde_h2o_bios.png/236343284/insyde_h2o_bios.png'
comment: true
---

Ce week-end alors que j'installais **ArchLinux** sur mon PC portable, le drame se produit: le BIOS me lache.

Cette panne est connue sous le nom de "Black Screen of the Death", cela se traduit par un ecran noir avec le rétro-éclairage mais rien ne se produit. Il ne faut pas le confondre avec la panne sur Windows qui apparait après le chargement de Windows et qui affiche un ecran noir avec le pointeur de la souris. <!--more--> ![Black Screen](http://www.logisticsct.com/blog/wp-content/uploads/2014/03/IMG_20140310_164816_372.jpg)

Après quelques recherches sur Internet, cela semble être un problème récurent chez ACER sur les modèles compatible EFI fonctionnant avec les BIOS _InsydeH2O_.

Très vite je trouve la manipulation, elle est simple a condition d'avoir le BIOS dans le bon format...

Oui mais voilà, trouver le bios dans le bon format n'est pas si simple, ACER ne fournit plus qu'un executable sous Windows pour flasher le BIOS.

Impossible d'en extraire le BIOS au format image ROM _(.fd pour les intimes)_.

Après de nombreuses recherches, voici le **BIOS pour l'E1-572** connu aussi sous le doux nom de **V5WE2**: [V5WE2X64.fd](https://mega.co.nz/#!F4IDSCpB!c5R0cQYoThvwyxXynpmmbxkhDu8ublTN-4PxLPyv8c8)

# Comment fait on pour restaurer cela?
<h2>Préparation</h2> Tout dabord, il faut vérifier que l'on ai bien le bon modèle.

Au dos du PC il y a une étiquette ACER, ou l'on peut lire "Model: V5WE2"

Si votre version est différente, ce n'est pas grave, notez la bien quand même.

Ensuite, il faut un deuxième PC, connecté à internet et une clé USB vierge < 8G car on va devoir la formater.

## On télécharge le BIOS
Si vous avez la même version que moi (E1-572 soit V5WE2), téléchargez ce fichier : **[V5WE2X64.fd](https://mega.co.nz/#!F4IDSCpB!c5R0cQYoThvwyxXynpmmbxkhDu8ublTN-4PxLPyv8c8)**

Sinon, tentez de faire une recherche avec le modèle suivi de **x64.fd**.

## C'est partit
Tout d'abord, on va formater la clé USB en FAT32 puis copier le fichier précédement téléchargé sur cette clé.

Une fois fini, déconnecter la clé "proprement".

On a fini la préparation.

## On FLASH!
**_ATTENTION!!! Flasher le BIOS peux endomager votre ordinateur. Si vous abimez votre matériel, je ne peux pas être tenu pour responsable!_**

On prend l'ordinateur à réparer:

- débrancher le cordon d'alimentation.
- débrancher tout périphériques (DD externe, Clé USB, souris...)
- Appuyer 10 secondes sur le bouton "**POWER**" _cela videra les condensateurs_
- brancher la clé USB que l'on à préparé juste avant.
- brancher le cordon d'alimentation
- presser simultanément les touches _**Fn**_ et _**Echap**_
- tout en maintenant préssé les touches, presser la touche "**POWER**" puis lachez la.
- le ventilateur s'affole, tout va bien :) vous pouvez relacher _**Fn**_ et _**Echap**_
- Après quelques secondes: 2 options
  - Vous entendez une serie de Bips et l'ordinateur redémarre sans améliorations:
    - Le BIOS que vous avez préparé ne fonctionne pas ou n'est pas bien nommé.
  - L'ordinateur redémarre et vous sautez de joie au plafond :)

**_ATTENTION!!! Le BIOS fournis ici contient un mot de passe, pour le retrouver, faites 2 ou 3 essais, vous verrez alors une clé numerique s'afficher, consultez alors ce site: [bios-pw.org](bios-pw.org) et entrez la clé pour connaitre votre mot de passe._**

Dans l'espoir que ce tutoriel vous aura aidé.
