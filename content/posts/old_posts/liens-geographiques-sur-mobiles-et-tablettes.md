---
categories:
- CAD-Killer
- HTML5
comments: true
date: "2015-02-21T00:00:00Z"
description: Je vais vous présenter la RFC 5870 qui permet de faire des liens géographiques
  compris par les smartphones et d'avoir la possibilité de faire un lien vers la fonction
  GPS.
cover:
  image: /assets/images/CodeWeb.jpg
published: "2015-02-21T00:00:00Z"
tags:
- CAD-Killer
- Cartes
- HTML5
- Android
- IOS
- RFC
title: Liens géographiques sur mobiles et tablettes
---

En avançant sur le développement de [CAD-Killer](/blog/2015/02/12/CAD-Killer/), j'ai voulu faire une
interface web-mobile. Et quoi de plus intéressant que de pouvoir faire une recherche
d'une adresse depuis son smartphone pendant la livraison ?

<!--more-->

Oui, mais voilà, l'affichage, c'est bien, la navigation... c'est encore mieux !

Heureusement, les développeurs ont pensé à tout !
La **[RFC 5870](http://tools.ietf.org/rfc/rfc5870)** permet de définir un lien vers des coordonnées géographiques.

Et ça donne quoi ?
------------------

Pour simplifier, c'est un lien au format URI :

~~~
geo:LAT,LON,ALT
~~~

LAT et LON sont en degrés décimaux, l'altitude en mètres est facultative.
On peut également ajouter des options :

- **crs** permet de spécifier le système de coordonnées.
  Par défaut, le système de coordonnées est le ***WGS-84*** (Mercator).
- **u** permet de renseigner l'imprécision.

Par exemple :

Voici l'[Arc de triomphe à Paris](geo:48.87379,2.29505)

{{< highlight html >}}
Voici l'<a href="geo:48.87379,2.29505">Arc de triomphe à Paris</a>
{{< / highlight >}}

Vous pouvez vérifier les coordonnées sur [OpenStreetMap](http://www.openstreetmap.org/?map=19/48.87379/2.29505#map=19/48.87379/2.29505)

Où est l'avantage de ces liens ?
--------------------------------

Les navigateurs web sur mobiles savent décoder ces liens nativement et vont automatiquement lancer l'application dédiée à l'affichage de carte et/ou à la navigation du système.

Ainsi, si vous n'avez pas personnalisé la configuration d'origine, depuis un appareil Android, cela ouvrira Google Maps,
et Plans sous IOS.

Et comme c'est un standard, les différentes plates-formes s'y adaptent sans que l'on change notre code pour chaque marque ou modèle de téléphone !