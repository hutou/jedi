# Générer les PDF / Build the PDFs

## Français

Le fichier **`fr.yaml`** est le fichier de paramètres à passer à Pandoc pour le français ; **`en.yaml`** joue le même rôle pour l'anglais. Chacun fixe l'ordre des 33 textes de sa langue : avant-propos, philosophie de Jedi, introductions et chapitres des trois parties, puis quatre annexes. Aucun texte ancien ou éditorial n'entre dans le manuel.

La génération demande **Pandoc avec les filtres Lua**, **XeLaTeX**, les polices **DejaVu Serif, DejaVu Sans et DejaVu Sans Mono**, et les packages LaTeX usuels du modèle Pandoc, dont `fvextra`, `geometry`, `longtable`, `booktabs`, `array`, `babel` et `fontspec`. Les PDF livrés ont été générés avec Pandoc 3.1.3 et XeLaTeX de TeX Live 2022.

Depuis la racine de l'archive extraite :

~~~bash
bash pdf/build.sh both
bash pdf/build.sh fr
bash pdf/build.sh en
~~~

La première commande génère les deux langues ; les deux autres sont des alternatives pour une seule langue. Le script peut également être appelé par son chemin depuis un autre dossier. Il crée `output/pdf/`, puis utilise les fichiers de paramètres.

Pour utiliser directement Pandoc, se placer à la racine de l'archive et préparer le dossier de sortie :

~~~bash
mkdir -p output/pdf
pandoc --defaults=pdf/fr.yaml
pandoc --defaults=pdf/en.yaml
~~~

Les résultats sont `output/pdf/jedi-1.0-fr.pdf` et `output/pdf/jedi-1.0-en.pdf`.

`book.lua` donne un identifiant unique aux titres de chaque chapitre et transforme les liens entre chapitres en renvois internes au PDF. Les titres H1 des sources Markdown restent sans numéro. Dans le PDF, le filtre ajoute les numéros des chapitres 1 à 24 et des annexes 1 à 4, d'après leurs noms de fichiers. Ces numéros apparaissent aussi dans le sommaire et les signets : les renvois restent donc utilisables après impression. L'avant-propos et les introductions des parties ne reçoivent pas de numéro de chapitre. Le filtre commence chaque texte sur une nouvelle page et fait revenir les lignes de code trop longues à la ligne ; il ne modifie pas les commandes dans les fichiers Markdown.

Les liens vers des fichiers TXT, les lanceurs et le guide des exemples désignent les fichiers livrés séparément dans cette archive. Conserver son arborescence pour les retrouver ; ils ne sont pas intégrés comme pièces jointes dans les PDF. Les adresses Web restent des liens externes.

Pour changer l'ordre de lecture, modifier `input-files` dans le fichier YAML concerné. Pour changer les marges ou les polices, modifier `variables`. Les réglages communs des blocs de code sont dans `header.tex`. Les scripts gardent commentaires et messages en anglais.

Références techniques : [manuel Pandoc](https://pandoc.org/MANUAL.html) et [filtres Lua](https://pandoc.org/lua-filters.html).

## English

**`fr.yaml`** is the Pandoc defaults file for French; **`en.yaml`** is its English counterpart. Each orders 33 current texts: foreword, Jedi's philosophy, part introductions and chapters, followed by four appendices. Former and editorial material is excluded.

Requirements are **Pandoc with Lua filters**, **XeLaTeX**, **DejaVu Serif, DejaVu Sans and DejaVu Sans Mono**, and usual Pandoc-template LaTeX packages including `fvextra`, `geometry`, `longtable`, `booktabs`, `array`, `babel` and `fontspec`. Supplied PDFs were generated with Pandoc 3.1.3 and TeX Live 2022 XeLaTeX.

From the extracted archive root, run `bash pdf/build.sh both`. Use `fr` or `en` instead of `both` for one language. The script also works when called by path from another directory. For direct Pandoc calls, create `output/pdf/`, then use `pandoc --defaults=pdf/fr.yaml` or `pandoc --defaults=pdf/en.yaml` from the archive root.

Outputs are `output/pdf/jedi-1.0-fr.pdf` and `output/pdf/jedi-1.0-en.pdf`. `book.lua` gives chapter headings unique identifiers, resolves chapter links inside the PDF and starts each text on a fresh page. Markdown H1 titles remain unnumbered. For the PDF, the filter adds chapter numbers 1 to 24 and appendix numbers 1 to 4 from their filenames. These numbers also appear in the contents and bookmarks, so chapter references remain usable in print. The foreword and part introductions receive no chapter number. Code wraps rather than being clipped, without changing Markdown commands.

TXT files, launchers and the example guide are supplied separately in the archive, not embedded as PDF attachments. Keep its directory structure to locate them. Web links remain external.

Edit `input-files` to change document order, `variables` for margins or fonts and `header.tex` for shared code formatting. Technical references: [Pandoc manual](https://pandoc.org/MANUAL.html) and [Lua filters](https://pandoc.org/lua-filters.html).
