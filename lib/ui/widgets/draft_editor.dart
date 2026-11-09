/// La carte du bloc en cours — SURFACE D'ÉDITION, pas un affichage.
///
/// Le premier prototype séparait les deux : la palette modifiait un
/// modèle invisible, et cette carte n'en montrait que le résultat. On
/// ne voyait donc ni comment changer la garde par défaut, ni comment
/// retirer une ligne posée par erreur.
///
/// Règle retenue : **tout ce qui est affiché ici se manipule ici.**
/// Chaque terme de garde et chaque ligne portent leur propre `×`, et
/// un curseur montre où atterrira la prochaine action.
library;

import 'package:flutter/material.dart';

import '../../i18n/strings.dart';
import '../../vm/ast.dart';
import '../theme/art.dart';
import '../theme/audio.dart';
import 'code_render.dart';
import 'guard_composer.dart';
import 'palette.dart';

class DraftEditor extends StatelessWidget {
  const DraftEditor({
    super.key,
    required this.draft,
    required this.enabled,
    this.blocksAbove = 0,
  });

  final BlockDraft draft;
  final bool enabled;

  /// Nombre de blocs gelés au-dessus. Sert à prévenir du cas le plus
  /// coûteux du jeu : un bloc sans garde les neutralise TOUS, parce
  /// que le dernier match gagne.
  final int blocksAbove;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: draft,
      builder: (context, _) {
        final lines = renderBody(draft.body, 0, draft.focusedList);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _guardRow(),
            if (draft.guard.isAlways && blocksAbove > 0) ...[
              const SizedBox(height: 2),
              Text(
                Tr.n('editor.catchAll', blocksAbove),
                style: Type.small.copyWith(color: Palette.danger),
              ),
            ],
            const SizedBox(height: Space.xs),
            Row(
              children: [
                Text(Tr.get('editor.doing'), style: Type.label),
                const Spacer(),
                if (draft.depth > 0)
                  Text(
                    Tr.n('editor.inside', draft.depth),
                    style: Type.small.copyWith(color: Palette.accent),
                  ),
                const SizedBox(width: Space.s),
                Text('~${draft.estimatedCost}', style: Type.small),
              ],
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  if (draft.body.isEmpty && lines.length <= 1)
                    Padding(
                      padding: const EdgeInsets.only(top: Space.xs),
                      child: Text(
                        Tr.get('editor.bodyEmpty'),
                        style: Type.small,
                      ),
                    ),
                  for (final l in lines) _line(l),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _guardRow() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(Tr.get('block.when'), style: Type.label),
      const SizedBox(width: Space.s),
      Expanded(
        child: GuardPreview(
          guard: draft.guard,
          onRemove: enabled ? draft.removeGuardTerm : null,
          onToggleOp: enabled
              ? () => draft.setGuardOp(
                  draft.guard.op == GuardOp.all ? GuardOp.any : GuardOp.all,
                )
              : null,
        ),
      ),
    ],
  );

  Widget _line(CodeLine l) {
    if (l.isCursor) {
      return Padding(
        padding: EdgeInsets.only(left: l.depth * 14.0, top: 1, bottom: 1),
        child: Row(
          children: [
            Container(width: 10, height: 2, color: Palette.accent),
            const SizedBox(width: 4),
            Text(l.text, style: Type.small.copyWith(color: Palette.accent)),
          ],
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(left: l.depth * 14.0, top: 1, bottom: 1),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l.text,
              style: Type.code.copyWith(
                color: l.isKeyword ? Palette.dim : Palette.ink,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (enabled && l.stmt != null)
            InkWell(
              onTap: () {
                Sfx.play(SfxEvent.uiBack);
                draft.removeStmt(l.stmt!);
              },
              child: Icon(Icons.close, size: 13, color: Palette.dim),
            ),
        ],
      ),
    );
  }
}
