/// L'économie d'une run. UNE SEULE MONNAIE : le temps, compté en cycles.
///
/// L'intérêt d'une monnaie unique est l'imputabilité : quand la jauge
/// tombe, le joueur sait exactement quelles décisions l'ont vidée.
/// Ne jamais introduire de points de vie ni de seconde ressource.
library;

import '../vm/ast.dart';
import '../vm/generator.dart';
import '../vm/room.dart';
import '../vm/trace.dart';
import '../vm/vm.dart';

class Economy {
  /// Budget de départ, augmentable par la méta-progression.
  static const int startingBudget = 2000;

  /// Fixe : rend la profondeur coûteuse en soi.
  static const int descentCost = 50;

  /// Il faut partir avant d'être à sec.
  static const int extractionCost = 200;

  /// Descendre sous la référence de la salle rend la différence,
  /// plafonnée. L'excellence est récompensée — c'est l'inverse d'un
  /// seuil pass/fail, qui tomberait injustement sur des salles générées.
  static const int maxReferenceRefund = 80;

  /// Toujours hors du chemin direct, et visibles avant le détour.
  static const int bonusTileValue = 100;
}

enum RunPhase { editing, playing, betweenFloors, extracted, dead }

class FloorResult {
  const FloorResult({
    required this.floor,
    required this.exec,
    required this.refund,
    required this.bonus,
  });

  final int floor;
  final ExecResult exec;
  final int refund;
  final int bonus;

  int get netCost => exec.totalCost - refund - bonus;
}

class RunState {
  RunState({required this.seed}) {
    program = Program([]);
    _loadFloor(1);
  }

  final int seed;

  late Program program;
  int budget = Economy.startingBudget;
  int floor = 1;
  int slots = Program.startingSlots;
  RunPhase phase = RunPhase.editing;

  Room? room;
  ExecResult? lastExec;

  /// Le loadout : ce que le joueur a choisi d'emporter. Le socle gratuit
  /// est toujours présent — il doit toujours permettre de résoudre
  /// n'importe quelle salle, plus chèrement.
  final Set<ActionKind> loadout = {
    ...ActionKind.values.where((a) => a.unlocked),
    ActionKind.scan,
    ActionKind.jump,
    ActionKind.mark,
    ActionKind.retrace,
  };

  bool isUnlocked(ActionKind a) => loadout.contains(a);

  /// Les traces de tous les étages : c'est ce qui rend le replay de fin
  /// de run quasi gratuit.
  final List<FloorResult> history = [];

  /// L'étage où se trouve le point d'extraction.
  static const int extractionFloor = 6;
  static int get lastFloor => campaign.length;

  bool get atExtraction => floor >= extractionFloor;
  bool get canAddBlock => program.blocks.length < slots;
  int get blocksUsed => program.blocks.length;

  String? loadError;

  void _loadFloor(int f) {
    floor = f;
    final spec = campaign[(f - 1).clamp(0, campaign.length - 1)];
    // Génération contextuelle : la salle doit forcer une addition.
    var next = Generator(seed * 31 + f).generate(spec, playerProgram: program);
    // Repli : aux premiers étages le programme est vide, et plus tard une
    // pile très générale peut assécher les candidats. On relâche alors le
    // filtre contextuel plutôt que de bloquer la run.
    next ??= Generator(seed * 31 + f + 977).generate(spec);
    room = next;
    loadError = next == null ? 'generation_failed' : null;
    lastExec = null;
    phase = RunPhase.editing;
  }

  /// Ajoute un bloc en BAS de la pile. Append-only : tout ce qui est
  /// au-dessus est gelé et ne pourra plus être touché.
  bool appendBlock(Block b) {
    if (!canAddBlock) return false;
    for (final old in program.blocks) {
      old.frozen = true;
    }
    program.blocks.add(b);
    return true;
  }

  /// Le bloc du bas tant qu'il n'a pas été validé par un RUN. Décision
  /// de design : l'édition reste libre tant que RUN n'est pas pressé.
  Block? get draftBlock {
    if (program.blocks.isEmpty) return null;
    final last = program.blocks.last;
    return last.frozen ? null : last;
  }

  void removeDraft() {
    final d = draftBlock;
    if (d != null) program.blocks.remove(d);
  }

  ExecResult execute() {
    final r = room;
    if (r == null) throw StateError('aucune salle chargée');
    final exec = Vm(r, program).run();
    lastExec = exec;
    phase = RunPhase.playing;
    return exec;
  }

  /// Applique le résultat au budget. Appelé une fois le replay terminé,
  /// pour que le joueur VOIE la jauge bouger après avoir vu pourquoi.
  FloorResult commit(ExecResult exec) {
    final r = room!;
    final refund = exec.success
        ? (r.referenceCost - exec.cyclesSpent).clamp(
            0,
            Economy.maxReferenceRefund,
          )
        : 0;
    final bonus = exec.bonusCollected * Economy.bonusTileValue;

    budget -= exec.totalCost;
    budget += refund + bonus;

    final result = FloorResult(
      floor: floor,
      exec: exec,
      refund: refund,
      bonus: bonus,
    );
    history.add(result);

    if (budget <= 0) {
      budget = 0;
      phase = RunPhase.dead;
    } else if (exec.success) {
      phase = RunPhase.betweenFloors;
    } else {
      phase = RunPhase.editing;
    }
    return result;
  }

  /// Un étage de plus, ou je rentre ? La seule décision qui compte.
  void descend() {
    budget -= Economy.descentCost;
    if (budget <= 0) {
      budget = 0;
      phase = RunPhase.dead;
      return;
    }
    _loadFloor(floor + 1);
  }

  void extract() {
    budget -= Economy.extractionCost;
    if (budget <= 0) {
      budget = 0;
      phase = RunPhase.dead;
      return;
    }
    phase = RunPhase.extracted;
  }
}
