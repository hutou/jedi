# Lire la structure d'un barème

Un barème associe les mouvements du cours à des variations du stock visé. Il ne décrit pas des transactions déjà réalisées. Jedi calcule une cible, puis la compare au stock effectivement détenu pour déterminer l'ordre suivant.

## Deux références : c0 et q0

Au premier achat, `c0` est le prix unitaire et `q0` la quantité. Avec 100 titres achetés à 10 €, les références valent `c0=10` et `q0=100`.

Un paramétrage ultérieur peut les reprendre, les adapter à un split ou les remplacer lors d'une réinitialisation. **`c0` n'est donc pas toujours le cours de la première opération, et `q0` n'est pas toujours le stock initial.** Ce ne sont pas non plus automatiquement le dernier cours et le stock courant.

Le **cours théorique** est le prix associé à une cible mécanique. Le **stock théorique** est la quantité que le barème voudrait détenir à cette cible. L'ordre utilise ensuite un prix conforme au pas de cotation et une quantité entière. Les exécutions réelles peuvent différer de ces valeurs.

## Lire les éléments du barème

Un coefficient est un multiplicateur : une référence de 10 € avec un coefficient de cours de 1,20 donne 12 €. Une référence de 100 titres avec un coefficient de stock de 0,80 donne 80 titres, avant les effets de palier.

| Élément | Ce qu'il règle |
|---|---|
| `kc` | Liste des coefficients de cours d'un type I. |
| `vr` | Taux de variation du prochain cours d'un type II. |
| `ks` | Liste des coefficients de stock, dans les deux types. |
| `ki` | Ajustement de la référence théorique de capital lors d'un saut. |
| `kb` | Convention de cet ajustement ; nos exemples courants utilisent `kb:1`. |
| `kd` | Répartition des variations de stock lorsque Jedi construit la liste `ks`. |
| `np`, `nn` | Bornes haute et basse d'un constructeur compact de type II. |

`ki` est distinct du risque `r` de gestion du capital. Un ajustement de palier de 10 % n'est ni un risque de portefeuille de 10 %, ni un gain promis.

## Nommer et numéroter un barème

À la création, **Jedi calcule le nom à partir du type produit par le builder**. Omettre `--name` dans `scale create` permet ce nommage automatique.

| Format du nom | Type opérationnel |
|---|---|
| `B_kc_NN` | Type I : cours déterminés par `kc`. |
| `B_vr_NN` | Type II : cours déterminés par `vr`. |

Tous les constructeurs de type I partagent `B_kc_NN`, qu'ils reçoivent `ks` ou construisent le stock avec `kd`. Les trois constructeurs de type II partagent `B_vr_NN` : liste `ks`, construction avec `kd`, ou forme Legacy avec `sr` et `mi`. Dans le code actuel, Legacy est bien de **type II**.

`NN` est le plus grand numéro déjà présent dans cette famille, augmenté de 1. La numérotation est indépendante pour les deux types : `B_kc_01` et `B_vr_01` peuvent donc coexister. Elle s'affiche sur au moins deux chiffres, puis continue avec `100`, `101`… Les numéros explicitement attribués sont pris en compte ; les trous de la séquence ne sont pas comblés tant qu'un numéro supérieur est présent.

**Une définition opérationnelle équivalente est refusée**, même si son constructeur est différent. Jedi compare le type, les coefficients de cours ou `vr`, les coefficients de stock, `ki`, `kb` et les bornes. Par exemple, `kc/kd` et `kc/ks` peuvent produire exactement les mêmes règles : ils correspondent alors à un seul barème à réutiliser. Le refus indique le nom et l'identifiant du barème existant. Il intervient avant l'attribution du nom automatique et ne consomme aucun numéro.

Le constructeur et le commentaire restent consultables avec `scale show`. Ils conservent la manière de construire le barème et son contexte ; le nom fournit son type et son numéro. Deux barèmes partageant quelques valeurs comme `vr` et `ki` peuvent encore avoir des définitions différentes.

`--name` reste disponible pour fixer une référence, mais le nom doit respecter le type du builder : `B_kc_NN` ou `B_vr_NN`, avec un numéro positif d'au moins deux chiffres. La casse et les zéros supplémentaires sont normalisés. Un numéro déjà attribué reste réservé, même si un ancien nom possède davantage de zéros. Les exemples fixent parfois un numéro pour conserver les références entre chapitres et variantes indépendantes ; l'usage courant consiste à laisser Jedi le choisir.

Les noms déjà enregistrés sont conservés. Un ancien barème peut être réutilisé sous son nom réel, ou renommé explicitement avec `scale update --name` dans le format correspondant. Les doublons présents dans une ancienne base restent également conservés, y compris lors de la restauration d'une sauvegarde. Les nouvelles créations et les modifications de définition ne peuvent pas en introduire d'autres ; `--force` ne contourne pas ce contrôle.

Pour changer une règle déjà utilisée, créer un nouveau barème puis lui associer un nouveau paramétrage préserve la définition de référence des anciennes opérations. Si la définition d'un barème numéroté est modifiée vers l'autre type, conformément aux protections de `scale update`, Jedi calcule son nouveau nom dans la famille correspondante, sauf si un nom conforme est fourni explicitement.

## Développer un type I simple

Enregistrer ce barème pédagogique dans une base d'essai :

~~~console
jedidemo scale create --name=B_kc_01 \
  --comment="Barème pédagogique de type I" \
  --builder="kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1"
jedidemo scale show B_kc_01
~~~

Créer ce nom une seule fois. S'il existe, consulter le barème avant de le réutiliser. Les autres exemples donnent souvent la définition directement à l'outil, sans créer de nom permanent.

Jedi ajoute les coefficients `1` à l'échelon zéro :

| Échelon | Coefficient de cours kc | Coefficient de stock ks |
|---|---:|---:|
| `+2`, borne supérieure | 1,40 | Saut vers le palier suivant |
| `+1` | 1,20 | 0,80 |
| `0` | 1,00 | 1,00 |
| `−1` | 0,80 | 1,20 |
| `−2`, borne inférieure | 0,60 | Saut vers le palier suivant |

Dans le premier palier, `+1` vise 80 titres à 12 € et `−1` vise 120 titres à 8 €. Aux bornes, Jedi change de palier et calcule de nouvelles références.

Jedi accepte des bornes allant de deux à six mouvements dans chaque sens, soit de un à cinq échelons intérieurs par côté. En type II compact, `np:3,nn:3` signifie trois mouvements jusqu'à chaque borne, avec deux échelons intérieurs de chaque côté.

## Distinguer les deux types

| Question | Type I | Type II |
|---|---|---|
| Prochain prix | Avec `kc` et les références du palier. | En appliquant `vr` au dernier prix d'exécution pertinent. |
| Stock cible | Avec `ks` et les références de stock. | Avec `ks` et les références de stock. |
| Hausse puis baisse | Dans un même palier, les coefficients désignent les mêmes niveaux. | Les pourcentages repartent du dernier prix ; le retour peut viser un autre niveau. |

Les [chapitres 14](14_comprendre_un_bareme_de_type_i.md) et [15](15_comprendre_un_bareme_de_type_ii.md) calculent ces différences. Le type ne prédit pas un résultat financier.

## Constructeur et définition développée

Le **constructeur** est le texte fourni à Jedi. La **définition canonique** est la règle développée et normalisée qu'il produit.

| Forme | Champs principaux |
|---|---|
| Type I, stock saisi directement | `kc`, `ks`, `ki`, `kb` |
| Type I, stock construit par Jedi | `kc`, `ki`, `kb`, `kd` |
| Type II, stock saisi directement | `vr`, `ks`, `ki`, `kb` |
| Type II, stock construit par Jedi | `vr`, `np`, `nn`, `ki`, `kb`, `kd` |
| Type II Legacy | `vr`, `np`, `sr`, `nn`, `mi`, `ki`, `kb` |

La définition développée expose toujours `ks`, même avec un constructeur utilisant `kd`. Le type I expose `kc`, le type II expose `vr`. `scale show` permet de lire le résultat avant de l'utiliser.

## Comprendre le mot optimisé

Jedi vérifie si la structure réduit le stock à la frontière haute et l'augmente à la frontière basse. Il emploie **optimisé** pour ce contrôle structurel.

Cette qualification ne mesure ni la rentabilité, ni les frais, ni les besoins du portefeuille. Avec des arrondis ou certains parcours de type II, il faut encore lire les ordres effectivement calculés. Le chapitre 17 montrera un Stop de fonctionnement.

Un constructeur optimisé est une méthode pour fabriquer `ks`. Une liste saisie directement peut aussi réussir le contrôle ; c'est le cas de `B_kc_01`.

Pour changer une règle déjà utilisée, créer un nouveau barème permet de conserver l'interprétation des anciennes opérations. Le [chapitre 16](16_continuite_entre_parametrages.md) explique comment lui associer un nouveau paramétrage daté.
