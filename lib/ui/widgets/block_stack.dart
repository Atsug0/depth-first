/// LA PILE DE BLOCS. Append-only : tout ce qui est gelé est en lecture
/// seule, pour toujours.
///
/// Les blocs gelés sont repliés par défaut et se déplient
/// AUTOMATIQUEMENT quand ils se déclenchent. C'est ce qui produit,
/// gratuitement, le moment « ah non, pas CE bloc » — le cœur émotionnel
/// du pilier append-only.
library;

import 'package:flutter/material.dart';

import '../../i18n/strings.dart';
import '../../vm/ast.dart';
import '../theme/art.dart';
import 'code_render.dart';

class BlockStackView extends StatelessWidget {
  const BlockStackView({
    super.key,
    required this.program,
    required this.slots,
    this.activeBlock,
    this.matched = const {},
    this.activeStmtId,
    this.onDiscardDraft,
  });

  final Program program;
  final int slots;
  final int? activeBlock;

  /// Blocs dont la garde était vraie ce tick. Ceux qui ne sont pas
  /// actifs ont été supplantés — c'est là que le joueur apprend la
  /// règle du dernier match gagne.
  final Set<int> matched;
  final int? activeStmtId;
  final VoidCallback? onDiscardDraft;

  @override
  Widget build(BuildContext context) {
    if (program.blocks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(Space.m),
        child: Text(Tr.get('block.empty'), style: Type.small),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(Space.s),
      itemCount: program.blocks.length,
      itemBuilder: (context, i) {
        final b = program.blocks[i];
        final isActive = activeBlock == i;
        return _BlockCard(
          index: i,
          block: b,
          active: isActive,
          outranked: !isActive && matched.contains(i),
          // Un bloc gelé se déplie quand il se déclenche.
          // Un bloc supplanté se déplie aussi : c'est le moment où
          // le joueur doit lire sa garde et comprendre pourquoi.
          expanded: isActive || !b.frozen || matched.contains(i),
          activeStmtId: isActive ? activeStmtId : null,
          onDiscard: !b.frozen ? onDiscardDraft : null,
        );
      },
    );
  }
}

class _BlockCard extends StatelessWidget {
  const _BlockCard({
    required this.index,
    required this.block,
    required this.active,
    required this.outranked,
    required this.expanded,
    required this.activeStmtId,
    this.onDiscard,
  });

  final int index;
  final Block block;
  final bool active;
  final bool outranked;
  final bool expanded;
  final int? activeStmtId;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    // Un bloc supplanté a bien été évalué et sa garde était vraie :
    // c'est un bloc plus bas qui l'a emporté. Sans ce repère, le
    // joueur croit que son nouveau bloc n'a jamais tourné.
    final status = outranked
        ? Tr.get('block.outranked')
        : block.corrupted
        ? Tr.get('block.corrupted')
        : block.inherited
        ? Tr.get('block.inherited')
        : active
        ? Tr.get('block.active')
        : block.frozen
        ? Tr.get('block.frozen')
        : Tr.get('block.draft');

    final edge = active
        ? Palette.accent
        : outranked
        ? Palette.gold
        : block.corrupted
        ? Palette.danger
        : block.frozen
        ? Palette.line
        : Palette.gold;

    // Une tablette gravée : la pierre, et une arête de lumière à
    // gauche quand le bloc est actif. Pas de cadre fermé.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      margin: const EdgeInsets.only(bottom: Space.xs),
      decoration: BoxDecoration(
        color: active
            ? Palette.accent.withValues(alpha: 0.10)
            : Palette.bg.withValues(alpha: 0.55),
        border: Border(
          left: BorderSide(color: edge, width: active ? 3 : 1.5),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(Space.m, Space.s, Space.s, Space.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${index + 1}',
                style: Type.small.copyWith(
                  color: edge,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: Space.s),
              Expanded(
                child: Text(
                  '${Tr.get('block.when')} ${guardLabel(block.guard)}',
                  style: Type.code.copyWith(
                    color: active ? Palette.ink : Palette.ink,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (outranked)
                Tooltip(
                  message: Tr.get('block.outrankedWhy'),
                  child: Text(status, style: Type.small.copyWith(color: edge)),
                )
              else
                Text(status, style: Type.small.copyWith(color: edge)),
              if (onDiscard != null) ...[
                const SizedBox(width: Space.xs),
                InkWell(
                  onTap: onDiscard,
                  child: Icon(Icons.close, size: 14, color: Palette.dim),
                ),
              ],
            ],
          ),
          if (expanded) ...[
            const SizedBox(height: Space.xs),
            ...renderBody(block.body).map((line) {
              final isCursor = line.stmtId == activeStmtId;
              return Padding(
                padding: EdgeInsets.only(
                  left: Space.m + line.depth * 14,
                  top: 1,
                  bottom: 1,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 12,
                      child: Text(
                        isCursor ? '▸' : '',
                        style: Type.code.copyWith(color: Palette.accent),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        line.text,
                        style: Type.code.copyWith(
                          color: isCursor
                              ? Palette.accent
                              : line.isKeyword
                              ? Palette.dim
                              : Palette.ink,
                          fontWeight: isCursor
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (block.body.isEmpty)
              Padding(
                padding: const EdgeInsets.only(left: Space.m),
                child: Text('—', style: Type.small),
              ),
          ],
        ],
      ),
    );
  }
}
