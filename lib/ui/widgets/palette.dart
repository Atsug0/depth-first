/// L'ÉDITEUR. Édition par sélection dans une palette, jamais au
/// clavier : même geste sur desktop et mobile, et aucune syntaxe
/// invalide n'est représentable.
library;

import 'package:flutter/material.dart';

import '../../game/run.dart';
import '../../i18n/strings.dart';
import '../../vm/ast.dart';
import '../theme/art.dart';
import '../theme/audio.dart';
import 'code_render.dart';
import 'guard_composer.dart';

/// Le bloc en cours de composition. Un seul niveau de pile de focus
/// suffit à imbriquer boucles et conditions.
class BlockDraft extends ChangeNotifier {
  Guard guard = const Guard.always();
  final List<Stmt> body = [];
  final List<List<Stmt>> _focus = [];

  /// Les conditionnelles ouvertes, pour savoir si un SINON est possible
  /// et vers quelle branche basculer.
  final List<IfStmt> _openIfs = [];

  /// Le prochain terme ajouté sera-t-il nié ? Un NON qui s'arme avant
  /// le terme, plutôt qu'un appui sur un terme déjà posé : ça évite de
  /// devoir viser un chip minuscule au pouce.
  bool pendingNot = false;

  bool get canElse =>
      _openIfs.isNotEmpty && identical(_target, _openIfs.last.then);

  List<Stmt> get _target => _focus.isEmpty ? body : _focus.last;
  int get depth => _focus.length;
  bool get isEmpty => body.isEmpty;
  int get estimatedCost => guard.cost + estimateBodyCost(body);

  /// Ajoute un terme à la garde. Les termes se cumulent : c'est
  /// l'opérateur courant qui décide de leur combinaison.
  void addGuardTerm(GuardKind kind, {int arg = 0}) {
    guard = guard.plus(GuardTerm(kind, arg: arg, negated: pendingNot));
    pendingNot = false;
    notifyListeners();
  }

  void toggleNot() {
    pendingNot = !pendingNot;
    notifyListeners();
  }

  void setGuardOp(GuardOp op) {
    guard = guard.withOp(op);
    notifyListeners();
  }

  void dropGuardTerm() {
    guard = guard.dropLast();
    notifyListeners();
  }

  void removeGuardTerm(int index) {
    final terms = [...guard.terms]..removeAt(index);
    guard = Guard(terms, op: guard.op);
    notifyListeners();
  }

  /// La liste où atterrira la prochaine action. Sert à dessiner le
  /// curseur d'insertion : sans lui, on ne sait pas si on écrit dans
  /// la boucle ou après elle.
  List<Stmt> get focusedList => _target;

  /// Supprime UNE ligne, où qu'elle soit dans l'imbrication.
  void removeStmt(Stmt target) {
    if (!_removeFrom(body, target)) return;
    _repairFocus();
    notifyListeners();
  }

  bool _removeFrom(List<Stmt> list, Stmt target) {
    for (var i = 0; i < list.length; i++) {
      if (identical(list[i], target)) {
        list.removeAt(i);
        return true;
      }
      final s = list[i];
      if (s is WhileStmt && _removeFrom(s.body, target)) return true;
      if (s is IfStmt &&
          (_removeFrom(s.then, target) || _removeFrom(s.otherwise, target))) {
        return true;
      }
      if (s is RepeatStmt && _removeFrom(s.body, target)) return true;
    }
    return false;
  }

  /// Si on vient de supprimer la boucle dans laquelle on écrivait, le
  /// curseur pointerait dans le vide. On le ramène à la racine.
  void _repairFocus() {
    final reachable = <List<Stmt>>[body];
    void walk(List<Stmt> list) {
      for (final s in list) {
        if (s is WhileStmt) {
          reachable.add(s.body);
          walk(s.body);
        } else if (s is IfStmt) {
          reachable
            ..add(s.then)
            ..add(s.otherwise);
          walk(s.then);
          walk(s.otherwise);
        } else if (s is RepeatStmt) {
          reachable.add(s.body);
          walk(s.body);
        }
      }
    }

    walk(body);
    if (_focus.any((f) => !reachable.any((r) => identical(r, f)))) {
      _focus.clear();
      _openIfs.clear();
    }
  }

  void clearGuard() {
    guard = const Guard.always();
    pendingNot = false;
    notifyListeners();
  }

  void addAction(ActionKind k, {int arg = 0}) {
    _target.add(ActionStmt(k, arg: arg));
    notifyListeners();
  }

  void openWhile(Guard cond) {
    final s = WhileStmt(cond, []);
    _target.add(s);
    _focus.add(s.body);
    notifyListeners();
  }

  void openIf(Guard cond) {
    final s = IfStmt(cond, [], []);
    _target.add(s);
    _openIfs.add(s);
    _focus.add(s.then);
    notifyListeners();
  }

  /// Bascule de la branche vraie vers la branche fausse du SI courant.
  void openElse() {
    if (!canElse) return;
    _focus.removeLast();
    _focus.add(_openIfs.last.otherwise);
    notifyListeners();
  }

  void closeNesting() {
    if (_focus.isEmpty) return;
    final closing = _focus.removeLast();
    if (_openIfs.isNotEmpty &&
        (identical(closing, _openIfs.last.then) ||
            identical(closing, _openIfs.last.otherwise))) {
      _openIfs.removeLast();
    }
    notifyListeners();
  }

  void undo() {
    if (_target.isNotEmpty) {
      _target.removeLast();
    } else if (_focus.isNotEmpty) {
      _focus.removeLast();
      if (_target.isNotEmpty) _target.removeLast();
    }
    notifyListeners();
  }

  void clear() {
    body.clear();
    _focus.clear();
    _openIfs.clear();
    guard = const Guard.always();
    pendingNot = false;
    notifyListeners();
  }

  Block toBlock(int floor) =>
      Block(guard: guard, body: List.of(body), floorAdded: floor);
}

/// `always` n'y figure pas : une garde VIDE est déjà « toujours ».
/// Proposer le terme ferait payer un cycle pour un test constant, et
/// laisserait croire qu'il faut le poser pour démarrer.
/// Les trois familles de la palette. Séparées en onglets : les
/// empiler dans une seule colonne obligeait à faire défiler pour
/// passer d'une garde à une action, et on perdait de vue ce qu'on
/// était en train d'écrire.
enum PaletteTab { guards, actions, control }

String paletteTabLabel(PaletteTab t) => switch (t) {
  PaletteTab.guards => Tr.get('tab.guards'),
  PaletteTab.actions => Tr.get('tab.actions'),
  PaletteTab.control => Tr.get('tab.control'),
};

const List<ActionKind> _actionMenu = [
  ActionKind.forward,
  ActionKind.turnLeft,
  ActionKind.turnRight,
  ActionKind.pickUp,
  ActionKind.wait,
  ActionKind.scan,
  ActionKind.jump,
  ActionKind.mark,
  ActionKind.retrace,
  ActionKind.setRegister,
];

class PaletteView extends StatelessWidget {
  const PaletteView({
    super.key,
    required this.draft,
    required this.run,
    required this.enabled,
    required this.tab,
  });

  final BlockDraft draft;
  final RunState run;
  final bool enabled;
  final PaletteTab tab;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: draft,
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.all(Space.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: switch (tab) {
            PaletteTab.guards => _guards(),
            PaletteTab.actions => _actions(),
            PaletteTab.control => _control(context),
          },
        ),
      ),
    );
  }

  List<Widget> _guards() => [
    Text(Tr.get('editor.guardHelp'), style: Type.small),
    const SizedBox(height: Space.s),
    GuardKeypad(
      enabled: enabled,
      pendingNot: draft.pendingNot,
      onToggleNot: draft.toggleNot,
      onAdd: draft.addGuardTerm,
    ),
  ];

  List<Widget> _actions() => [
    Text(Tr.get('editor.actionsHelp'), style: Type.small),
    const SizedBox(height: Space.s),
    Wrap(
      spacing: Space.xs,
      runSpacing: Space.xs,
      children: [
        for (final a in _actionMenu)
          GuardChip(
            label: actionLabel(a),
            cost: a.cycleCost,
            enabled: enabled && run.isUnlocked(a),
            locked: !run.isUnlocked(a),
            onTap: () {
              Sfx.play(SfxEvent.uiTap);
              draft.addAction(a, arg: a == ActionKind.setRegister ? 1 : 0);
            },
          ),
      ],
    ),
  ];

  List<Widget> _control(BuildContext context) => [
    Text(Tr.get('editor.controlHelp'), style: Type.small),
    const SizedBox(height: Space.s),
    Wrap(
      spacing: Space.xs,
      runSpacing: Space.xs,
      children: [
        GuardChip(
          label: Tr.get('act.while'),
          enabled: enabled,
          onTap: () async {
            // Même composeur que pour la garde de bloc : une condition
            // de boucle accepte donc aussi les ET / OU / NON.
            final g = await showGuardComposer(
              context,
              title: Tr.get('editor.condWhile'),
            );
            if (g != null) draft.openWhile(g);
          },
        ),
        GuardChip(
          label: Tr.get('act.if'),
          enabled: enabled,
          onTap: () async {
            final g = await showGuardComposer(
              context,
              title: Tr.get('editor.condIf'),
            );
            if (g != null) draft.openIf(g);
          },
        ),
        GuardChip(
          label: Tr.get('act.else'),
          enabled: enabled && draft.canElse,
          accent: draft.canElse,
          onTap: () {
            Sfx.play(SfxEvent.uiTap);
            draft.openElse();
          },
        ),
        GuardChip(
          label: Tr.get('editor.endBlock'),
          enabled: enabled && draft.depth > 0,
          accent: draft.depth > 0,
          onTap: () {
            Sfx.play(SfxEvent.uiBack);
            draft.closeNesting();
          },
        ),
      ],
    ),
  ];
}
