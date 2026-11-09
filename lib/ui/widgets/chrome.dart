/// Barre d'état, timeline et panneau de résultat.
///
/// Règle portée par ces widgets : une taxe invisible n'enseigne rien.
/// La ventilation des cycles entre gardes et actions est affichée en
/// permanence, parce que c'est elle qui apprend au joueur à écrire
/// serré dès le premier étage.
library;

import 'package:flutter/material.dart';

import '../../game/run.dart';
import '../../i18n/strings.dart';
import '../../vm/generator.dart';
import '../../vm/room.dart';
import '../../vm/trace.dart';
import '../theme/art.dart';
import 'dungeon_backdrop.dart';

/// Le HUD : du texte posé sur la pierre, avec un filet de lumière.
/// Aucun cadre — l'information n'a pas besoin d'être enfermée.
class StatusBar extends StatelessWidget {
  const StatusBar({
    super.key,
    required this.run,
    required this.frame,
    required this.compact,
  });

  final RunState run;
  final Frame? frame;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final room = run.room;
    final ratio = (run.budget / Economy.startingBudget).clamp(0.0, 1.0);
    final low = ratio < 0.25;
    final f = frame;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.m),
          // Le HUD doit tenir sur une ligne à toute largeur : on le
          // laisse rétrécir plutôt que déborder.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${run.budget}',
                  style: Type.big.copyWith(
                    fontSize: 26,
                    letterSpacing: 1,
                    color: low ? Palette.danger : Palette.ink,
                  ),
                ),
                const SizedBox(width: Space.xs),
                Text(Tr.get('hud.time').toLowerCase(), style: Type.small),
                const SizedBox(width: Space.l),
                _fact(Tr.get('hud.floor'), '${run.floor}'),
                const SizedBox(width: Space.m),
                _fact(
                  Tr.get('hud.blocks'),
                  '${run.blocksUsed}/${run.slots}',
                  color: run.canAddBlock ? null : Palette.gold,
                ),
                if (!compact && room != null) ...[
                  const SizedBox(width: Space.m),
                  _fact(Tr.get('hud.reference'), '${room.referenceCost}'),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.xs),
        SpectralGauge(ratio: ratio.toDouble(), low: low),
        const SizedBox(height: Space.xs),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.m),
          child: Row(
            children: [
              if (room != null) ...[
                _Badge(Tr.get('arch.${room.archetype.name}')),
                if (room.tiles.any((t) => t == Tile.spike || t == Tile.pit))
                  _Badge(Tr.get('arch.warnSpikes'), color: Palette.danger),
                if (room.fog)
                  _Badge(Tr.get('arch.warnFog'), color: Palette.gold),
              ],
              const Spacer(),
              if (f != null)
                Text(
                  '${f.cycles}  ·  ${Tr.get('hud.guards')} ${f.guardCycles}'
                  '  ·  ${Tr.get('hud.actions')} ${f.actionCycles}',
                  style: Type.small.copyWith(color: Palette.accent),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _fact(String label, String value, {Color? color}) => Row(
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('$label ', style: Type.small),
      Text(
        value,
        style: Type.code.copyWith(
          fontWeight: FontWeight.w700,
          color: color ?? Palette.ink,
        ),
      ),
    ],
  );
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, {this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: Space.m),
    child: Text(
      text.toUpperCase(),
      style: Type.small.copyWith(
        fontSize: 9,
        letterSpacing: 1.6,
        color: color ?? Palette.dim,
      ),
    ),
  );
}

/// Timeline scrubbable. Gratuite grâce à l'architecture trace-based :
/// ce n'est qu'un index dans une liste. C'est l'outil de debug ET
/// l'outil de spectacle.
class TimelineBar extends StatelessWidget {
  const TimelineBar({
    super.key,
    required this.total,
    required this.index,
    required this.playing,
    required this.speed,
    required this.onSeek,
    required this.onTogglePlay,
    required this.onStep,
    required this.onRestart,
    required this.onSpeed,
  });

  final int total;
  final int index;
  final bool playing;
  final int speed;
  final ValueChanged<int> onSeek;
  final VoidCallback onTogglePlay;
  final ValueChanged<int> onStep;
  final VoidCallback onRestart;
  final VoidCallback onSpeed;

  @override
  Widget build(BuildContext context) {
    final maxIdx = (total - 1).clamp(0, 1 << 30);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.m,
        vertical: Space.xs,
      ),
      decoration: BoxDecoration(
        color: Palette.panel,
        border: Border.all(color: Palette.line),
        borderRadius: BorderRadius.circular(Space.radius),
      ),
      child: Row(
        children: [
          _TBtn(Icons.first_page, onRestart),
          _TBtn(Icons.chevron_left, () => onStep(-1)),
          _TBtn(
            playing ? Icons.pause : Icons.play_arrow,
            onTogglePlay,
            accent: true,
          ),
          _TBtn(Icons.chevron_right, () => onStep(1)),
          _TBtn(Icons.last_page, () => onSeek(maxIdx)),
          const SizedBox(width: Space.s),
          InkWell(
            onTap: onSpeed,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: Palette.line),
                borderRadius: BorderRadius.circular(Space.radius),
              ),
              child: Text('×$speed', style: Type.small),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 2,
                activeTrackColor: Palette.accent,
                inactiveTrackColor: Palette.line,
                thumbColor: Palette.accent,
                overlayShape: SliderComponentShape.noOverlay,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              ),
              child: Slider(
                value: index.toDouble().clamp(0, maxIdx.toDouble()),
                min: 0,
                max: maxIdx.toDouble().clamp(1, double.infinity),
                onChanged: (v) => onSeek(v.round()),
              ),
            ),
          ),
          Text('$index/$maxIdx', style: Type.small),
        ],
      ),
    );
  }
}

class _TBtn extends StatelessWidget {
  const _TBtn(this.icon, this.onTap, {this.accent = false});
  final IconData icon;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onTap,
    icon: Icon(icon, size: 18),
    color: accent ? Palette.accent : Palette.dim,
    visualDensity: VisualDensity.compact,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
  );
}

/// Un seul bloc a remporté tous les dispatches alors que d'autres
/// matchaient : c'est le piège du bloc sans garde, et c'est la cause
/// la plus fréquente d'un « mon bloc ne se déclenche pas ».
bool _oneBlockMonopolised(ExecResult r) {
  final winners = <int>{};
  final matched = <int>{};
  for (final f in r.frames) {
    if (f.activeBlock != null) winners.add(f.activeBlock!);
    matched.addAll(f.matched);
  }
  return !r.success && winners.length == 1 && matched.length > 1;
}

String outcomeLabel(ExecResult r) => switch (r.outcome) {
  Outcome.solved => Tr.get('outcome.solved'),
  Outcome.cycleLimit => Tr.get('outcome.cycleLimit'),
  Outcome.blocked => Tr.get('outcome.blocked'),
  Outcome.hazard =>
    r.last.event == FrameEvent.hazardPit
        ? Tr.get('outcome.pit')
        : Tr.get('outcome.spike'),
  _ => Tr.get('outcome.cycleLimit'),
};

class OutcomePanel extends StatelessWidget {
  const OutcomePanel({super.key, required this.result, required this.actions});

  final FloorResult result;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final r = result.exec;
    final ok = r.success;
    return Container(
      padding: const EdgeInsets.all(Space.m),
      decoration: BoxDecoration(
        color: Palette.bg.withValues(alpha: 0.88),
        border: Border(
          left: BorderSide(color: ok ? Palette.good : Palette.danger, width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            outcomeLabel(r),
            style: Type.title.copyWith(
              color: ok ? Palette.good : Palette.danger,
            ),
          ),
          const SizedBox(height: Space.s),
          _line(Tr.get('hud.cycles'), '${r.cyclesSpent}'),
          if (r.penalty > 0)
            _line(
              Tr.get('outcome.penalty'),
              '+${r.penalty}',
              color: Palette.danger,
            ),
          if (result.refund > 0)
            _line(
              Tr.get('outcome.refund'),
              '−${result.refund}',
              color: Palette.good,
            ),
          if (result.bonus > 0)
            _line(
              Tr.get('outcome.bonus'),
              '−${result.bonus}',
              color: Palette.gold,
            ),
          Divider(color: Palette.line, height: Space.l),
          _line(
            Tr.get('outcome.netCost'),
            '${result.netCost}',
            color: Palette.ink,
            bold: true,
          ),
          if (!ok) ...[
            const SizedBox(height: Space.s),
            if (_oneBlockMonopolised(r))
              Text(
                Tr.get('outcome.oneBlockWon'),
                style: Type.small.copyWith(color: Palette.gold),
              )
            else if (r.outcome == Outcome.stalled)
              Text(Tr.get('outcome.stalledWhy'), style: Type.small)
            else if (r.outcome == Outcome.blocked)
              Text(Tr.get('outcome.blocked'), style: Type.small),
            const SizedBox(height: Space.xs),
            Text(Tr.get('outcome.stillToSolve'), style: Type.small),
          ],
          const SizedBox(height: Space.m),
          Wrap(spacing: Space.s, runSpacing: Space.s, children: actions),
        ],
      ),
    );
  }

  Widget _line(String k, String v, {Color? color, bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: Type.small),
            Text(
              v,
              style: Type.code.copyWith(
                color: color ?? Palette.ink,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      );
}

class ActionButton extends StatelessWidget {
  const ActionButton(
    this.label,
    this.onTap, {
    super.key,
    this.primary = false,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = danger
        ? Palette.danger
        : primary
        ? Palette.accent
        : Palette.dim;
    return Opacity(
      opacity: onTap == null ? 0.35 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Space.radius),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.m,
            vertical: Space.s,
          ),
          decoration: BoxDecoration(
            color: primary
                ? Palette.accent.withValues(alpha: 0.12)
                : Colors.transparent,
            border: Border.all(color: c, width: primary ? 1.4 : 1),
          ),
          child: Text(
            label,
            style: Type.code.copyWith(color: c, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

/// Repère de progression pour l'écran de fin.
String archetypeOf(int floor) {
  final spec = campaign[(floor - 1).clamp(0, campaign.length - 1)];
  return Tr.get('arch.${spec.archetype.name}');
}
