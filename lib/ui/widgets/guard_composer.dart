/// Composeur de condition, réutilisable.
///
/// Sert partout où une condition se saisit : la garde d'un bloc, mais
/// aussi celle d'un `TANT QUE` ou d'un `SI`. Le premier prototype ne
/// proposait là qu'un terme unique — on ne pouvait pas écrire
/// `TANT QUE sol libre devant ET NON pics devant`, alors que la garde
/// de bloc, elle, le permettait. Deux grammaires pour la même notion,
/// c'est le genre d'incohérence qui se paie en confusion.
library;

import 'package:flutter/material.dart';

import '../../i18n/strings.dart';
import '../../vm/ast.dart';
import '../theme/art.dart';
import '../theme/audio.dart';
import 'code_render.dart';

/// Les gardes proposées au joueur. `always` n'y figure pas : une
/// condition vide est déjà « toujours ».
const List<GuardKind> guardMenu = [
  GuardKind.floorAhead,
  GuardKind.wallAhead,
  GuardKind.floorRight,
  GuardKind.floorLeft,
  GuardKind.hazardAhead,
  GuardKind.spikeAhead,
  GuardKind.pitAhead,
  GuardKind.itemHere,
  GuardKind.itemAhead,
  GuardKind.exitAhead,
];

/// Ouvre la feuille de composition et renvoie la condition saisie,
/// ou null si le joueur annule.
Future<Guard?> showGuardComposer(
  BuildContext context, {
  required String title,
}) {
  Sfx.play(SfxEvent.uiTap);
  return showModalBottomSheet<Guard>(
    context: context,
    backgroundColor: Palette.panel,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Space.radius)),
    ),
    builder: (context) => _GuardComposerSheet(title: title),
  );
}

class _GuardComposerSheet extends StatefulWidget {
  const _GuardComposerSheet({required this.title});
  final String title;

  @override
  State<_GuardComposerSheet> createState() => _GuardComposerSheetState();
}

class _GuardComposerSheetState extends State<_GuardComposerSheet> {
  Guard guard = const Guard.always();
  bool not = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Space.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title.toUpperCase(), style: Type.label),
            const SizedBox(height: Space.s),
            GuardPreview(
              guard: guard,
              onRemove: (i) => setState(() {
                final terms = [...guard.terms]..removeAt(i);
                guard = Guard(terms, op: guard.op);
              }),
              onToggleOp: () => setState(() {
                guard = guard.withOp(
                  guard.op == GuardOp.all ? GuardOp.any : GuardOp.all,
                );
              }),
            ),
            const SizedBox(height: Space.m),
            GuardKeypad(
              pendingNot: not,
              onToggleNot: () => setState(() => not = !not),
              onAdd: (k) => setState(() {
                guard = guard.plus(GuardTerm(k, negated: not));
                not = false;
              }),
            ),
            const SizedBox(height: Space.l),
            Row(
              children: [
                _sheetButton(
                  Tr.get('editor.cancel'),
                  () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: Space.s),
                _sheetButton(
                  Tr.get('editor.confirm'),
                  guard.terms.isEmpty
                      ? null
                      : () => Navigator.of(context).pop(guard),
                  primary: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetButton(
    String label,
    VoidCallback? onTap, {
    bool primary = false,
  }) {
    final c = primary ? Palette.accent : Palette.dim;
    return Expanded(
      child: Opacity(
        opacity: onTap == null ? 0.35 : 1,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: Space.s),
            decoration: BoxDecoration(
              color: primary ? Palette.accentSoft : null,
              border: Border.all(color: c, width: primary ? 1.6 : 1),
              borderRadius: BorderRadius.circular(Space.radius),
            ),
            child: Center(
              child: Text(
                label,
                style: Type.code.copyWith(
                  color: c,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Affiche une condition composée, chaque terme retirable, l'opérateur
/// tappable. Partagé entre la carte du bloc et la feuille.
class GuardPreview extends StatelessWidget {
  const GuardPreview({
    super.key,
    required this.guard,
    this.onRemove,
    this.onToggleOp,
    this.emptyLabel,
  });

  final Guard guard;
  final void Function(int index)? onRemove;
  final VoidCallback? onToggleOp;
  final String? emptyLabel;

  @override
  Widget build(BuildContext context) {
    final terms = guard.terms;
    if (terms.isEmpty) {
      return Text(
        emptyLabel ?? Tr.get('editor.whenEmpty'),
        style: Type.code.copyWith(color: Palette.dim),
      );
    }
    return Wrap(
      spacing: Space.xs,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < terms.length; i++) ...[
          if (i > 0)
            InkWell(
              onTap: onToggleOp,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  guard.op == GuardOp.all
                      ? Tr.get('guard.and')
                      : Tr.get('guard.or'),
                  style: Type.small.copyWith(
                    color: Palette.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: Palette.gold.withValues(alpha: 0.12),
              border: Border.all(color: Palette.gold),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  termLabel(terms[i]),
                  style: Type.code.copyWith(fontSize: 12, color: Palette.ink),
                ),
                if (onRemove != null) ...[
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () {
                      Sfx.play(SfxEvent.uiBack);
                      onRemove!(i);
                    },
                    child: Icon(Icons.close, size: 12, color: Palette.gold),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Le pavé de gardes : le NON s'arme avant le terme, parce que viser
/// un chip de 40 px pour le nier après coup est pénible au pouce.
class GuardKeypad extends StatelessWidget {
  const GuardKeypad({
    super.key,
    required this.pendingNot,
    required this.onToggleNot,
    required this.onAdd,
    this.enabled = true,
  });

  final bool pendingNot;
  final VoidCallback onToggleNot;
  final void Function(GuardKind kind) onAdd;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Space.xs,
      runSpacing: Space.xs,
      children: [
        GuardChip(
          label: Tr.get('guard.not'),
          enabled: enabled,
          accent: pendingNot,
          onTap: onToggleNot,
        ),
        for (final k in guardMenu)
          GuardChip(
            label: Tr.get('guard.${k.name}'),
            cost: k.cycleCost,
            enabled: enabled,
            onTap: () {
              Sfx.play(SfxEvent.uiTap);
              onAdd(k);
            },
          ),
      ],
    );
  }
}

class GuardChip extends StatelessWidget {
  const GuardChip({
    super.key,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.cost,
    this.locked = false,
    this.accent = false,
  });

  final String label;
  final int? cost;
  final bool enabled;
  final bool locked;
  final bool accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(Space.radius),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.s,
            vertical: Space.xs + 2,
          ),
          // Une rune gravée dans la pierre : fond sourd, liseré fin,
          // angles droits. L'accent ne sert qu'à ce qui est armé.
          decoration: BoxDecoration(
            color: accent
                ? Palette.accent.withValues(alpha: 0.12)
                : Palette.panelHi.withValues(alpha: 0.75),
            border: Border.all(
              color: accent ? Palette.accent : Palette.line,
              width: accent ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (locked)
                Padding(
                  padding: const EdgeInsets.only(right: Space.xs),
                  child: Icon(Icons.lock_outline, size: 11, color: Palette.dim),
                ),
              Text(
                label,
                style: Type.code.copyWith(
                  fontSize: 12,
                  color: accent ? Palette.accent : Palette.ink,
                ),
              ),
              if (cost != null) ...[
                const SizedBox(width: Space.xs),
                Text('$cost', style: Type.small.copyWith(fontSize: 10)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
