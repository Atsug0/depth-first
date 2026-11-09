# DEPTH FIRST

*Parcours en profondeur d'abord : l'algorithme, et la descente.*

Un jeu de programmation rogue-lite. Tu descends dans un donjon en
écrivant un programme que tu n'as **jamais le droit de réécrire**, et
il faut garder assez de ressources pour remonter.

## La boucle

1. Tu entres dans une salle, tu vois le problème, tu **ajoutes** un bloc
   à ton programme. Les blocs précédents sont gelés.
2. Tu lances l'exécution et tu regardes. Les cycles consommés sont
   déduits de ton temps restant.
3. Aux paliers : descendre plus profond, ou extraire pour garder ce que
   tu as gagné.

## Les trois piliers

Rien ne doit être ajouté au jeu qui n'en serve un.

1. **Append-only** — les blocs écrits sont gelés et continuent de
   s'évaluer à chaque tick. Dette technique à intérêts composés.
2. **Le temps est la monnaie unique** — jamais de points de vie. Une
   seule jauge garantit que chaque mort est imputable à une décision.
3. **Extraction à risque** — le retour est un coût intellectuel à
   prépayer. Équipé = en jeu, au stash = en sécurité.

## Lancer

```sh
flutter run -d macos     # desktop
flutter run -d chrome    # web
flutter run              # simulateur iOS / Android
flutter test             # 16 tests, dont la VM en Dart pur
```

## Architecture

```
lib/
  vm/          Dart pur, zéro dépendance Flutter, entièrement testable
    room.dart        la salle, DONNÉE sérialisable — jamais du code
    ast.dart         le langage : gardes, actions, blocs, pile
    vm.dart          l'interpréteur → produit une trace
    trace.dart       Frame, ExecResult, modes de défaite
    generator.dart   génération contextuelle + solveur canonique
  game/
    run.dart         l'économie du temps
  i18n/
    strings.dart     FR / EN, bascule à chaud, zéro dépendance
  ui/
    theme/art.dart   TOUTE la direction artistique, 2 variantes
    theme/audio.dart crochets de son, no-op pour l'instant
    widgets/         monde, pile de blocs, palette, HUD
    screens/         l'écran de jeu, responsive desktop / mobile
```

### Exécution vers trace

Le programme est déterministe et fini : on l'exécute **entièrement en
amont**, puis on anime la liste de frames. La simulation ne tourne
jamais dans la boucle de rendu. Conséquences gratuites : pause, rewind,
pas-à-pas, vitesse variable et scrubbing ne sont qu'un index dans une
liste — et le replay de fin de run ne coûte rien.

### Deux garanties du générateur

1. **Solvabilité par construction** — une salle n'est retenue que si le
   solveur canonique (un suiveur de mur écrit dans le langage du jeu)
   la résout. Son coût en cycles devient le coût de référence.
2. **Génération contextuelle** — le générateur connaît la pile du
   joueur et rejette toute salle que son programme résout déjà. Une
   salle n'est retenue que si elle **force une addition**.

## Remplacer la DA, les sprites, les sons

Voir [ASSETS_TODO.md](ASSETS_TODO.md). Résumé :

| Quoi | Où |
| --- | --- |
| Couleurs et direction artistique | `lib/ui/theme/art.dart` → `_Scheme` |
| Typographie | `lib/ui/theme/art.dart` → `Type.family` |
| Dessin des sprites | `tools/gen_sprites.py`, puis relancer le script |
| Chargement des sprites | `lib/ui/theme/art.dart` → `SpriteSheet` |
| Sons et musique | `lib/ui/theme/audio.dart` |
| Traductions | `lib/i18n/strings.dart` |

### Les sprites

30 sprites pixel art, direction **Nécropole**. Ils sont décrits en
grilles ASCII dans `tools/gen_sprites.py` et compilés en SVG :

```sh
python3 tools/gen_sprites.py
```

Les SVG ne contiennent que des `<rect>` alignés sur des entiers, ce qui
permet à `PixelSprite` de les redessiner à la taille d'affichage — net
à toute résolution, sans rééchantillonnage et sans dépendance.

Le bouton **▣** de l'en-tête ouvre une galerie de tous les sprites
agrandis : c'est là qu'on juge le pixel art, pas dans le Finder.

Le prototype expose dans l'en-tête un retour au menu **←** et la
galerie de sprites **▣**, outil de développement à retirer avant une
release. La bascule **FR/EN** vit dans le menu.

## État du prototype

Implémenté : la VM et son langage, la génération contextuelle, 6 étages,
l'économie du temps, les modes de défaite physiques, la limite de blocs,
la timeline scrubbable, l'extraction, le responsive desktop/mobile,
FR/EN.

Pas encore : loadout avant descente, méta-progression, stash, chemins
cachés à clé, carnet de patterns, corruption, mode infini, défi
quotidien, bac à sable, achievements. Le doc de design les couvre.
