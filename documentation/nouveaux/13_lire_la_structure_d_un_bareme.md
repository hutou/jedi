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

## Développer un type I simple

Enregistrer ce barème pédagogique dans une base d'essai :

~~~console
jedidemo scale create --name=PEDA-I \
  --comment="Barème pédagogique de type I" \
  --builder="kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1"
jedidemo scale show PEDA-I
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

La définition développée expose toujours `ks`, même avec un constructeur utilisant `kd`. Le type I expose `kc`, le type II expose `vr`. `scale show` permet de lire le résultat avant de l'utiliser.

## Comprendre le mot optimisé

Jedi vérifie si la structure réduit le stock à la frontière haute et l'augmente à la frontière basse. Il emploie **optimisé** pour ce contrôle structurel.

Cette qualification ne mesure ni la rentabilité, ni les frais, ni les besoins du portefeuille. Avec des arrondis ou certains parcours de type II, il faut encore lire les ordres effectivement calculés. Le chapitre 17 montrera un Stop de fonctionnement.

Un constructeur optimisé est une méthode pour fabriquer `ks`. Une liste saisie directement peut aussi réussir le contrôle ; c'est le cas de `PEDA-I`.

Pour changer une règle déjà utilisée, créer un nouveau barème permet de conserver l'interprétation des anciennes opérations. Le [chapitre 16](16_continuite_entre_parametrages.md) explique comment lui associer un nouveau paramétrage daté.
