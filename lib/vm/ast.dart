/// Le langage : une pile de blocs gardés, append-only.
///
/// Niveau haut = liste de règles `QUAND <garde> FAIRE <corps>`.
/// Intérieur d'un bloc = vrai code impératif (boucles, conditions).
library;

/// Compteur global d'identifiants de nœuds. Chaque statement porte un id
/// stable : c'est lui que la trace référence pour poser le curseur sur
/// l'instruction en cours d'exécution.
int _nextId = 0;
int newStmtId() => _nextId++;

enum GuardKind {
  always(1),
  wallAhead(1),
  floorAhead(1),
  floorRight(1),
  floorLeft(1),
  pitAhead(1),
  spikeAhead(1),

  /// Teste tous les dangers d'un coup. Plus cher, mais une ligne au lieu
  /// de trois : c'est le raccourci prudent.
  hazardAhead(2),
  itemHere(1),
  itemAhead(1),
  exitAhead(1),
  registerEquals(1);

  const GuardKind(this.cycleCost);
  final int cycleCost;
}

/// Comment les termes d'une garde se combinent.
///
/// DÉLIBÉRÉMENT PLAT, sans parenthèses ni imbrication : une garde est
/// une liste de termes reliés par UN seul opérateur. `A ET (B OU C)`
/// n'est pas représentable — il faut deux blocs, et c'est exactement
/// l'arbitrage que le plafond de blocs doit créer.
///
/// Le vrai motif : une grammaire imbriquée est intappable au pouce, et
/// la précédence implicite est le piège classique des éditeurs
/// visuels. Plat, c'est lisible sans ambiguïté.
enum GuardOp { all, any }

class GuardTerm {
  const GuardTerm(this.kind, {this.arg = 0, this.negated = false});

  final GuardKind kind;
  final int arg;
  final bool negated;

  GuardTerm get inverted => GuardTerm(kind, arg: arg, negated: !negated);

  Map<String, dynamic> toJson() => {'k': kind.index, 'a': arg, 'n': negated};

  static GuardTerm fromJson(Map<String, dynamic> j) => GuardTerm(
    GuardKind.values[j['k'] as int],
    arg: j['a'] as int,
    negated: j['n'] as bool? ?? false,
  );

  @override
  bool operator ==(Object other) =>
      other is GuardTerm &&
      other.kind == kind &&
      other.arg == arg &&
      other.negated == negated;

  @override
  int get hashCode => Object.hash(kind, arg, negated);
}

class Guard {
  const Guard(this.terms, {this.op = GuardOp.all});

  /// Le cas courant : un seul terme, non nié. Non `const` — une liste
  /// construite depuis un paramètre ne peut pas l'être.
  Guard.of(GuardKind kind, {int arg = 0})
    : terms = [GuardTerm(kind, arg: arg)],
      op = GuardOp.all;

  /// Garde vide : vraie en permanence. Équivaut à `toujours`.
  const Guard.always() : terms = const [], op = GuardOp.all;

  final List<GuardTerm> terms;
  final GuardOp op;

  bool get isAlways =>
      terms.isEmpty ||
      (terms.length == 1 &&
          terms.first.kind == GuardKind.always &&
          !terms.first.negated);

  /// Chaque terme se paie à CHAQUE tick, pour chaque bloc de la pile.
  /// Une garde composée est donc plus expressive ET plus chère : c'est
  /// le mécanisme de la dette qui arbitre tout seul.
  int get cost {
    if (terms.isEmpty) return 1;
    var total = 0;
    for (final t in terms) {
      total += t.kind.cycleCost;
    }
    return total;
  }

  Guard plus(GuardTerm t) => Guard([...terms, t], op: op);

  Guard withOp(GuardOp o) => Guard(terms, op: o);

  Guard dropLast() =>
      terms.isEmpty ? this : Guard(terms.sublist(0, terms.length - 1), op: op);

  Map<String, dynamic> toJson() => {
    't': terms.map((t) => t.toJson()).toList(),
    'o': op.index,
  };

  static Guard fromJson(Map<String, dynamic> j) => Guard(
    (j['t'] as List)
        .map((e) => GuardTerm.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    op: GuardOp.values[j['o'] as int? ?? 0],
  );

  @override
  bool operator ==(Object other) =>
      other is Guard &&
      other.op == op &&
      other.terms.length == terms.length &&
      List.generate(
        terms.length,
        (i) => terms[i] == other.terms[i],
      ).every((b) => b);

  @override
  int get hashCode => Object.hash(op, Object.hashAll(terms));
}

enum ActionKind {
  forward(1, unlocked: true),
  turnLeft(1, unlocked: true),
  turnRight(1, unlocked: true),
  pickUp(1, unlocked: true),
  wait(1, unlocked: true),
  scan(3),
  jump(4),
  mark(5),
  retrace(1),
  setRegister(2);

  const ActionKind(this.cycleCost, {this.unlocked = false});

  final int cycleCost;

  /// Socle gratuit. Règle de design : il doit toujours permettre de
  /// résoudre n'importe quelle salle, plus chèrement. Sans ça une salle
  /// générée peut tuer un joueur qui n'a pas débloqué la bonne action,
  /// et la mort cesse d'être imputable.
  final bool unlocked;
}

sealed class Stmt {
  Stmt() : id = newStmtId();
  final int id;
  Map<String, dynamic> toJson();
}

class ActionStmt extends Stmt {
  ActionStmt(this.kind, {this.arg = 0});
  final ActionKind kind;
  final int arg;

  @override
  Map<String, dynamic> toJson() => {'t': 'a', 'k': kind.index, 'v': arg};
}

class IfStmt extends Stmt {
  IfStmt(this.cond, this.then, [this.otherwise = const []]);
  final Guard cond;
  final List<Stmt> then;
  final List<Stmt> otherwise;

  @override
  Map<String, dynamic> toJson() => {
    't': 'i',
    'c': cond.toJson(),
    'y': then.map((s) => s.toJson()).toList(),
    'n': otherwise.map((s) => s.toJson()).toList(),
  };
}

class WhileStmt extends Stmt {
  WhileStmt(this.cond, this.body);
  final Guard cond;
  final List<Stmt> body;

  @override
  Map<String, dynamic> toJson() => {
    't': 'w',
    'c': cond.toJson(),
    'b': body.map((s) => s.toJson()).toList(),
  };
}

class RepeatStmt extends Stmt {
  RepeatStmt(this.times, this.body);
  final int times;
  final List<Stmt> body;

  @override
  Map<String, dynamic> toJson() => {
    't': 'r',
    'n': times,
    'b': body.map((s) => s.toJson()).toList(),
  };
}

Stmt stmtFromJson(Map<String, dynamic> j) => switch (j['t'] as String) {
  'a' => ActionStmt(ActionKind.values[j['k'] as int], arg: j['v'] as int),
  'i' => IfStmt(
    Guard.fromJson((j['c'] as Map).cast<String, dynamic>()),
    (j['y'] as List)
        .map((e) => stmtFromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    (j['n'] as List)
        .map((e) => stmtFromJson((e as Map).cast<String, dynamic>()))
        .toList(),
  ),
  'w' => WhileStmt(
    Guard.fromJson((j['c'] as Map).cast<String, dynamic>()),
    (j['b'] as List)
        .map((e) => stmtFromJson((e as Map).cast<String, dynamic>()))
        .toList(),
  ),
  'r' => RepeatStmt(
    j['n'] as int,
    (j['b'] as List)
        .map((e) => stmtFromJson((e as Map).cast<String, dynamic>()))
        .toList(),
  ),
  _ => throw ArgumentError('statement inconnu: ${j['t']}'),
};

/// Un bloc. Une fois gelé, il ne peut plus être modifié — c'est le
/// pilier append-only. Il continue pourtant de s'évaluer à chaque tick,
/// ce qui en fait un passif : dette technique à intérêts composés.
class Block {
  Block({
    required this.guard,
    required this.body,
    required this.floorAdded,
    this.frozen = false,
    this.inherited = false,
    this.corrupted = false,
  });

  Guard guard;
  List<Stmt> body;
  final int floorAdded;
  bool frozen;

  /// Vient du carnet de patterns : un bloc hérité d'une run précédente,
  /// gelé et placé au fond de la pile.
  final bool inherited;

  /// Écrit par le donjon, pas par le joueur. Impossible à retirer.
  final bool corrupted;

  Map<String, dynamic> toJson() => {
    'g': guard.toJson(),
    'b': body.map((s) => s.toJson()).toList(),
    'f': floorAdded,
    'z': frozen,
    'i': inherited,
    'c': corrupted,
  };

  static Block fromJson(Map<String, dynamic> j) => Block(
    guard: Guard.fromJson((j['g'] as Map).cast<String, dynamic>()),
    body: (j['b'] as List)
        .map((e) => stmtFromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    floorAdded: j['f'] as int,
    frozen: j['z'] as bool,
    inherited: j['i'] as bool? ?? false,
    corrupted: j['c'] as bool? ?? false,
  );
}

/// La pile. L'ordre est la priorité : DERNIER MATCH GAGNE, donc l'index
/// le plus haut l'emporte. Choix critique du design — avec « premier
/// match gagne », une règle écrite à l'étage 1 dominerait pour toujours
/// et la run deviendrait ingagnable par accumulation.
class Program {
  Program(this.blocks);
  final List<Block> blocks;

  /// Plafond dur. Ce n'est pas une contrainte d'affichage : c'est ce qui
  /// empêche le bidouillage par accumulation, borne la taxe de gardes à
  /// 10 cycles par tick, et rend la pile lisible sur téléphone.
  static const int maxBlocks = 10;
  static const int startingSlots = 4;

  int get guardTaxPerTick => blocks.fold(0, (sum, b) => sum + b.guard.cost);

  Program clone() => Program(
    blocks
        .map((b) => Block.fromJson((b.toJson() as Map).cast<String, dynamic>()))
        .toList(),
  );
}
