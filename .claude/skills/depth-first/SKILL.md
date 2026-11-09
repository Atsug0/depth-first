---
name: depth-first
description: Développer le jeu DEPTH FIRST (rogue-lite de programmation en Flutter). À utiliser pour toute tâche sur ce projet — ajouter une garde, une action, un archétype de salle, un système de méta-progression, brancher des sprites ou du son, traduire, ou modifier l'économie. Contient les invariants de design qu'aucun changement ne doit casser.
---

# DEPTH FIRST — skill de développement

Jeu de programmation rogue-lite en Flutter. Le joueur descend dans un
donjon en écrivant un programme qu'il n'a jamais le droit de réécrire,
et doit garder assez de ressources pour remonter.

Le document de design complet vit hors du repo :
`~/Desktop/jeu-algo-roguelite-design.md`. Le consulter en cas de doute
sur une intention de design.

## Les trois piliers — ne jamais les contredire

Avant d'ajouter quoi que ce soit, vérifier que ça sert l'un des trois.
Si ça n'en sert aucun, **ne pas l'ajouter**.

1. **Append-only.** Les blocs écrits sont gelés et continuent de
   s'évaluer à chaque tick. L'ancien code est un passif : il se
   déclenche dans les cas non couverts, et il coûte des cycles sur tous
   les étages restants. Ne jamais permettre d'éditer un bloc gelé
   autrement que par l'action `PATCH`.

2. **Le temps est la monnaie unique.** Jamais de points de vie, jamais
   de seconde ressource. Une seule jauge garantit que chaque mort est
   imputable à une décision. Un danger physique se paie en cycles
   (pénalité de 150), pas en PV.

3. **Extraction à risque.** Le retour est un coût intellectuel à
   prépayer. Équipé = en jeu, au stash = en sécurité. On perd des
   objets, jamais des acquis.

Socle transverse : **on randomise le problème, jamais les outils.**
Aucun tirage aléatoire ne doit affecter la capacité du joueur.

## Invariants techniques

| Invariant | Pourquoi | Où |
| --- | --- | --- |
| Une salle est une **donnée sérialisable**, jamais du code | Sans ça, l'éditeur de niveaux et le partage par code sont infaisables | `lib/vm/room.dart` |
| Le `lib/vm/` ne dépend **jamais** de Flutter | Testable en `dart test`, réutilisable par le solveur | `lib/vm/` |
| L'exécution produit une **trace complète** avant tout rendu | Rewind, scrubbing, replay et perf en découlent gratuitement | `lib/vm/vm.dart` |
| **Dernier match gagne** au dispatch | Premier-match-gagne rend les runs ingagnables par accumulation | `Vm._dispatch` |
| **Toutes** les gardes sont évaluées à chaque tick | C'est le mécanisme de la dette à intérêts composés | `Vm._dispatch` |
| Plafond dur de **10 blocs** | Empêche le bidouillage par accumulation, borne la taxe, rend la pile lisible sur mobile | `Program.maxBlocks` |
| Le monde et le bloc en cours sont **toujours visibles** | Le lien instruction ↔ effet est la seule chose à ne jamais perdre | `lib/ui/screens/game_screen.dart` |
| Une salle générée doit **forcer une addition** au programme | Sinon le joueur relance et passe sans rien apprendre | `Generator.generate` |
| Un programme qui ne change plus rien **s'arrête et le dit** | Une impasse logique n'est pas une lenteur ; la sanctionner comme telle n'apprend rien | `Vm._dispatch`, `Outcome.stalled` |
| Les gardes qui ont matché **sans l'emporter** sont affichées | Sans ça la règle du dernier match gagne est invisible, et le joueur croit que son bloc n'a pas tourné | `Frame.matched` |

## Carte du code

```
lib/vm/          Dart pur. Le cœur. Tout changement ici demande un test.
  room.dart        Tile, Dir, Archetype, Room (sérialisable)
  ast.dart         Guard, ActionKind, Stmt, Block, Program
  vm.dart          l'interpréteur ; dispatch + exécution + dangers
  trace.dart       Frame, FrameEvent, Outcome, ExecResult
  generator.dart   solveur canonique + génération contextuelle
lib/game/run.dart  économie du temps, phases, étages
lib/i18n/          FR/EN, ValueNotifier, zéro dépendance
lib/ui/theme/      art.dart (toute la DA) + audio.dart (crochets son)
lib/ui/widgets/    world_view, block_stack, palette, chrome, code_render
lib/ui/screens/    game_screen (responsive desktop / mobile)
```

## Recettes

### Ajouter une garde

1. `GuardKind` dans `ast.dart` — avec son coût en cycles
2. le cas correspondant dans `Vm._raw` (le test brut d'UN terme)
3. la clé `guard.<nom>` dans **les deux** maps de `i18n/strings.dart`
4. l'ajouter à `_guardMenu` dans `palette.dart` si elle doit être
   proposée au joueur
5. un test dans `test/vm_test.dart`

Une `Guard` est une **liste plate de termes** reliés par UN opérateur
(`ET` ou `OU`), chaque terme pouvant être nié. Pas de parenthèses, pas
d'imbrication : `A ET (B OU C)` n'est pas représentable, il faut deux
blocs — et c'est l'arbitrage que le plafond de blocs doit créer. Une
grammaire imbriquée serait intappable au pouce et sa précédence
implicite est le piège classique des éditeurs visuels.

Le coût d'une garde est la **somme** de ses termes, payée à chaque
tick par chaque bloc de la pile. Une garde plus expressive est donc
mécaniquement plus chère : la dette arbitre toute seule, sans qu'on
ait à brider l'expressivité.

### Ajouter une action

1. `ActionKind` dans `ast.dart` — coût, et `unlocked: true` seulement
   si elle fait partie du socle gratuit
2. le cas dans `Vm._doAction`
3. la clé `act.<nom>` dans les deux maps
4. `_actionMenu` dans `palette.dart`
5. un `SfxEvent` dans `audio.dart` si l'action mérite un son
6. une ligne dans `ASSETS_TODO.md`

**Règle** : le socle gratuit doit toujours suffire à résoudre n'importe
quelle salle, plus chèrement. Sinon une salle générée peut tuer un
joueur qui n'a pas débloqué la bonne action, et la mort cesse d'être
imputable.

### Diagnostiquer « mon bloc ne se déclenche pas »

**La cause n°1, de loin : un bloc laissé sans garde.** Une garde vide
est « toujours », et comme le dernier match gagne, ce bloc remporte
CHAQUE tick et neutralise toute la pile au-dessus. La carte du bloc
affiche un avertissement rouge dans ce cas ; le panneau de résultat le
nomme aussi quand un seul bloc a gagné tous les ticks.

Ensuite, dans l'ordre :

1. Scruber la timeline et regarder la pile : le bloc actif est en accent,
   ceux marqués **supplanté** avaient une garde vraie mais ont perdu.
2. Vérifier que la garde n'est pas vraie *trop souvent*. Le piège
   classique : `sol libre à droite` reste vrai juste après un virage,
   parce que le couloir d'où l'on vient est maintenant à droite — le
   bloc tourne deux fois et s'annule. La bonne garde est souvent
   `mur devant`, qui ne décrit pas une opportunité mais un blocage.
3. Un échec `stalled` signifie qu'un bloc gagne bien le dispatch mais
   que plus rien ne bouge. Ce n'est jamais « le bloc n'a pas tourné » :
   c'est « aucune règle ne sort de cet état ».

### Ajouter un archétype de salle

1. `Archetype` dans `room.dart`
2. un cas dans `Generator._layout`
3. une entrée dans `campaign` si l'étage entre dans la campagne
4. la clé `arch.<nom>` dans les deux maps
5. **vérifier que le solveur canonique le résout** — sinon le filtre de
   solvabilité bouclera et `generate` renverra null

Les dangers ne vont **jamais** sur le chemin canonique : `_layout` les
place sur `offPath`. Ne pas contourner ça.

### Toucher aux sprites

Ne **jamais** éditer un fichier de `assets/sprites/` : ils sont générés.

1. modifier la grille ASCII dans `tools/gen_sprites.py`
2. `python3 tools/gen_sprites.py`
3. si c'est un nouveau sprite, ajouter sa clé à `SpriteSheet.keys`
4. **regarder le résultat** : bouton ▣ de l'en-tête, qui ouvre la
   galerie. Le pixel art se juge agrandi, jamais dans un explorateur
   de fichiers ni dans le XML.

Contrat de format : uniquement des `<rect>` entiers avec un `fill` hex.
`PixelSprite` rejette tout le reste et retombe sur le procédural, en
listant l'échec dans la galerie.

Deux pièges de lisibilité déjà payés :
- **Deux sprites ne doivent pas partager la même grammaire de forme.**
  `exit` et `pit` avaient tous deux des anneaux concentriques : on ne
  les distinguait plus. `exit` est passé en marches rectilignes.
- **Une silhouette symétrique ne dit pas sa direction.** Le héros avait
  un cerne vert uniforme, donc aucune orientation lisible. Le spectre
  est maintenant concentré sur le seul avant.

### Brancher le son

`Sfx._emit` dans `audio.dart` — un seul corps de méthode, tous les
points d'appel sont déjà posés. Ne jamais disperser de chemins
d'assets ailleurs.

### Ajouter une langue

`lib/i18n/strings.dart` : une valeur dans `AppLocale`, une entrée dans
`localeLabel`, une map dupliquée et traduite. Les clés manquantes
retombent sur le français.

**Piège connu** : ne jamais mettre `const` sur un widget qui lit `Tr`
et qui est sur le chemin du `ValueListenableBuilder` de la locale. Un
widget const est canonicalisé et Flutter court-circuite son rebuild —
la langue ne changerait pas. Voir le commentaire dans `main.dart`.

## Discipline de test

`lib/vm/` est du Dart pur : **toute modification de la VM, du langage
ou du générateur s'accompagne d'un test**. C'est peu cher et ça protège
le seul endroit du projet où une régression est invisible à l'œil.

```sh
flutter test              # tout
flutter analyze           # doit rester à zéro issue
flutter run -d macos
flutter run -d <simulateur iOS>
```

Les tests widget forcent une taille d'écran : vérifier **les deux**
layouts (desktop ≥ 900 px de large, mobile en dessous) quand on touche
à l'UI.

## Ce qui n'est pas encore implémenté

Loadout avant descente, méta-progression, stash, chemins cachés à clé,
carnet de patterns, corruption, mode infini, défi quotidien, bac à
sable, achievements, tutoriel scripté. Le doc de design les spécifie
tous — s'y référer plutôt que d'improviser.
