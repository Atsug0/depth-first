/// Une salle est une DONNÉE, jamais du code.
///
/// Décision d'architecture du doc de design : tant que la salle est
/// sérialisable, l'éditeur de niveaux, le partage par code, les défis
/// quotidiens et le rejeu déterministe tombent tous du même format.
/// Ne jamais représenter une salle autrement que par ce qui suit.
library;

enum Tile { floor, wall, spike, pit, exitTile }

enum Dir {
  north(0, -1),
  east(1, 0),
  south(0, 1),
  west(-1, 0);

  const Dir(this.dx, this.dy);
  final int dx;
  final int dy;

  Dir get right => Dir.values[(index + 1) % 4];
  Dir get left => Dir.values[(index + 3) % 4];
}

/// Ce qu'une salle exige du joueur. Sert à l'annonce préalable :
/// règle de design — un type de salle exigeant est TOUJOURS annoncé.
enum Archetype { corridor, turn, maze, collect, spikes, chasm, extraction }

class Room {
  const Room({
    required this.width,
    required this.height,
    required this.tiles,
    required this.startX,
    required this.startY,
    required this.startDir,
    required this.items,
    required this.bonuses,
    required this.fog,
    required this.cycleLimit,
    required this.referenceCost,
    required this.seed,
    required this.archetype,
  });

  final int width;
  final int height;

  /// row-major, longueur = width * height
  final List<Tile> tiles;
  final int startX;
  final int startY;
  final Dir startDir;

  /// index de case (y * width + x)
  final List<int> items;

  /// index de case. Visibles avant le détour — décision de design :
  /// le détour doit être un choix informé, risque contre butin.
  final List<int> bonuses;

  final bool fog;
  final int cycleLimit;

  /// Coût en cycles de la solution canonique. Descendre en dessous
  /// rend la différence au joueur.
  final int referenceCost;

  final int seed;
  final Archetype archetype;

  int idx(int x, int y) => y * width + x;
  bool inBounds(int x, int y) => x >= 0 && y >= 0 && x < width && y < height;

  Tile at(int x, int y) => inBounds(x, y) ? tiles[idx(x, y)] : Tile.wall;

  /// Praticable ET sans danger. `floorAhead` s'appuie dessus, donc un
  /// programme naïf évite les pièges par construction.
  bool isSafe(int x, int y) {
    final t = at(x, y);
    return t == Tile.floor || t == Tile.exitTile;
  }

  bool isHazard(int x, int y) {
    final t = at(x, y);
    return t == Tile.spike || t == Tile.pit;
  }

  Map<String, dynamic> toJson() => {
    'w': width,
    'h': height,
    'tiles': tiles.map((t) => t.index).toList(),
    'sx': startX,
    'sy': startY,
    'sd': startDir.index,
    'items': items,
    'bonuses': bonuses,
    'fog': fog,
    'limit': cycleLimit,
    'ref': referenceCost,
    'seed': seed,
    'arch': archetype.index,
  };

  static Room fromJson(Map<String, dynamic> j) => Room(
    width: j['w'] as int,
    height: j['h'] as int,
    tiles: (j['tiles'] as List).map((i) => Tile.values[i as int]).toList(),
    startX: j['sx'] as int,
    startY: j['sy'] as int,
    startDir: Dir.values[j['sd'] as int],
    items: (j['items'] as List).cast<int>(),
    bonuses: (j['bonuses'] as List).cast<int>(),
    fog: j['fog'] as bool,
    cycleLimit: j['limit'] as int,
    referenceCost: j['ref'] as int,
    seed: j['seed'] as int,
    archetype: Archetype.values[j['arch'] as int],
  );

  Room copyWith({int? referenceCost, int? cycleLimit}) => Room(
    width: width,
    height: height,
    tiles: tiles,
    startX: startX,
    startY: startY,
    startDir: startDir,
    items: items,
    bonuses: bonuses,
    fog: fog,
    cycleLimit: cycleLimit ?? this.cycleLimit,
    referenceCost: referenceCost ?? this.referenceCost,
    seed: seed,
    archetype: archetype,
  );
}
