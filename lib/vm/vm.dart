/// L'interpréteur. Dart pur, zéro dépendance Flutter, testable en
/// `dart test` sans widget tree ni device.
library;

import 'ast.dart';
import 'room.dart';
import 'trace.dart';

class _Agent {
  _Agent(this.x, this.y, this.dir);
  int x;
  int y;
  Dir dir;
}

class _Halt implements Exception {
  _Halt(this.outcome, this.event);
  final Outcome outcome;
  final FrameEvent event;
}

/// Comment un tick choisit ce qu'il exécute.
enum DispatchMode {
  /// Un SEUL bloc par tick : le plus bas dont la garde est vraie.
  /// Les autres sont supplantés.
  lastMatch,

  /// TOUS les blocs dont la garde est vraie s'exécutent, de haut en
  /// bas. La pile se lit alors comme un programme, pas comme une
  /// liste de priorités.
  allMatching,
}

class Vm {
  Vm(this.room, this.program, {this.mode = DispatchMode.lastMatch});

  final Room room;
  final Program program;
  final DispatchMode mode;

  late _Agent _a;
  final List<Frame> _frames = [];
  final Set<int> _collected = {};
  final Set<int> _revealed = {};
  final Set<int> _marks = {};
  int _register = 0;
  int _cycles = 0;
  int _guardCycles = 0;
  int _actionCycles = 0;
  int _bonus = 0;
  Outcome _outcome = Outcome.running;
  int? _activeBlock;
  Set<int> _matched = const {};

  /// Signature complète de l'état observable au moment du dispatch.
  ///
  /// La salle est statique et la VM déterministe : la suite dépend
  /// UNIQUEMENT de cette signature. Deux dispatches avec la même
  /// signature démontrent donc une boucle infinie — ce n'est pas une
  /// heuristique, c'est une preuve.
  String _signature() {
    final marks = _marks.toList()..sort();
    return '${_a.x},${_a.y},${_a.dir.index},${_collected.length},'
        '${Object.hashAll(marks)},$_register';
  }

  final Map<String, int> _seen = {};

  /// On laisse la boucle se jouer deux fois avant de couper : le joueur
  /// doit la VOIR osciller, sinon l'arrêt paraît arbitraire.
  static const int _loopLimit = 3;

  /// Borne dure contre les boucles infinies imbriquées. La limite de
  /// cycles de la salle reste l'échec « officiel » ; celle-ci protège
  /// seulement l'exécuteur.
  static const int _hardStepCap = 200000;

  ExecResult run() {
    _a = _Agent(room.startX, room.startY, room.startDir);
    _reveal();
    _emit(FrameEvent.none, null);

    try {
      var steps = 0;
      while (true) {
        if (++steps > _hardStepCap) {
          throw _Halt(Outcome.cycleLimit, FrameEvent.cycleLimit);
        }
        _dispatch();
      }
    } on _Halt catch (h) {
      _outcome = h.outcome;
      _emit(h.event, null);
    }

    return ExecResult(
      frames: _frames,
      outcome: _outcome,
      cyclesSpent: _cycles,
      guardCycles: _guardCycles,
      actionCycles: _actionCycles,
      bonusCollected: _bonus,
    );
  }

  // ---------------------------------------------------------------
  // Dispatch : TOUTES les gardes sont évaluées à chaque tick, et le
  // dernier match l'emporte. C'est exactement le mécanisme de la dette :
  // chaque bloc gelé coûte sa garde à chaque tick, sur tous les étages
  // restants.
  // ---------------------------------------------------------------
  void _dispatch() {
    int? winner;
    final matched = <int>{};
    for (var i = 0; i < program.blocks.length; i++) {
      _spend(program.blocks[i].guard.cost, guard: true);
      if (_test(program.blocks[i].guard)) {
        matched.add(i);
        winner = i;
      }
    }

    _activeBlock = winner;
    _matched = matched;

    if (winner == null) {
      // Blocage : le tick est perdu. Ça tourne jusqu'à la limite de
      // cycles. La leçon : il faut un bloc `toujours` en fond de pile.
      _emit(FrameEvent.blocked, null);
      return;
    }

    if (mode == DispatchMode.allMatching) {
      for (final i in matched.toList()..sort()) {
        _activeBlock = i;
        _emit(FrameEvent.dispatch, null);
        _exec(program.blocks[i].body);
      }
    } else {
      _emit(FrameEvent.dispatch, null);
      _exec(program.blocks[winner].body);
    }

    // Le programme repasse par un état déjà visité : il tournera ainsi
    // indéfiniment. Inutile de vider la jauge pour l'apprendre — et
    // surtout, « tu tournes en rond » est une leçon, « tu es trop
    // lent » n'en est pas une.
    final sig = _signature();
    final n = (_seen[sig] ?? 0) + 1;
    _seen[sig] = n;
    if (n >= _loopLimit) {
      throw _Halt(Outcome.stalled, FrameEvent.stalled);
    }
  }

  void _exec(List<Stmt> body) {
    for (final s in body) {
      switch (s) {
        case ActionStmt():
          _doAction(s);
        case IfStmt():
          _spend(s.cond.cost, guard: true);
          _exec(_test(s.cond) ? s.then : s.otherwise);
        case WhileStmt():
          var guardTrips = 0;
          while (true) {
            _spend(s.cond.cost, guard: true);
            if (!_test(s.cond)) break;
            if (++guardTrips > _hardStepCap) {
              throw _Halt(Outcome.cycleLimit, FrameEvent.cycleLimit);
            }
            _exec(s.body);
          }
        case RepeatStmt():
          for (var i = 0; i < s.times; i++) {
            _exec(s.body);
          }
      }
    }
  }

  void _doAction(ActionStmt s) {
    _spend(s.kind.cycleCost, guard: false);
    var event = FrameEvent.none;

    switch (s.kind) {
      case ActionKind.forward:
        event = _step(_a.x + _a.dir.dx, _a.y + _a.dir.dy);
      case ActionKind.jump:
        // Franchit une case : atterrit deux cases plus loin.
        event = _step(_a.x + _a.dir.dx * 2, _a.y + _a.dir.dy * 2);
      case ActionKind.turnLeft:
        _a.dir = _a.dir.left;
      case ActionKind.turnRight:
        _a.dir = _a.dir.right;
      case ActionKind.pickUp:
        final here = room.idx(_a.x, _a.y);
        if (room.items.contains(here) && !_collected.contains(here)) {
          _collected.add(here);
          event = FrameEvent.picked;
        }
      case ActionKind.wait:
        break;
      case ActionKind.scan:
        _reveal(radius: 2);
        event = FrameEvent.scanned;
      case ActionKind.mark:
        _marks.add(room.idx(_a.x, _a.y));
        event = FrameEvent.marked;
      case ActionKind.retrace:
        if (_marks.isNotEmpty) {
          final target = _marks.last;
          _marks.remove(target);
          _a.x = target % room.width;
          _a.y = target ~/ room.width;
        }
      case ActionKind.setRegister:
        _register = s.arg;
    }

    _reveal();
    _emit(event, s.id);
  }

  /// Déplacement, avec les modes de défaite physiques. Un danger
  /// interrompt l'exécution : la salle reste à résoudre et la pénalité
  /// tombe. Aussi punitif qu'une mort sèche, mais imputable.
  FrameEvent _step(int nx, int ny) {
    if (!room.inBounds(nx, ny) || room.at(nx, ny) == Tile.wall) {
      return FrameEvent.none; // bute sur le mur, le cycle est consommé
    }

    _a.x = nx;
    _a.y = ny;
    _reveal();

    final tile = room.at(nx, ny);
    if (tile == Tile.spike) {
      _emit(FrameEvent.hazardSpike, null);
      throw _Halt(Outcome.hazard, FrameEvent.hazardSpike);
    }
    if (tile == Tile.pit) {
      _emit(FrameEvent.hazardPit, null);
      throw _Halt(Outcome.hazard, FrameEvent.hazardPit);
    }

    final here = room.idx(nx, ny);
    if (room.bonuses.contains(here) && !_collected.contains(here)) {
      _collected.add(here);
      _bonus++;
      return FrameEvent.bonus;
    }

    if (tile == Tile.exitTile && _allItemsCollected) {
      _emit(FrameEvent.exitReached, null);
      throw _Halt(Outcome.solved, FrameEvent.exitReached);
    }

    return FrameEvent.none;
  }

  bool get _allItemsCollected => room.items.every(_collected.contains);

  // ---------------------------------------------------------------

  /// Une garde est une liste PLATE de termes reliés par un seul
  /// opérateur. Liste vide = vraie, donc `Guard.always()` est le cas
  /// dégénéré et ne demande aucun traitement particulier.
  bool _test(Guard g) {
    if (g.terms.isEmpty) return true;
    if (g.op == GuardOp.all) {
      for (final t in g.terms) {
        if (!_term(t)) return false;
      }
      return true;
    }
    for (final t in g.terms) {
      if (_term(t)) return true;
    }
    return false;
  }

  bool _term(GuardTerm t) {
    final v = _raw(t.kind, t.arg);
    return t.negated ? !v : v;
  }

  bool _raw(GuardKind kind, int arg) {
    final ax = _a.x + _a.dir.dx;
    final ay = _a.y + _a.dir.dy;
    final rx = _a.x + _a.dir.right.dx;
    final ry = _a.y + _a.dir.right.dy;
    final lx = _a.x + _a.dir.left.dx;
    final ly = _a.y + _a.dir.left.dy;

    return switch (kind) {
      GuardKind.always => true,
      GuardKind.wallAhead => room.at(ax, ay) == Tile.wall,
      GuardKind.floorAhead => room.isSafe(ax, ay),
      GuardKind.floorRight => room.isSafe(rx, ry),
      GuardKind.floorLeft => room.isSafe(lx, ly),
      GuardKind.pitAhead => room.at(ax, ay) == Tile.pit,
      GuardKind.spikeAhead => room.at(ax, ay) == Tile.spike,
      GuardKind.hazardAhead => room.isHazard(ax, ay),
      GuardKind.itemHere =>
        room.items.contains(room.idx(_a.x, _a.y)) &&
            !_collected.contains(room.idx(_a.x, _a.y)),
      GuardKind.itemAhead =>
        room.inBounds(ax, ay) &&
            room.items.contains(room.idx(ax, ay)) &&
            !_collected.contains(room.idx(ax, ay)),
      GuardKind.exitAhead => room.at(ax, ay) == Tile.exitTile,
      GuardKind.registerEquals => _register == arg,
    };
  }

  void _spend(int n, {required bool guard}) {
    _cycles += n;
    if (guard) {
      _guardCycles += n;
    } else {
      _actionCycles += n;
    }
    if (_cycles > room.cycleLimit) {
      throw _Halt(Outcome.cycleLimit, FrameEvent.cycleLimit);
    }
  }

  /// Hors brouillard tout est révélé d'emblée. Règle de design : un
  /// piège invisible dans une salle éclairée n'existe pas.
  void _reveal({int radius = 1}) {
    if (!room.fog) return;
    for (var dy = -radius; dy <= radius; dy++) {
      for (var dx = -radius; dx <= radius; dx++) {
        final x = _a.x + dx;
        final y = _a.y + dy;
        if (room.inBounds(x, y)) _revealed.add(room.idx(x, y));
      }
    }
  }

  void _emit(FrameEvent event, int? stmtId) {
    _frames.add(
      Frame(
        x: _a.x,
        y: _a.y,
        dir: _a.dir,
        matched: Set.of(_matched),
        cycles: _cycles,
        guardCycles: _guardCycles,
        actionCycles: _actionCycles,
        activeBlock: _activeBlock,
        activeStmtId: stmtId,
        collected: Set.of(_collected),
        revealed: Set.of(_revealed),
        marks: Set.of(_marks),
        register: _register,
        event: event,
      ),
    );
  }
}
