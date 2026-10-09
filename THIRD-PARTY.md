# Third-party components / Composants tiers

Jedi's own code, manuals, scripts and fictional examples use the [MIT license](LICENSE). The notices below preserve the licenses of dependencies; they do not replace them with Jedi's license.

Le code, les manuels, les scripts et les exemples fictifs de Jedi utilisent la [licence MIT](LICENSE). Les mentions suivantes conservent les licences des dépendances ; elles ne les remplacent pas par celle de Jedi.

## Crystal dependencies / Dépendances Crystal

Versions are from the supplied `shard.lock`. Exact upstream revisions and file fingerprints are recorded in [release/dependencies.json](release/dependencies.json). License files were copied from those revisions.

Les versions viennent de `shard.lock`. Les révisions et empreintes des fichiers sont dans [release/dependencies.json](release/dependencies.json). Les licences ont été copiées depuis ces révisions.

| Component | Version | Use | License notice |
|---|---|---|---|
| sqlite3 | 0.23.0 | SQLite adapter / Adaptateur SQLite | [MIT](licenses/shards/sqlite3/LICENSE) |
| db | 0.14.0 | Database interface / Interface de base | [MIT](licenses/shards/db/LICENSE) |
| cryplot | 0.2.1 | gnuplot interface / Interface gnuplot | [MIT](licenses/shards/cryplot/LICENSE) |
| tablo | 1.1.0 | Terminal tables / Tableaux du terminal | [MIT](licenses/shards/tablo/LICENSE) |
| i18n | 0.2.2 | English/French interface / Interface anglais-français | [MIT](licenses/shards/i18n/LICENSE) |
| textseg | 0.1.3 | Unicode segmentation / Segmentation Unicode | [MIT](licenses/shards/textseg/LICENSE) |
| uniwidth | 0.1.3 | Unicode character widths / Largeur des caractères | [MIT](licenses/shards/uniwidth/LICENSE) |
| ameba | 1.7.0 | Development only / Développement uniquement | [MIT](licenses/shards/ameba/LICENSE) |
| debug | 2.0.4 | Development only / Développement uniquement | [MIT](licenses/shards/debug/LICENSE) |

The generated Unicode tables include Unicode data; its [copyright and permission notice](licenses/unicode/LICENSE.txt) is included. Upstream source: [Unicode license](https://www.unicode.org/license.txt). Palette attributions from cryplot's pinned submodule are preserved in [licenses/palettes/ATTRIBUTION.txt](licenses/palettes/ATTRIBUTION.txt), together with the [ColorBrewer license](licenses/palettes/COLORBREWER.txt) and [CC0 legal code](licenses/palettes/CC0-1.0.txt). This product includes color specifications and designs developed by Cynthia Brewer (https://colorbrewer2.org/). The Apache 2.0 text for Google's Turbo palette is also included as [licenses/crystal/LICENSE](licenses/crystal/LICENSE); its Google copyright notice is retained in the palette attributions.

Les tables générées contiennent des données Unicode ; leur [mention de copyright et de permission](licenses/unicode/LICENSE.txt) est fournie. Les attributions des palettes du sous-module fixé par cryplot sont conservées dans [licenses/palettes/ATTRIBUTION.txt](licenses/palettes/ATTRIBUTION.txt).

## Native libraries / Bibliothèques natives

The static build contains Crystal standard-library code and native libraries. Crystal 1.21.1's [Apache 2.0 license](licenses/crystal/LICENSE) is included. The build procedure collects upstream notices for the actual Alpine versions of musl, Boehm GC, PCRE2, libyaml, OpenSSL, zlib and libevent when present, and records SQLite's public-domain status. The resulting binary archive adds `licenses/native/manifest.json` and those notices. These native versions cannot be reported from the Jedi source archive alone; they are recorded after the actual build.

Le binaire statique contient du code de la bibliothèque standard Crystal et des bibliothèques natives. La [licence Apache 2.0 de Crystal 1.21.1](licenses/crystal/LICENSE) est fournie. La procédure récupère les mentions des versions Alpine réellement employées pour musl, Boehm GC, PCRE2, libyaml, OpenSSL, zlib et libevent lorsqu’il est présent, puis consigne le statut de domaine public de SQLite. L’archive binaire ajoute `licenses/native/manifest.json` et ces mentions. Ces versions natives ne peuvent pas être déduites de la seule archive source ; elles sont consignées après la construction.

gnuplot is an external program installed by the user's distribution and is not bundled in Jedi archives. Price-provider services are external: their data access and redistribution terms apply to data obtained from them. The included quotations are fictional project examples.

gnuplot est un programme externe installé par la distribution de l’utilisateur ; il n’est pas inclus dans les archives Jedi. Les fournisseurs de cours sont des services externes : leurs conditions s’appliquent aux données obtenues auprès d’eux. Les cotations livrées sont les exemples fictifs du projet.
