# Jedi en quelques pages

Les exemples ci-dessous utilisent le lanceur `jedidemo`, installé au [chapitre 02](02_installer_et_preparer_jedi.md). Il conserve leurs données dans un espace de démonstration séparé du portefeuille réel.

## Une règle de conduite pour un trade

Jedi est une application en ligne de commande destinée à gérer des trades selon des règles définies à l'avance. Un **trade** regroupe les achats et les ventes d'un même titre, son barème, ses réglages et son historique.

Le **barème** relie les mouvements du cours à des quantités à acheter ou à vendre. À partir de l'état du trade, Jedi calcule les ordres à envisager. L'utilisateur les place chez son courtier, vérifie leur exécution et enregistre les opérations réellement réalisées.

Cette séparation permet de suivre une mécanique compréhensible : choisir les règles, observer les niveaux atteints, exécuter puis enregistrer. Une hausse ou une baisse prolongée, des frais élevés ou un manque de fonds peuvent toutefois rendre le parcours défavorable.

## Exploiter les fluctuations

Un aller-retour peut consister à vendre quelques titres après une hausse, puis à les racheter lors d'une baisse. Voici un exemple **fictif**, calculé avec Jedi :

~~~console
jedidemo --border=markdown tools play -c o0,6-14,17 -- \
  scale=vr:10%,np:3,nn:3,ki:10%,kb:1,kd:0,q0=100,c0=10,tick=0.01 1 -1
~~~

L'environnement créé indique un barème, 100 titres achetés à 10 € et un pas de cotation de 0,01 €. Les arguments `1 -1` demandent un échelon à la hausse, puis un échelon à la baisse. Le double tiret sépare les options des arguments du scénario.

Dans la sortie obtenue, l'achat initial est suivi de :

| Opération | Quantité | Prix | Montant | Stock après opération |
|---|---:|---:|---:|---:|
| Vente | 6 | 11,00 € | 66,00 € | 94 |
| Achat | 6 | 9,90 € | 59,40 € | 100 |

Le stock retrouve 100 titres et l'aller-retour apporte 6,60 € avant frais. Le cours final est cependant de 9,90 € : il faut aussi valoriser les titres restants pour connaître le résultat global. Un aller-retour positif et un trade globalement positif sont deux constats différents.

`tools play` sert ici à expliquer la mécanique. Il ne lit aucun historique et ne passe aucun ordre chez le courtier. Les types I et II de barèmes sont développés dans la partie II.

## Les trois décisions avant l'ouverture

| Étape | Question | Moyen possible |
|---|---|---|
| Choisir un titre | Quel titre examiner ? | Choix personnel, screener externe ou `tools profile` |
| Choisir un barème | Avec quelles règles l'étudier ? | Barème déjà choisi ou recherche avec `tools score` |
| Évaluer le projet | Peut-on ouvrir et poursuivre avec ces quantités et ces fonds ? | `tools candidate` |

Le choix du titre appartient à l'utilisateur. `profile` l'aide à établir une liste selon la tendance, la liquidité, la volatilité, l'oscillation et trois critères complémentaires. Ses statuts sont **retenu**, **vigilance** et **écarté**.

`score` simule différents barèmes sur l'historique du titre choisi. Son classement courant montre les résultats bruts, l'activité et l'investissement maximal. Le lecteur peut comprendre les critères de tri puis retenir une définition de barème.

`candidate` examine cette définition au prix fourni ou enregistré dans Jedi. Il vérifie les quantités utiles et le financement, compte tenu des trades déjà engagés. Un projet opérable peut demander trop de fonds ; un projet disposant de fonds peut produire des ordres trop petits.

Un backtest complémentaire permet d'examiner un barème fixé sur une période historique. Aucun de ces calculs ne transforme une sélection en ordre d'achat automatique.

## Le cycle de suivi

Une fois le trade ouvert, le travail courant consiste à actualiser le cours, consulter les ordres, suivre leur exécution chez le courtier, enregistrer les opérations et recalculer les ordres.

Un **ordre** est une instruction envisagée ou placée ; une **opération** est un achat ou une vente exécuté. Enregistrer une opération signifie décrire ce qui a réellement eu lieu, avec sa quantité et son prix.

Les événements exceptionnels méritent une trace : exécution partielle, annulation du solde d'un ordre, suspension, incident de cotation ou changement de réglage. Le journal `note` permet de conserver la date, le titre ou le nom du trade, les faits et la décision prise. Les chapitres 08 et 09 expliquent son usage.

## Les données dont on a besoin

La base principale conserve les titres utilisés, les trades, les paramètres, les opérations, les notes et les cours enregistrés. Une base de marché distincte conserve des historiques de cotations.

Cette seconde base est facultative. `score` et `backtest` peuvent lire un fichier individuel préparé ; `profile` peut aussi examiner ce fichier. Pour comparer une population de titres et gérer sa fraîcheur, on utilise une base de marché.

Un historique **OHLCV** contient, par séance, l'ouverture, le plus haut, le plus bas, la clôture et le volume. Un cours courant est une information ponctuelle. Importer un historique avec `market` n'actualise pas le cours de la base principale.

La commande `quote get` interroge les fournisseurs de cours ; elle ne met aucune base à jour. Les commandes d'enregistrement et de suivi sont expliquées dans les chapitres pratiques.

## Où poursuivre la lecture

Le chapitre 03 aide à choisir un titre. Les chapitres 04, 05 et 06 expliquent `profile`, `score` et `candidate`. Les chapitres 07 à 09 suivent un trade réel ; le chapitre 10 explique les fichiers et bases de marché.

La partie II détaille la mécanique avec `play` et `calc`. La partie III explique les backtests, les comparaisons de périodes et le suivi des résultats. Les annexes servent de référence pour les commandes, les fournisseurs, le screener externe et le vocabulaire.
