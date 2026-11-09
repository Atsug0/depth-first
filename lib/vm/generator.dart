/// Génération procédurale, avec deux garanties non négociables.
///
/// 1. SOLVABILITÉ PAR CONSTRUCTION — une salle n'est retenue que si le
///    solveur canonique la résout. Son coût en cycles devient le coût
///    de référence de la salle.
/// 2. GÉNÉRATION CONTEXTUELLE — le générateur connaît la pile actuelle
///    du joueur et rejette toute salle que son programme résout déjà.
///    Une salle n'est retenue que si elle FORCE une addition. C'est ce
///    qui rend impossible la salle « je relance et je passe ».
library;

import 'dart:math';

import 'ast.dart';
import 'room.dart';
import 'vm.dart';

/// Le solveur canonique : un suiveur de mur à droite, écrit dans le
/// langage du jeu avec le seul socle gratuit. Dernier match gagne, donc
/// l'index le plus haut est le plus prioritaire.
Program canonicalSolver() => Program([
  Block(
    guard: Guard.of(GuardKind.always),
    body: [ActionStmt(ActionKind.turnLeft)],
    floorAdded: 0,
    frozen: true,
  ),
  Block(
    guard: Guard.of(GuardKind.floorAhead),
    body: [ActionStmt(ActionKind.forward)],
    floorAdded: 0,
    frozen: true,
  ),
  Block(
    guard: Guard.of(GuardKind.floorRight),
    body: [ActionStmt(ActionKind.turnRight), ActionStmt(ActionKind.forward)],
    floorAdded: 0,
    frozen: true,
  ),
  Block(
    guard: Guard.of(GuardKind.exitAhead),
    body: [ActionStmt(ActionKind.forward)],
    floorAdded: 0,
    frozen: true,
  ),
  Block(
    guard: Guard.of(GuardKind.itemHere),
    body: [ActionStmt(ActionKind.pickUp)],
    floorAdded: 0,
    frozen: true,
  ),
]);

class GenSpec {
  const GenSpec({
    required this.archetype,
    required this.cellsW,
    required this.cellsH,
    this.items = 0,
    this.bonuses = 0,
    this.spikes = 0,
    this.pits = 0,
    this.fog = false,
  });

  final Archetype archetype;
  final int cellsW;
  final int cellsH;
  final int items;
  final int bonuses;
  final int spikes;
  final int pits;
  final bool fog;
}

/// La courbe de la campagne. Chaque étage force quelque chose de neuf —
/// c'est la table « La courbe, salle par salle » du doc de design.
const List<GenSpec> campaign = [
  GenSpec(archetype: Archetype.corridor, cellsW: 6, cellsH: 1),
  GenSpec(archetype: Archetype.turn, cellsW: 5, cellsH: 4),
  GenSpec(archetype: Archetype.maze, cellsW: 5, cellsH: 4, bonuses: 1),
  GenSpec(
    archetype: Archetype.collect,
    cellsW: 6,
    cellsH: 5,
    items: 2,
    bonuses: 1,
  ),
  GenSpec(
    archetype: Archetype.spikes,
    cellsW: 7,
    cellsH: 5,
    spikes: 6,
    bonuses: 1,
  ),
  GenSpec(
    archetype: Archetype.extraction,
    cellsW: 6,
    cellsH: 5,
    spikes: 3,
    pits: 2,
  ),
];

class Generator {
  Generator(this.seed);
  final int seed;

  /// Tente de produire une salle valide pour ce spec ET ce programme.
  /// Renvoie null si aucune candidate n'a passé les filtres.
  Room? generate(GenSpec spec, {Program? playerProgram, int attempts = 60}) {
    for (var i = 0; i < attempts; i++) {
      final rng = Random(seed * 7919 + i);
      final candidate = _layout(spec, rng);
      if (candidate == null) continue;

      // Filtre 1 : solvabilité par construction.
      final canonical = Vm(candidate, canonicalSolver()).run();
      if (!canonical.success) continue;

      final room = candidate.copyWith(
        referenceCost: canonical.cyclesSpent,
        cycleLimit: (canonical.cyclesSpent * 2.5).round() + 40,
      );

      // Filtre 2 : génération contextuelle. Si le programme actuel du
      // joueur résout déjà la salle, elle n'apporte rien : on la jette.
      if (playerProgram != null && playerProgram.blocks.isNotEmpty) {
        final byPlayer = Vm(room, playerProgram).run();
        if (byPlayer.success) continue;
      }

      return room;
    }
    return null;
  }

  // ---------------------------------------------------------------

  Room? _layout(GenSpec spec, Random rng) {
    final w = spec.cellsW * 2 + 1;
    final h = spec.cellsH * 2 + 1;
    final tiles = List<Tile>.filled(w * h, Tile.wall);
    int idx(int x, int y) => y * w + x;

    switch (spec.archetype) {
      case Archetype.corridor:
        for (var x = 1; x < w - 1; x++) {
          tiles[idx(x, 1)] = Tile.floor;
        }
      case Archetype.turn:
        for (var x = 1; x < w - 1; x++) {
          tiles[idx(x, 1)] = Tile.floor;
        }
        for (var y = 1; y < h - 1; y++) {
          tiles[idx(w - 2, y)] = Tile.floor;
        }
      case Archetype.spikes:
      case Archetype.chasm:
      case Archetype.extraction:
        for (var y = 1; y < h - 1; y++) {
          for (var x = 1; x < w - 1; x++) {
            tiles[idx(x, y)] = Tile.floor;
          }
        }
        // Quelques blocs pour que le suiveur de mur ait de quoi
        // s'accrocher, et que l'espace ne soit pas une plaine vide.
        for (var i = 0; i < spec.cellsW ~/ 2; i++) {
          final bx = 2 + rng.nextInt(w - 4);
          final by = 2 + rng.nextInt(h - 4);
          tiles[idx(bx, by)] = Tile.wall;
        }
      case Archetype.maze:
      case Archetype.collect:
        _recursiveBacktracker(tiles, w, h, spec, rng);
    }

    // Départ en haut à gauche, sortie sur la case praticable la plus
    // éloignée : le trajet traverse réellement la salle.
    const sx = 1, sy = 1;
    if (tiles[idx(sx, sy)] != Tile.floor) return null;

    final dist = _bfs(tiles, w, h, idx(sx, sy));
    var best = -1, bestD = -1;
    for (var i = 0; i < tiles.length; i++) {
      if (dist[i] > bestD) {
        bestD = dist[i];
        best = i;
      }
    }
    if (best < 0 || bestD < 3) return null;
    tiles[best] = Tile.exitTile;

    final path = _pathTo(tiles, w, h, idx(sx, sy), best, dist);
    final pathSet = path.toSet();

    // Cases libres hors du chemin canonique : c'est là que vont les
    // dangers et les bonus. Un danger ne doit jamais bloquer la seule
    // route, sinon la salle devient insoluble et le filtre 1 la rejette
    // en boucle.
    final offPath = <int>[];
    for (var i = 0; i < tiles.length; i++) {
      if (tiles[i] == Tile.floor && !pathSet.contains(i) && i != idx(sx, sy)) {
        offPath.add(i);
      }
    }
    offPath.shuffle(rng);

    final items = <int>[];
    final bonuses = <int>[];
    var cursor = 0;

    // Les objets vont SUR le chemin : ils doivent être ramassables par
    // le solveur canonique.
    final onPath = path.where((i) => i != best && i != idx(sx, sy)).toList()
      ..shuffle(rng);
    for (var i = 0; i < spec.items && i < onPath.length; i++) {
      items.add(onPath[i]);
    }

    for (var i = 0; i < spec.spikes && cursor < offPath.length; i++) {
      tiles[offPath[cursor++]] = Tile.spike;
    }
    for (var i = 0; i < spec.pits && cursor < offPath.length; i++) {
      tiles[offPath[cursor++]] = Tile.pit;
    }
    for (var i = 0; i < spec.bonuses && cursor < offPath.length; i++) {
      bonuses.add(offPath[cursor++]);
    }

    return Room(
      width: w,
      height: h,
      tiles: tiles,
      startX: sx,
      startY: sy,
      startDir: Dir.east,
      items: items,
      bonuses: bonuses,
      fog: spec.fog,
      cycleLimit: 4000,
      referenceCost: 0,
      seed: seed,
      archetype: spec.archetype,
    );
  }

  /// Labyrinthe parfait (sans boucle). Propriété qui nous intéresse :
  /// un suiveur de mur à droite résout TOUJOURS un labyrinthe parfait,
  /// donc le filtre de solvabilité passe systématiquement.
  void _recursiveBacktracker(
    List<Tile> tiles,
    int w,
    int h,
    GenSpec spec,
    Random rng,
  ) {
    int idx(int x, int y) => y * w + x;
    final visited = <int>{};
    final stack = <List<int>>[
      [1, 1],
    ];
    tiles[idx(1, 1)] = Tile.floor;
    visited.add(idx(1, 1));

    while (stack.isNotEmpty) {
      final cur = stack.last;
      final cx = cur[0], cy = cur[1];
      final neighbours = <List<int>>[];
      for (final d in const [
        [0, -2],
        [2, 0],
        [0, 2],
        [-2, 0],
      ]) {
        final nx = cx + d[0], ny = cy + d[1];
        if (nx > 0 &&
            ny > 0 &&
            nx < w - 1 &&
            ny < h - 1 &&
            !visited.contains(idx(nx, ny))) {
          neighbours.add([nx, ny, cx + d[0] ~/ 2, cy + d[1] ~/ 2]);
        }
      }
      if (neighbours.isEmpty) {
        stack.removeLast();
        continue;
      }
      final pick = neighbours[rng.nextInt(neighbours.length)];
      tiles[idx(pick[2], pick[3])] = Tile.floor;
      tiles[idx(pick[0], pick[1])] = Tile.floor;
      visited.add(idx(pick[0], pick[1]));
      stack.add([pick[0], pick[1]]);
    }
  }

  List<int> _bfs(List<Tile> tiles, int w, int h, int from) {
    final dist = List<int>.filled(tiles.length, -1);
    final q = <int>[from];
    dist[from] = 0;
    var head = 0;
    while (head < q.length) {
      final cur = q[head++];
      final cx = cur % w, cy = cur ~/ w;
      for (final d in const [
        [0, -1],
        [1, 0],
        [0, 1],
        [-1, 0],
      ]) {
        final nx = cx + d[0], ny = cy + d[1];
        if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
        final n = ny * w + nx;
        if (tiles[n] == Tile.wall || dist[n] >= 0) continue;
        dist[n] = dist[cur] + 1;
        q.add(n);
      }
    }
    return dist;
  }

  List<int> _pathTo(
    List<Tile> tiles,
    int w,
    int h,
    int from,
    int to,
    List<int> dist,
  ) {
    final path = <int>[to];
    var cur = to;
    while (cur != from) {
      final cx = cur % w, cy = cur ~/ w;
      var next = -1;
      for (final d in const [
        [0, -1],
        [1, 0],
        [0, 1],
        [-1, 0],
      ]) {
        final nx = cx + d[0], ny = cy + d[1];
        if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
        final n = ny * w + nx;
        if (dist[n] == dist[cur] - 1) {
          next = n;
          break;
        }
      }
      if (next < 0) break;
      path.add(next);
      cur = next;
    }
    return path.reversed.toList();
  }
}
