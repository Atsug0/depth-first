# Assets — DEPTH FIRST

| Chantier | État |
| --- | --- |
| Sprites | **30 faits**, jouables en jeu |
| Sound design | 21 crochets posés, **aucun son** |
| Musique | 5 crochets posés, **aucune piste** |
| Typographie | monospace système, à remplacer |

Le jeu tourne sans aucun asset : tout ce qui manque retombe sur un
rendu procédural ou un no-op. Rien de ce qui suit ne demande de
toucher au gameplay.

---

## 1. Sprites — faits

Direction artistique : **Nécropole** (dark fantasy, PICO-8 gothic).

### Comment ça marche

Les sprites ne sont **pas dessinés à la main dans les SVG**. Ils sont
décrits en grilles ASCII dans `tools/gen_sprites.py`, qui émet le SVG.

```sh
python3 tools/gen_sprites.py     # regénère assets/sprites/*.svg
```

Pourquoi : l'alignement entier est garanti, les quatre orientations du
héros sont **dérivées par rotation** donc ne peuvent pas diverger, et
une grille de caractères se relit et se retouche bien plus vite qu'une
liste de `<rect>`.

Pour juger le résultat : bouton **▣** dans l'en-tête du jeu, qui ouvre
une galerie de tous les sprites agrandis sur damier. Le pixel art se
juge à l'échelle d'affichage, pas dans un explorateur de fichiers.

### Contrat de format

Un SVG de sprite ne contient **que** des `<rect>` alignés sur des
entiers, avec un `fill` hexadécimal. Pas de `<path>`, pas de
`<circle>`, pas de gradient, pas de `transform`.

Ce n'est pas une préférence : `PixelSprite` (dans `art.dart`) parse
directement ces rectangles et les redessine à la taille d'affichage.
Le rendu reste donc net à n'importe quelle résolution, sans
rééchantillonnage et **sans dépendance**. Un fichier non conforme est
rejeté au chargement, listé dans la galerie, et le jeu retombe sur le
procédural — jamais d'écran vide, jamais d'échec silencieux.

### Rôles de couleur — à ne pas mélanger

Une couleur = une signification. C'est ce qui rend la grille lisible
d'un coup d'œil sur un écran de 6 pouces.

| Couleur | Rôle | Interdit ailleurs |
| --- | --- | --- |
| `#39FF14` spectre | Héros, repères, exécution | **Oui** — sinon le curseur d'exécution se confond avec le décor |
| `#FF0055` / `#FF5500` | Danger mortel, flamme | — |
| `#FFB000` ambre | Objet requis, serrure | — |
| `#00E5FF` cyan | Case bonus (temps) | — |
| `#D0C8D6` / `#8B7D93` os | Sortie, liseré du héros | — |
| violets | Sol, murs, brouillard | — |

### Inventaire

| Clé | Ce que c'est | Pourquoi il existe |
| --- | --- | --- |
| `floor` | Dalle praticable | Le fond le plus neutre, il tuile partout |
| `floor_rune` | Dalle gravée | Variante à semer 1 fois sur 5, casse la répétition |
| `wall` | Mur de briques | **Plus sombre que le sol** : plein contre chemin |
| `wall_lichen` | Mur moussu | Variante |
| `spike` | Pics vus d'aplomb | Danger : −150 cycles et l'exécution s'arrête |
| `pit` | Abîme | Idem, et l'agent repart de l'entrée. Forme lisse, à l'opposé de la trame du mur |
| `exit` | Escalier descendant | Marches **rectilignes** — surtout pas concentriques, le vide l'est déjà |
| `corrupted` | Dalle fendue | Le donjon a écrit un bloc dans ton programme. Fractures asymétriques : une blessure n'est pas un symbole |
| `door_locked` | Porte scellée | Chemin caché. Ne s'ouvre qu'avec une clé rapportée **et emportée** d'une run précédente |
| `item` | Éclat d'ambre | Objet requis : sans lui la sortie reste fermée |
| `bonus` | Gemme cyan | Case bonus, toujours hors du chemin direct |
| `mark` | Rune spectrale | Repère posé par `MARQUER`, lu par `RETRACER` |
| `fog` | Trame serrée | L'illisibilité **est** le message : tu n'as pas l'information |
| `fog_eyes` | Yeux dans l'ombre | Variante **purement décorative** de `fog`, aucune règle attachée. 1 dalle sur 30, l'effet vient de la rareté |
| `agent_n/e/s/w` | Le héros | Orientation lisible **sans animation**. E/S/O dérivées du nord par rotation |

### Décor animé du menu

Quatre couches, de la plus lente à la plus rapide. Les cadences vivent
côté Flutter, pas dans les assets.

| Clé | Rôle | Cadence suggérée |
| --- | --- | --- |
| `bg_stone` | Mur tuilé 32×32 | Immobile |
| `bg_sigil_1/2/3` | Sceau au-dessus du titre : double anneau, graduations, hexagramme, cœur | ~2,4 s le cycle. La pulsation joue sur **quelles parties s'allument**, pas sur une luminosité globale : le sceau se charge au lieu de clignoter |
| `bg_torch_1/2/3` | Torche murale | ~0,15 s par image, support fixe |
| `bg_wisp_1/2/3/4` | Volute spectrale | ~0,2 s, plus une dérive lente |
| `bg_ember` | Braise | **Une seule image** : l'animation est un déplacement vertical avec zigzag, pas un cycle |

### Reste à produire

- Variantes de dalle (2-3 par type) pour casser davantage la répétition
- Porte **ouverte** (pendant de `door_locked`)
- Animations de mort : empalement, chute
- Sprites de second agent (étage « deux agents, un programme »)
- Icônes d'actions pour la palette (actuellement du texte)

---

## 2. Sound design — à faire

**Où brancher** : `lib/ui/theme/audio.dart` → `Sfx._emit`.
Un seul corps de méthode. Tous les points d'appel sont déjà posés.
Fichiers attendus dans `assets/audio/`.

### Interface

| Fichier | Déclenché par |
| --- | --- |
| `ui_tap` | Sélection d'une garde ou d'une action |
| `ui_back` | Annuler, fermer une imbrication |
| `block_add` | Un bloc rejoint la pile |
| `block_freeze` | Un bloc est gelé — **définitif, un peu froid** |

### Exécution

| Fichier | Déclenché par |
| --- | --- |
| `run_start` | Appui sur LANCER |
| `dispatch` | Changement de bloc actif (discret, très court) |
| `step` / `turn` / `jump` | Déplacements |
| `pick_up` / `bonus` | Ramassage |
| `scan` / `mark` | Actions débloquables |

### Échecs et fins

| Fichier | Déclenché par | Intention |
| --- | --- | --- |
| `hazard_spike` | Pics | **Sec et cher** : 150 cycles viennent de partir |
| `hazard_pit` | Chute | Plus long, descendant |
| `cycle_limit` | Limite atteinte | Épuisement, pas violence |
| `blocked` | Aucune garde ne matche | Bourdonnement d'attente |
| `room_solved` | Sortie atteinte | Court, net |
| `descend` | Descente d'un étage | Grave, engageant |
| `extract` | Extraction réussie | Soulagement |
| `run_dead` | Temps à zéro | Fin |

`step`, `turn` et `dispatch` sont joués **plusieurs fois par seconde**
en replay ×16. Les garder minuscules, ou les couper au-delà d'une
certaine vitesse.

---

## 3. Musique — à faire

**Où brancher** : `lib/ui/theme/audio.dart` → `Music.play`.

| Piste | Contexte | Intention |
| --- | --- | --- |
| `menu_loop` | Menu, loadout | Calme, on prépare |
| `surface_loop` | Étages 1 à 5 | Neutre, on apprend |
| `descent_loop` | Étages 6 à 10 | La tension monte |
| `deep_loop` | Étages 11+ et mode infini | Oppressant |
| `extraction_loop` | Salle d'extraction | Urgence |

Le jeu a de longues phases de réflexion silencieuse : prévoir des
boucles qui tiennent dix minutes sans lasser, et une couche qui
s'ajoute pendant l'exécution.

---

## 4. Typographie — à faire

**Où brancher** : `lib/ui/theme/art.dart` → `Type.family`.

Déposer la police dans `assets/fonts/`, la déclarer dans
`pubspec.yaml`, changer la seule constante.

Contrainte : le programme se lit comme du code. Il faut une monospace
avec une distinction nette entre `1 l I` et `0 O`.

---

## 5. Direction artistique

**Nécropole** est la direction artistique du jeu, et la seule. La
variante Vitrail qui servait à comparer sur appareil a été supprimée.

Toute la DA tient dans un unique `_Scheme` (`lib/ui/theme/art.dart`).
Aucun autre fichier ne connaît de couleur en dur : la changer, c'est
réécrire ces quinze constantes.
