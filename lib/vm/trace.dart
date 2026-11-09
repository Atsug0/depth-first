/// Exécution vers trace, puis rendu.
///
/// Le programme est déterministe et fini : on l'exécute ENTIÈREMENT en
/// amont, puis on anime la liste de frames. Conséquences gratuites :
/// la simulation ne tourne jamais dans la boucle de rendu, et le
/// scrubbing / rewind / pas-à-pas ne sont qu'un index dans une liste.
library;

import 'room.dart';

enum FrameEvent {
  none,
  dispatch,
  blocked,
  stalled,
  hazardSpike,
  hazardPit,
  exitReached,
  cycleLimit,
  picked,
  bonus,
  marked,
  scanned,
}

class Frame {
  const Frame({
    required this.x,
    required this.y,
    required this.dir,
    required this.cycles,
    required this.guardCycles,
    required this.actionCycles,
    required this.activeBlock,
    required this.matched,
    required this.activeStmtId,
    required this.collected,
    required this.revealed,
    required this.marks,
    required this.register,
    required this.event,
  });

  final int x;
  final int y;
  final Dir dir;

  /// cumulés
  final int cycles;
  final int guardCycles;
  final int actionCycles;

  /// index du bloc élu par le dispatch, null si aucun
  final int? activeBlock;

  /// TOUS les blocs dont la garde était vraie ce tick. Ceux qui ne sont
  /// pas `activeBlock` ont matché mais ont été supplantés — c'est la
  /// règle « dernier match gagne », et il faut que le joueur la VOIE,
  /// sinon il croit que son nouveau bloc n'a jamais été évalué.
  final Set<int> matched;

  /// id du statement en cours — c'est le curseur côté programme, et
  /// c'est lui qui relie les deux moitiés de l'écran
  final int? activeStmtId;

  final Set<int> collected;
  final Set<int> revealed;
  final Set<int> marks;
  final int register;
  final FrameEvent event;
}

enum Outcome {
  running,
  solved,
  cycleLimit,
  hazard,
  blocked,

  /// Un bloc gagne le dispatch mais l'état du monde ne change plus :
  /// le programme tourne à vide. Distinct de la limite de cycles, qui
  /// sanctionne la lenteur ; ici c'est une impasse logique, et la dire
  /// tout de suite vaut mieux que vider la jauge pour l'apprendre.
  stalled,
  unsolvable,
}

class ExecResult {
  const ExecResult({
    required this.frames,
    required this.outcome,
    required this.cyclesSpent,
    required this.guardCycles,
    required this.actionCycles,
    required this.bonusCollected,
  });

  final List<Frame> frames;
  final Outcome outcome;
  final int cyclesSpent;
  final int guardCycles;
  final int actionCycles;
  final int bonusCollected;

  Frame get last => frames.last;
  bool get success => outcome == Outcome.solved;

  /// Pénalité de danger physique. Pas de points de vie : le pilier de la
  /// monnaie unique l'interdit, donc les dangers se paient en temps,
  /// mais brutalement. Calibré à ~3 salles faciles.
  static const int hazardPenalty = 150;

  int get penalty => outcome == Outcome.hazard ? hazardPenalty : 0;

  /// Ce que la salle coûte réellement au budget de la run.
  int get totalCost => cyclesSpent + penalty;
}
