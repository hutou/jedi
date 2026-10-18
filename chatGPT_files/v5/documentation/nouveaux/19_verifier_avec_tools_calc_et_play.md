# Vérifier avec tools calc et tools play

Une valeur isolée aide à comprendre un coefficient. Un parcours montre comment les opérations s'enchaînent, avec leurs arrondis, leurs changements de paramétrage et leurs protections. Jedi fournit les deux outils : `calc` pour un calcul de type I, `play` pour une simulation de type I ou II.

Une simulation définie directement dans la commande ne crée aucun trade et n'enregistre aucune opération dans la base principale. Les commandes `scale create` et `note create`, utilisées ailleurs dans cette partie, écrivent en revanche dans cette base : garder l'espace d'essai du [chapitre 02](02_installer_et_preparer_jedi.md#préparer-un-espace-dessai-séparé).

## Choisir le calcul utile

`tools calc` reçoit un barème de type I, une position et une fonction. La position s'écrit `x:y:e`, comme au [chapitre 12](12_positions_echelons_et_paliers.md).

| Fonction | Valeur calculée | Information supplémentaire |
|---|---|---|
| `kcb` | Coefficient de capital de base | Position |
| `kcp` | Coefficient de cours | Position |
| `ksp` | Coefficient de stock | Position |
| `cpe` | Cours théorique | `c0` |
| `spe` | Stock théorique | `q0` |
| `quantity` | Quantité entière à acheter ou vendre | `q0` et stock actuel |
| `price` | Prix arrondi au pas de cotation | `c0`, `tick` et sens |

Au premier palier supérieur, le stock théorique de notre type I vaut environ 78,571429 titres :

~~~console
jedidemo tools calc spe \
  scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1 \
  position=1:0:0 q0=100
jedidemo tools calc quantity \
  scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1 \
  position=1:0:0 q0=100 stock=80
~~~

Jedi arrondit le stock cible à 79. Depuis 80 titres, la quantité de l'ordre est donc **−1**, soit une vente d'un titre. Le résultat théorique décimal ne constitue pas une quantité d'ordre exécutable.

`calc` ne reproduit pas les frais, les protections ni la continuité d'un historique de paramétrages. Il refuse les barèmes de type II, dont les prix dépendent des exécutions précédentes. Pour ces situations, utiliser `play`.

## Définir un parcours avec play

La première donnée décrit le barème, le stock de référence, le cours de référence et le pas de cotation. Les suivantes décrivent les actions :

~~~console
jedidemo tools play -c o0,6-14,17 -- \
  "scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1,\
q0=100,c0=10,tick=0.01" 1 -1
~~~

Le séparateur `--` permet de transmettre les mouvements négatifs comme arguments. Les guillemets réunissent la définition en un seul argument ; le `\` final prolonge la ligne, sans espace ajouté au début de `q0`.

L'ouverture porte sur 100 titres à 10 €. La hausse vend 20 à 12 €, puis la baisse rachète 20 à 10 €. Le stock revient à 100 et l'investissement net hors frais devient 960 €.

| Action | Interprétation |
|---|---|
| `1`, `-1` | Un échelon de hausse ou de baisse |
| `2`, `-2` | Deux échelons successifs dans le sens indiqué |
| `"2x1,-1"` | Répéter deux fois le couple hausse, baisse |
| `8.00` | Aller vers le prix de 8 € |
| `"20@12"` | Achat manuel de 20 titres à 12 € |
| `"-20@12"` | Vente manuelle de 20 titres à 12 € |
| `mark` | Poser une marque après l'opération précédente |

**`8` signifie huit échelons ; `8.00` signifie un prix.** Un mouvement vers un prix peut traverser plusieurs ordres. Une opération manuelle termine normalement le parcours ; l'opération qui suit une réinitialisation `merge` bénéficie d'un traitement particulier, expliqué au [chapitre 16](16_continuite_entre_parametrages.md).

~~~console
jedidemo tools play -c o0,6-14,17 -- \
  "scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1,\
q0=100,c0=10,tick=0.01" "2x1,-1"
~~~

Ces deux allers-retours finissent avec 100 titres et 920 € d'investissement : 80 € de gain brut au cours final de 10 €.

## Simuler un regroupement avec reset ou merge

Ces simulations reproduisent le cas de 1 790 anciens titres regroupés en 179 nouveaux. Elles utilisent une définition littérale : aucun barème permanent ni trade n'est à créer. Le prix ancien de 0,80 € décrit l'opération de départ ; le prix de reprise de 12 € est déjà exprimé après regroupement.

Pour **reset** :

~~~console
jedidemo tools play -c co0,6-14,17 -- \
  "scale=vr:10%,ks:0.8,1.2,ki:0%,kb:0,q0=1790,c0=0.8,tick=0.01" \
  "split=1:10,reinit=reset,12" 1 -1
~~~

La section `c` affiche le paramétrage et la section `o` les opérations :

| Étape | Stock | Prix | Référence du nouveau paramétrage |
|---|---:|---:|---|
| Après split + reset, avant transaction | 179 | Reprise à 12 € | `q0=179`, `c0=12`, position `0:0:0` |
| Première hausse : vente de 36 titres nouveaux | 143 | 13,20 € | Même référence |
| Baisse suivante : achat de 36 titres nouveaux | 179 | 11,87 € | Même référence |

Le prix de 11,87 € reprend l'arrondi effectivement produit par Jedi avec le pas de 0,01 €. Le split n'est pas réappliqué après la première transaction.

Pour **merge**, reprendre l'état de départ dans une autre simulation :

~~~console
jedidemo tools play -c co0,6-14,17 -- \
  "scale=vr:10%,ks:0.8,1.2,ki:0%,kb:0,q0=1790,c0=0.8,tick=0.01" \
  "split=1:10,reinit=merge,12" "21@10.00" 1
~~~

Le paramétrage attend l'achat manuel. Après `21@10.00`, stock et `q0` valent 200 et `c0` vaut 11,79 €. La hausse suivante vend 40 titres à 11 €, laissant 160 titres. Le type II repart du prix réel de cette transaction manuelle pour le prochain mouvement.

La quantité `21` et le prix `10.00` décrivent les **nouvelles actions**, après le regroupement. Une vente manuelle s'écrit avec une quantité négative, par exemple `"-20@14.00"`. Jedi contrôle la vente par rapport au stock converti : `"-180@12.00"` serait refusé avec seulement 179 titres disponibles.

Les deux options appartiennent au même changement de paramétrage. `sync` ne peut accompagner cette combinaison. Après `merge`, fournir une transaction manuelle avant un déplacement automatique ou un prix cible ; sinon Jedi refuse le scénario. Dans le suivi réel, enregistrer uniquement la transaction effectivement exécutée.

## Choisir les tableaux affichés

| Lettre de `--command` | Lecture |
|---|---|
| `o` | Opérations et évolution du stock |
| `c` | Paramétrages et références |
| `r` | Ordres disponibles avant les opérations |
| `f` | Bilan financier brut |

On peut combiner les lettres, par exemple `--command=o0,6-14,17crf`. Le sélecteur `-c o0,6-14,17` conserve onze colonnes du tableau des opérations : identifiant, type, mode, quantité, prix, position, achats, ventes, résultat brut, investissement du trade et stock détenu. Le résultat brut valorise le stock au prix de chaque opération ; il ne se limite pas aux gains encaissés.

Pour afficher aussi les frais, ajouter la colonne `16` : `-c o0,6-14,16-17`. Pour joindre le bilan financier aux opérations sélectionnées, ajouter `f` : `-c o0,6-14,17f`. Avec `operation list`, saisir seulement les indices, sans la lettre `o` : `-c 0,6-14,17`.

Le tableau `r` montre les ordres **avant** chaque opération ; une flèche repère l'ordre suivi. Il ne faut pas prendre sa dernière ligne pour un état d'ordres recalculé après la toute dernière opération.

## Comparer les flux entre deux marques

Une marque découpe la lecture financière sans modifier le barème ni les ordres. Une seule marque est admise. Pour le bilan financier, la placer après une opération suivant l'ouverture : l'opération de base ne peut pas servir de marque.

~~~console
jedidemo tools play -c o0,6-14,17f -- \
  "scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1,\
q0=100,c0=10,tick=0.01" 1 -1 mark -1 1
~~~

L'aller-retour haussier produit 40 € de gain brut. Le second, baissier, produit encore 40 €. Le total vaut 80 € brut, **6,30 € de frais** et **73,70 € après frais** avec notre configuration à 0,35 %, sans minimum. Le tableau financier sépare les périodes avant et après la marque ; les frais se lisent dans les opérations si la colonne `16` est ajoutée au sélecteur.

Les changements de barème et les réinitialisations s'introduisent dans le parcours comme au chapitre 16. La définition peut aussi contenir `money` : vérifier alors `simulation.capital` et le mode `loss`, comme au [chapitre 18](18_capital_risque_et_dimensionnement.md).

## Partir d'une opération enregistrée

Au lieu d'une définition directe, `play` peut recevoir l'identifiant d'une opération réelle. Il réutilise son contexte pour examiner la suite sans modifier les opérations enregistrées :

~~~console
jedidemo tools play -c o0,6-14,17 -- 3 1 -1
~~~

Ici, **3 est un exemple d'identifiant**, à remplacer par celui d'une opération existant dans la base utilisée. Ce n'est pas un nom de trade ni une quantité.

Conserver la commande, la configuration et les résultats quand on compare deux réglages. `play` suit les mouvements que l'utilisateur lui fournit ; il ne mesure pas leur fréquence historique. La partie III expliquera comment `backtest` suit un fichier de cotations et quelles hypothèses il ajoute.
