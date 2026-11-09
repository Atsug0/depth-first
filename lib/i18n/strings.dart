/// Localisation FR / EN.
///
/// AJOUTER UNE LANGUE :
///   1. ajouter la valeur à `AppLocale`
///   2. ajouter son nom dans `localeLabel`
///   3. dupliquer la map `_fr` et traduire — les clés manquantes
///      retombent automatiquement sur le français
/// Aucune dépendance externe : tout se change ici.
library;

import 'package:flutter/foundation.dart';

enum AppLocale { fr, en }

const Map<AppLocale, String> localeLabel = {
  AppLocale.fr: 'Français',
  AppLocale.en: 'English',
};

class Tr {
  Tr._();

  /// Changer de langue à chaud : tout l'arbre se reconstruit.
  static final ValueNotifier<AppLocale> locale = ValueNotifier<AppLocale>(
    AppLocale.fr,
  );

  static void toggle() =>
      locale.value = locale.value == AppLocale.fr ? AppLocale.en : AppLocale.fr;

  static String call(String key) => get(key);

  static String get(String key) {
    final table = locale.value == AppLocale.fr ? _fr : _en;
    return table[key] ?? _fr[key] ?? key;
  }

  static String n(String key, Object a) => get(key).replaceFirst('{}', '$a');

  static String n2(String key, Object a, Object b) =>
      get(key).replaceFirst('{}', '$a').replaceFirst('{}', '$b');
}

const Map<String, String> _fr = {
  'app.title': 'DEPTH FIRST',
  'app.tagline': 'Écris un programme que tu ne pourras plus réécrire.',

  'hud.time': 'TEMPS',
  'hud.floor': 'ÉTAGE',
  'hud.blocks': 'BLOCS',
  'hud.reference': 'RÉFÉRENCE',
  'hud.cycles': 'CYCLES',
  'hud.guards': 'gardes',
  'hud.actions': 'actions',

  'panel.program': 'LE PROGRAMME',
  'panel.world': 'LE MONDE',
  'panel.palette': 'PALETTE',
  'panel.stack': 'PILE',

  'block.frozen': 'gelé',
  'block.draft': 'en écriture',
  'block.active': 'actif',
  'block.inherited': 'hérité',
  'block.corrupted': 'corrompu',
  'block.when': 'QUAND',
  'block.empty': 'Aucun bloc. Ajoute-en un pour commencer.',
  'block.new': 'NOUVEAU BLOC',
  'block.discard': 'Jeter',
  'block.noSlots': 'Plus de slot disponible',

  'editor.guard': 'Garde',
  'editor.body': 'Corps',
  'editor.actions': 'Actions',
  'editor.control': 'Contrôle',
  'editor.endBlock': 'FIN',
  'editor.undo': 'Annuler',
  'editor.hint': 'Choisis une garde, puis empile des actions.',
  'editor.here': '‹ ici',
  'editor.whenEmpty': 'toujours — appuie sur une garde',
  'editor.doing': 'FAIRE',
  'editor.bodyEmpty': 'Appuie sur une action pour la poser ici',
  'editor.guardHelp': 'Une garde s\'ajoute à la précédente. × pour retirer.',
  'editor.actionsHelp': 'Se posent à l\'endroit du curseur ‹ ici',
  'editor.controlHelp': 'TANT QUE et SI ouvrent un bloc. FIN le referme.',
  'editor.inside': 'dans {} niveau(x)',
  'editor.cancel': 'ANNULER',
  'editor.confirm': 'VALIDER',
  'editor.condWhile': 'Condition de la boucle',
  'editor.condIf': 'Condition du SI',
  'tab.guards': 'GARDES',
  'tab.actions': 'ACTIONS',
  'tab.control': 'CONTRÔLE',
  'editor.catchAll':
      'Sans garde, ce bloc gagnera CHAQUE tick et neutralisera les {} '
      'blocs au-dessus. Ajoute une garde pour ne le déclencher que '
      'dans le cas qui t\'intéresse.',
  'outcome.oneBlockWon':
      'Un seul bloc a gagné tous les ticks. Les autres ont bien été '
      'évalués, mais une garde plus basse l\'a systématiquement emporté.',

  'run.run': 'LANCER',
  'run.running': 'EXÉCUTION',
  'run.replay': 'Rejouer',
  'run.edit': 'Éditer',
  'run.descend': 'DESCENDRE',
  'run.extract': 'EXTRAIRE',
  'run.newRun': 'NOUVELLE RUN',

  'outcome.solved': 'Salle résolue',
  'outcome.cycleLimit': 'Limite de cycles dépassée',
  'outcome.hazard': 'Danger déclenché',
  'outcome.blocked': 'Blocage : aucune garde ne matche',
  'outcome.stalled': 'Le programme tourne à vide',
  'outcome.stalledWhy':
      'Un bloc gagne bien le dispatch, mais plus rien ne change dans le '
      'monde. Il manque une règle pour sortir de cet état.',
  'block.outranked': 'supplanté',
  'block.outrankedWhy':
      'Cette garde était vraie, mais un bloc plus bas l\'a emporté : '
      'le dernier match gagne.',
  'outcome.spike': 'Marché dans des pics',
  'outcome.pit': 'Chute dans le vide',
  'outcome.penalty': 'Pénalité',
  'outcome.refund': 'Sous la référence',
  'outcome.bonus': 'Cases bonus',
  'outcome.netCost': 'Coût net',
  'outcome.stillToSolve': 'La salle reste à résoudre.',

  'end.dead': 'RUN TERMINÉE',
  'end.deadBody':
      'Le temps est tombé à zéro en profondeur. Le loadout équipé est perdu.',
  'end.extracted': 'EXTRACTION RÉUSSIE',
  'end.extractedBody':
      'Tu remontes avec ce que tu as gagné. Les acquis sont définitifs.',
  'end.depth': 'Profondeur atteinte',
  'end.replayAll': 'REVOIR LA RUN',

  'hint.descendOrExtract':
      'Un étage de plus, ou tu rentres ? Descendre coûte {} cycles.',
  'hint.extractionHere':
      'Point d\'extraction. Extraire coûte {} cycles et met fin à la run.',
  'hint.genFailed':
      'Aucune salle ne force une addition à ton programme. Il est déjà très général.',

  'arch.corridor': 'Couloir',
  'arch.turn': 'Virage',
  'arch.maze': 'Labyrinthe',
  'arch.collect': 'Collecte',
  'arch.spikes': 'Pièges',
  'arch.chasm': 'Précipice',
  'arch.extraction': 'Extraction',
  'arch.warnSpikes': 'Dangers signalés',
  'arch.warnFog': 'Brouillard',

  'guard.always': 'toujours',
  'guard.wallAhead': 'mur devant',
  'guard.floorAhead': 'sol libre devant',
  'guard.floorRight': 'sol libre à droite',
  'guard.floorLeft': 'sol libre à gauche',
  'guard.pitAhead': 'vide devant',
  'guard.spikeAhead': 'pics devant',
  'guard.hazardAhead': 'danger devant',
  'guard.itemHere': 'objet ici',
  'guard.itemAhead': 'objet devant',
  'guard.exitAhead': 'sortie devant',
  'guard.registerEquals': 'registre =',
  'guard.not': 'NON',
  'guard.and': 'ET',
  'guard.or': 'OU',
  'guard.clear': 'vider',
  'guard.hint':
      'Enchaîne les gardes : elles se combinent avec ET ou OU, sans '
      'parenthèses. Chaque terme se paie à chaque tick.',

  'act.forward': 'AVANCER',
  'act.turnLeft': 'TOURNER GAUCHE',
  'act.turnRight': 'TOURNER DROITE',
  'act.pickUp': 'RAMASSER',
  'act.wait': 'ATTENDRE',
  'act.scan': 'SCANNER',
  'act.jump': 'SAUTER',
  'act.mark': 'MARQUER',
  'act.retrace': 'RETRACER',
  'act.setRegister': 'REGISTRE',
  'act.while': 'TANT QUE',
  'act.if': 'SI',
  'act.else': 'SINON',
  'act.locked': 'verrouillé',

  'menu.start': 'DESCENDRE',
  'menu.gallery': 'Galerie de sprites',
  'menu.proto': 'prototype',

  'lang.switch': 'EN',
};

const Map<String, String> _en = {
  'app.title': 'DEPTH FIRST',
  'app.tagline': 'Write a program you will never be allowed to rewrite.',

  'hud.time': 'TIME',
  'hud.floor': 'FLOOR',
  'hud.blocks': 'BLOCKS',
  'hud.reference': 'REFERENCE',
  'hud.cycles': 'CYCLES',
  'hud.guards': 'guards',
  'hud.actions': 'actions',

  'panel.program': 'THE PROGRAM',
  'panel.world': 'THE WORLD',
  'panel.palette': 'PALETTE',
  'panel.stack': 'STACK',

  'block.frozen': 'frozen',
  'block.draft': 'drafting',
  'block.active': 'active',
  'block.inherited': 'inherited',
  'block.corrupted': 'corrupted',
  'block.when': 'WHEN',
  'block.empty': 'No blocks yet. Add one to begin.',
  'block.new': 'NEW BLOCK',
  'block.discard': 'Discard',
  'block.noSlots': 'No slot left',

  'editor.guard': 'Guard',
  'editor.body': 'Body',
  'editor.actions': 'Actions',
  'editor.control': 'Control',
  'editor.endBlock': 'END',
  'editor.undo': 'Undo',
  'editor.hint': 'Pick a guard, then stack actions.',
  'editor.here': '‹ here',
  'editor.whenEmpty': 'always — tap a guard',
  'editor.doing': 'DO',
  'editor.bodyEmpty': 'Tap an action to drop it here',
  'editor.guardHelp': 'Guards add up. × to remove one.',
  'editor.actionsHelp': 'Land at the ‹ here cursor',
  'editor.controlHelp': 'WHILE and IF open a block. END closes it.',
  'editor.inside': '{} level(s) deep',
  'editor.cancel': 'CANCEL',
  'editor.confirm': 'CONFIRM',
  'editor.condWhile': 'Loop condition',
  'editor.condIf': 'IF condition',
  'tab.guards': 'GUARDS',
  'tab.actions': 'ACTIONS',
  'tab.control': 'CONTROL',
  'editor.catchAll':
      'With no guard, this block wins EVERY tick and neutralises the {} '
      'blocks above it. Add a guard so it only fires in the case you '
      'care about.',
  'outcome.oneBlockWon':
      'A single block won every tick. The others were evaluated, but a '
      'lower guard consistently outranked them.',

  'run.run': 'RUN',
  'run.running': 'RUNNING',
  'run.replay': 'Replay',
  'run.edit': 'Edit',
  'run.descend': 'DESCEND',
  'run.extract': 'EXTRACT',
  'run.newRun': 'NEW RUN',

  'outcome.solved': 'Room solved',
  'outcome.cycleLimit': 'Cycle limit exceeded',
  'outcome.hazard': 'Hazard triggered',
  'outcome.blocked': 'Stalled: no guard matches',
  'outcome.stalled': 'The program is spinning',
  'outcome.stalledWhy':
      'A block does win the dispatch, but nothing changes in the world '
      'any more. A rule is missing to get out of this state.',
  'block.outranked': 'outranked',
  'block.outrankedWhy':
      'This guard was true, but a lower block won: last match wins.',
  'outcome.spike': 'Walked into spikes',
  'outcome.pit': 'Fell into the void',
  'outcome.penalty': 'Penalty',
  'outcome.refund': 'Under reference',
  'outcome.bonus': 'Bonus tiles',
  'outcome.netCost': 'Net cost',
  'outcome.stillToSolve': 'The room still has to be solved.',

  'end.dead': 'RUN OVER',
  'end.deadBody': 'Time hit zero while deep. The equipped loadout is lost.',
  'end.extracted': 'EXTRACTION SUCCESSFUL',
  'end.extractedBody':
      'You surface with what you earned. Unlocks are permanent.',
  'end.depth': 'Depth reached',
  'end.replayAll': 'WATCH THE RUN',

  'hint.descendOrExtract':
      'One floor deeper, or head back? Descending costs {} cycles.',
  'hint.extractionHere':
      'Extraction point. Extracting costs {} cycles and ends the run.',
  'hint.genFailed':
      'No room forces an addition to your program. It is already very general.',

  'arch.corridor': 'Corridor',
  'arch.turn': 'Turn',
  'arch.maze': 'Maze',
  'arch.collect': 'Collect',
  'arch.spikes': 'Traps',
  'arch.chasm': 'Chasm',
  'arch.extraction': 'Extraction',
  'arch.warnSpikes': 'Hazards signposted',
  'arch.warnFog': 'Fog',

  'guard.always': 'always',
  'guard.wallAhead': 'wall ahead',
  'guard.floorAhead': 'clear floor ahead',
  'guard.floorRight': 'clear floor right',
  'guard.floorLeft': 'clear floor left',
  'guard.pitAhead': 'void ahead',
  'guard.spikeAhead': 'spikes ahead',
  'guard.hazardAhead': 'hazard ahead',
  'guard.itemHere': 'item here',
  'guard.itemAhead': 'item ahead',
  'guard.exitAhead': 'exit ahead',
  'guard.registerEquals': 'register =',
  'guard.not': 'NOT',
  'guard.and': 'AND',
  'guard.or': 'OR',
  'guard.clear': 'clear',
  'guard.hint':
      'Chain guards: they combine with AND or OR, no parentheses. '
      'Every term is paid on every tick.',

  'act.forward': 'FORWARD',
  'act.turnLeft': 'TURN LEFT',
  'act.turnRight': 'TURN RIGHT',
  'act.pickUp': 'PICK UP',
  'act.wait': 'WAIT',
  'act.scan': 'SCAN',
  'act.jump': 'JUMP',
  'act.mark': 'MARK',
  'act.retrace': 'RETRACE',
  'act.setRegister': 'REGISTER',
  'act.while': 'WHILE',
  'act.if': 'IF',
  'act.else': 'ELSE',
  'act.locked': 'locked',

  'menu.start': 'DESCEND',
  'menu.gallery': 'Sprite gallery',
  'menu.proto': 'prototype',

  'lang.switch': 'FR',
};
