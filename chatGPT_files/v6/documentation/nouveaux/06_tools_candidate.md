# Évaluer une ouverture avec tools candidate

## Deux questions avant d'ouvrir

`candidate` évalue un projet de trade au prix fourni ou enregistré. Il vérifie :

- son **opérabilité** : les quantités permettent-elles d'obtenir les ordres utiles contrôlés ?
- son **financement** : les fonds libres couvrent-ils l'ouverture et les achats supplémentaires projetés ?

Ces deux résultats restent distincts. La commande ne recherche pas le titre et ne sélectionne pas son barème. Elle ne nécessite aucun historique OHLCV, ne crée pas le trade et ne passe aucun ordre.

## Identifier le titre, le prix et le barème

L'argument du candidat est un **ISIN**, pas un ticker. Une cotation explicitement fournie par `--price` remplace le cours de la base principale. Elle permet même d'examiner un titre qui n'y est pas encore enregistré.

Sans `--price`, le titre doit posséder un cours enregistré dans la base principale. Le rapport indique l'origine et, pour ce cours enregistré, la date connue. La dernière clôture d'une base de marché n'est pas utilisée automatiquement.

Un prix saisi n'emprunte pas la date d'une ancienne cotation enregistrée. À l'utilisateur de vérifier la date et la pertinence du prix qu'il fournit.

`--scale` accepte le nom d'un barème existant ou une définition littérale. Après `score`, reprendre le constructeur sans son préfixe d'affichage `I:` ou `II:`.

## Choisir le montant d'ouverture

Voici un exemple **fictif**, sur une base principale sans autre trade engagé :

~~~console
jedidemo tools candidate FR4487601001 --price=10 \
  --scale="vr:10%,np:3,nn:3,ki:10%,kb:1,kd:0" \
  --amount=1000 --capital=5000
~~~

`--amount=1000` fixe le montant souhaité pour le premier achat. À 10 €, il correspond à 100 titres. Pour un prix qui ne divise pas exactement le montant, Jedi retient une quantité entière par défaut ; le montant réellement engagé peut être inférieur à la demande.

`--capital=5000` fournit le capital du portefeuille pour vérifier le financement. Ce capital et le montant d'ouverture ont des rôles différents.

Sortie obtenue :

~~~text
Quantité initiale :              100
Montant réel d'ouverture :       1000.00 €

Opérabilité :                    OUI
Financement :                    OUI
Capital libre après réserve :    5000.00 €
Besoin maximal du candidat :     1187.83 €
Marge après candidat :           3812.17 €
Réserve du candidat calculée sur 3 échelons ; financement hors frais.
~~~

Le projet demande davantage que son achat initial : 187,83 € supplémentaires sont réservés pour le parcours projeté. Le barème est également affiché sous sa définition opérationnelle complète.

## Dimensionner avec la gestion du capital

La seconde forme utilise `--money` à la place de `--amount` :

~~~console
jedidemo tools candidate FR4487601001 --price=10 \
  --scale="vr:10%,np:3,nn:3,ki:10%,kb:1,kd:0" \
  --money="r:1%,o:1,n:2" --capital=10000 --extended
~~~

Les valeurs choisies servent ici à expliquer le calcul.

| Paramètre | Signification |
|---|---|
| `r` | Part du capital utilisée pour calculer le risque monétaire. |
| `n` | Nombre d'échelons baissiers servant à calculer la distance du StopLoss. |
| `o` | Coefficient de l'objectif monétaire utilisé pour la protection des gains. |

Avec 10 000 € et `r:1%`, le risque calculé est de 100 €. Le barème donne, à deux échelons sous 10 €, un cours théorique de 8,10 €, soit une distance de 19 %. Cette distance conduit à un montant théorique de 526,32 € et à 52 titres pour 520 €.

L'affichage étendu donne notamment :

~~~text
Risque monétaire R :             100.00 €
Quantité initiale :              52
Montant réel d'ouverture :       520.00 €
Quantité minimale opérable :     32
Opérabilité :                    OUI
Besoin maximal du candidat :     617.56 €
Marge après candidat :           9382.44 €
~~~

Le calcul tient aussi compte de la limite de capital sur le trajet de risque et des quantités minimales utiles. Il peut refuser l'ouverture lorsqu'aucune quantité entière ne satisfait l'ensemble des contraintes.

Sans `--capital`, Jedi utilise le capital configuré pour les trades. Si aucun capital positif n'est disponible, le financement peut être affiché « non évalué » ; cela ne signifie pas qu'il a été validé.

## Choisir r, o et n en pratique

Commencer par exprimer le risque en euros, puis le rapporter au capital choisi. Avec 10 000 €, 1 % représente 100 € et 2 % représente 200 €. Augmenter `r` augmente le risque accepté et peut augmenter la quantité ; ce n'est pas un moyen neutre de faire disparaître un refus.

Choisir `n` après lecture du barème : deux échelons ne représentent pas le même pourcentage selon la taille des mouvements. Un nombre d'échelons plus élevé donne généralement un StopLoss plus éloigné et, à risque monétaire identique, une quantité initiale plus faible.

La comparaison suivante reprend trois commandes exécutées sur notre exemple, en changeant un seul paramètre :

| Capital | r | n | Distance calculée | Quantité | Achat initial | Besoin maximal hors frais |
|---:|---:|---:|---:|---:|---:|---:|
| 10 000 € | 1 % | 2 | 19,00 % | 52 | 520 € | 617,56 € |
| 10 000 € | 2 % | 2 | 19,00 % | 105 | 1 050 € | 1 253,22 € |
| 10 000 € | 1 % | 3 | 27,10 % | 36 | 360 € | 425,88 € |

Voici les trois commandes complètes, dans le même ordre que les lignes de la table :

~~~console
jedidemo tools candidate FR4487601001 --price=10 \
  --scale="vr:10%,np:3,nn:3,ki:10%,kb:1,kd:0" \
  --money="r:1%,o:1,n:2" --capital=10000 --extended

jedidemo tools candidate FR4487601001 --price=10 \
  --scale="vr:10%,np:3,nn:3,ki:10%,kb:1,kd:0" \
  --money="r:2%,o:1,n:2" --capital=10000 --extended

jedidemo tools candidate FR4487601001 --price=10 \
  --scale="vr:10%,np:3,nn:3,ki:10%,kb:1,kd:0" \
  --money="r:1%,o:1,n:3" --capital=10000 --extended
~~~

`o` multiplie le risque monétaire pour définir l'objectif utilisé par la protection des gains. Avec un risque de 100 €, `o:1` donne un objectif de 100 €, `o:2` de 200 €. Il ne fixe pas directement la quantité initiale. Le déclenchement dépend du résultat projeté après `n` échelons de baisse et du parcours du trade ; ce n'est pas simplement « vendre dès que le gain courant atteint 100 € ».

Pour commencer les essais pédagogiques, garder `o:1,n:2` et modifier un paramètre à la fois rend les comparaisons lisibles. Ces valeurs d'exemple ne déterminent pas à elles seules un risque approprié à chaque investisseur. Le chapitre 18 et `tools play` montreront les effets sur les ordres de protection.

Un StopLoss peut être exécuté au-delà du prix calculé, notamment lors d'un gap. Le risque calculé ne constitue donc pas une borne garantie de perte. Examiner également le risque cumulé des trades engagés.

## Comprendre l'opérabilité

L'opérabilité vérifie que les ordres utiles gardent une quantité suffisante. Le défaut est de deux titres minimum par ordre et de trois échelons haussiers contrôlés, selon `diagnostic_steps` dans la configuration.

Les options `--minimum-quantity` et `--operability-steps` permettent de changer ce contrôle. Réduire ces exigences change la question posée ; cela ne résout pas automatiquement les frais ou la liquidité.

Sur notre barème, le minimum initial calculé est de 32 titres. Avec un capital de 5 000 €, `r:1%,o:1,n:2` ne permet que 26 titres selon le risque. Le projet est refusé pour quantité insuffisante. L'affichage indique une quantité d'ouverture nulle et le motif ; la base dispose pourtant de capital libre.

## Comprendre les réserves et le financement

Jedi prend le capital du portefeuille, retire l'investissement net courant, puis réserve les achats supplémentaires projetés des trades possédant encore des titres. Il reste le **capital libre après réserve**.

Pour le candidat, le besoin maximal est l'achat initial plus sa propre réserve. La **marge après candidat** est le capital libre après réserve diminué de ce besoin.

La projection explore les trajectoires à la hausse et à la baisse sur l'horizon retenu. Pour la réserve, cet horizon vaut `diagnostic_steps`, porté à `n` si le candidat utilise une gestion du capital avec un `n` supérieur. Il ne se confond pas avec l'option d'opérabilité.

Les frais sont exclus de cette projection de financement. Les besoins au-delà de l'horizon, les nouvelles décisions et les conditions réelles d'exécution peuvent changer le résultat. Garder une marge pour ces différences.

Avec la même ouverture de 1 000 € et seulement `--capital=1000`, on obtient :

~~~text
Opérabilité :                    OUI
Financement :                    NON
Besoin maximal du candidat :     1187.83 €
Marge après candidat :           -187.83 €
~~~

Le premier achat est possible en montant, mais les fonds ne couvrent pas la réserve projetée. Un prix favorable ou un bon résultat historique ne change pas ce calcul.

## Quand des trades ont déjà dépassé R

Une perte supérieure au risque calculé `R` peut survenir, par exemple après un gap ou une interruption du suivi. La gestion du capital `money` ne peut pas rétablir rétroactivement cette limite. Lors du calcul des ordres, Jedi peut signaler qu'un trade est hors contrôle lorsque sa perte au cours courant dépasse `R`.

**`candidate` ne bloque pas automatiquement une nouvelle ouverture pour ce motif.** Il ne vérifie pas les pertes courantes des autres trades par rapport à leur `R`. Il continue à compter tous les trades possédant encore des titres dans les réserves, même ceux qui ont dépassé ce risque. La réserve est projetée à partir de leur dernier état enregistré et de leur barème, sur l'horizon prévu ; elle ne suppose pas qu'un StopLoss a liquidé le trade.

Le financement utilise l'investissement net, c'est-à-dire les achats moins les ventes enregistrés dans la base principale. Il ne remplace pas cet engagement par la valeur des titres au cours courant. Une vente à perte enregistrée affecte donc les fonds calculés ; une perte encore latente n'est pas déduite comme un budget de risque supplémentaire. Le capital servant à calculer le `R` du candidat reste celui fourni par `--capital` ou la configuration. Il n'est pas recalculé automatiquement à partir des pertes des autres trades.

Avec plusieurs trades dans cette situation, `candidate` peut ainsi afficher « financement : OUI » si les fonds couvrent l'engagement et les réserves. Ce résultat valide ce calcul de financement ; il ne valide pas le risque cumulé du portefeuille ni la poursuite des trades en difficulté.

Pour examiner les alertes des trades existants, utiliser :

~~~console
jedidemo trade orders
~~~

L'affichage étendu de `candidate`, obtenu avec `--extended` dans les commandes ci-dessus, détaille l'investissement net, la réserve totale et la réserve de chaque trade. Consigner les incidents et décisions exceptionnelles avec `note`, en identifiant le trade concerné ; enregistrer séparément les opérations réellement exécutées.

## Lire un refus avant de modifier le projet

| Résultat | À vérifier |
|---|---|
| Aucun cours disponible | Fournir un prix valide ou enregistrer une cotation du titre. |
| Quantité initiale nulle | Montant, prix et quantité entière. |
| Quantité insuffisante | Barème, quantités utiles et paramètres du risque. |
| Capital limitant | Achat initial et investissement projeté sur le trajet de risque. |
| Marge négative | Fonds libres et réserves des trades existants et du candidat. |

L'option `--extended` donne les détails utiles. Les prix, montants et capitaux doivent être positifs et finis ; `--amount` et `--money` sont incompatibles.

Avant l'ouverture, conserver l'ISIN, le prix vérifié, la définition du barème, les paramètres et le rapport. Le chapitre 07 explique ensuite l'ouverture chez le courtier et l'enregistrement effectif dans Jedi.
