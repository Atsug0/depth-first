/// L'écran de jeu.
///
/// INVARIANTE ABSOLUE, sur desktop comme sur mobile :
/// le monde et le bloc en cours sont TOUJOURS visibles simultanément,
/// et rien ne les recouvre jamais. Tout le reste — pile gelée, palette,
/// stats — est escamotable. C'est la traduction directe de l'exigence
/// de lisibilité : le lien entre l'instruction qui s'exécute et ce
/// qu'elle produit à l'écran est la seule chose que le joueur ne doit
/// jamais perdre de vue.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../game/run.dart';
import '../../i18n/strings.dart';
import '../../vm/trace.dart';
import '../theme/art.dart';
import '../theme/audio.dart';
import '../widgets/block_stack.dart';
import '../widgets/chrome.dart';
import '../widgets/dungeon_backdrop.dart';
import '../widgets/code_render.dart';
import '../widgets/draft_editor.dart';
import '../widgets/palette.dart';
import '../widgets/world_view.dart';

/// Au-delà, on a la place pour tout montrer d'un coup.
const double kDesktopBreakpoint = 900;

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late RunState run;
  late BlockDraft draft;

  int frameIndex = 0;
  bool playing = false;
  int speed = 4;
  Timer? _timer;
  FloorResult? pending;

  /// Onglets du bas. La pile et les trois familles de la palette sont
  /// au MÊME niveau : imbriquer « palette » puis « gardes / actions »
  /// aurait demandé deux gestes pour atteindre une action.
  int mobileTab = 1;
  PaletteTab deskTab = PaletteTab.guards;

  static const List<PaletteTab> _paletteTabs = PaletteTab.values;

  @override
  void initState() {
    super.initState();
    _newRun();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _newRun() {
    _timer?.cancel();
    setState(() {
      run = RunState(seed: DateTime.now().millisecondsSinceEpoch % 100000);
      draft = BlockDraft();
      frameIndex = 0;
      playing = false;
      pending = null;
    });
    Music.play(MusicTrack.descent);
  }

  ExecResult? get exec => run.lastExec;
  Frame? get frame {
    final e = exec;
    if (e == null || e.frames.isEmpty) return null;
    return e.frames[frameIndex.clamp(0, e.frames.length - 1)];
  }

  // ── Exécution ────────────────────────────────────────────────────

  void _run() {
    if (draft.isEmpty && run.draftBlock == null) return;

    // Le bloc en cours d'écriture est validé au moment du RUN : c'est là
    // qu'il rejoint la pile et devient irréversible au coup suivant.
    if (run.draftBlock == null && !draft.isEmpty) {
      if (!run.appendBlock(draft.toBlock(run.floor))) return;
      draft.clear();
      Sfx.play(SfxEvent.blockAdd);
    }

    Sfx.play(SfxEvent.runStart);
    setState(() {
      run.execute();
      frameIndex = 0;
      pending = null;
      playing = true;
    });
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(milliseconds: (240 / speed).round().clamp(16, 400)),
      (_) {
        final e = exec;
        if (e == null) return;
        if (frameIndex >= e.frames.length - 1) {
          _finishPlayback();
          return;
        }
        setState(() => frameIndex++);
        _sfxFor(e.frames[frameIndex].event);
      },
    );
  }

  void _sfxFor(FrameEvent ev) {
    switch (ev) {
      case FrameEvent.picked:
        Sfx.play(SfxEvent.pickUp);
      case FrameEvent.bonus:
        Sfx.play(SfxEvent.bonus);
      case FrameEvent.hazardSpike:
        Sfx.play(SfxEvent.hazardSpike);
      case FrameEvent.hazardPit:
        Sfx.play(SfxEvent.hazardPit);
      case FrameEvent.scanned:
        Sfx.play(SfxEvent.scan);
      case FrameEvent.marked:
        Sfx.play(SfxEvent.mark);
      case FrameEvent.blocked:
        Sfx.play(SfxEvent.blocked);
      case FrameEvent.exitReached:
        Sfx.play(SfxEvent.roomSolved);
      default:
        break;
    }
  }

  /// Le budget ne bouge qu'une fois le replay terminé : le joueur voit
  /// POURQUOI avant de voir la jauge chuter.
  void _finishPlayback() {
    _timer?.cancel();
    final e = exec;
    if (e == null) return;
    setState(() {
      playing = false;
      frameIndex = e.frames.length - 1;
      pending = run.commit(e);
    });
    if (run.phase == RunPhase.dead) Sfx.play(SfxEvent.runDead);
  }

  void _togglePlay() {
    setState(() => playing = !playing);
    if (playing) {
      final e = exec;
      if (e != null && frameIndex >= e.frames.length - 1) frameIndex = 0;
      _startTimer();
    } else {
      _timer?.cancel();
    }
  }

  void _seek(int i) {
    _timer?.cancel();
    final e = exec;
    if (e == null) return;
    setState(() {
      playing = false;
      frameIndex = i.clamp(0, e.frames.length - 1);
    });
  }

  void _backToEdit() {
    _timer?.cancel();
    setState(() {
      playing = false;
      pending = null;
      run.lastExec = null;
      frameIndex = 0;
      run.phase = RunPhase.editing;
    });
  }

  void _descend() {
    Sfx.play(SfxEvent.descend);
    setState(() {
      run.descend();
      draft.clear();
      pending = null;
      frameIndex = 0;
    });
  }

  void _extract() {
    Sfx.play(SfxEvent.extract);
    setState(() {
      run.extract();
      pending = null;
    });
  }

  // ── Rendu ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (run.phase == RunPhase.dead || run.phase == RunPhase.extracted) {
      return _EndScreen(run: run, onRestart: _newRun);
    }

    return LayoutBuilder(
      builder: (context, box) {
        final desktop = box.maxWidth >= kDesktopBreakpoint;
        // Le donjon est le fond, pas un panneau parmi d'autres.
        return DungeonBackdrop(
          child: SafeArea(
            // L'en-tête a déjà consommé l'encoche : ne pas la repayer.
            top: false,
            child: desktop ? _desktop() : _mobile(),
          ),
        );
      },
    );
  }

  // ── Desktop : tout tient à l'écran ───────────────────────────────

  Widget _desktop() => Column(
    children: [
      StatusBar(run: run, frame: frame, compact: false),
      const SizedBox(height: Space.m),
      Expanded(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 300,
              child: Scrim(
                label: Tr.get('panel.program'),
                padding: EdgeInsets.zero,
                trailing: Text(
                  '${run.blocksUsed}/${run.slots}',
                  style: Type.small,
                ),
                child: _stackAndDraft(),
              ),
            ),
            const SizedBox(width: Space.m),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.m),
                child: _worldArea(),
              ),
            ),
            const SizedBox(width: Space.m),
            SizedBox(
              width: 280,
              child: Scrim(
                label: Tr.get('panel.palette'),
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Space.s,
                        Space.s,
                        Space.s,
                        0,
                      ),
                      child: Row(
                        children: [
                          for (final t in _paletteTabs) ...[
                            _tabButton(
                              paletteTabLabel(t),
                              deskTab == t,
                              () => setState(() => deskTab = t),
                            ),
                            if (t != _paletteTabs.last)
                              const SizedBox(width: Space.xs),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      child: PaletteView(
                        draft: draft,
                        run: run,
                        enabled: _editable,
                        tab: deskTab,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: Space.m),
      _controls(),
    ],
  );

  // ── Mobile : pile et palette en drawer, sous les zones fixes ─────

  Widget _mobile() => Column(
    children: [
      StatusBar(run: run, frame: frame, compact: true),
      const SizedBox(height: Space.s),
      // ZONE FIXE 1 — le monde, jamais recouvert
      Expanded(flex: 5, child: _worldArea()),
      const SizedBox(height: Space.s),
      // ZONE FIXE 2 — le bloc en cours, jamais recouvert
      SizedBox(height: 150, child: _currentBlockCard()),
      const SizedBox(height: Space.s),
      // ZONE ESCAMOTABLE — onglets, sous les deux zones fixes
      Row(
        children: [
          _tab(0, Tr.get('panel.stack')),
          const SizedBox(width: Space.xs),
          for (var i = 0; i < _paletteTabs.length; i++) ...[
            _tab(i + 1, paletteTabLabel(_paletteTabs[i])),
            if (i < _paletteTabs.length - 1) const SizedBox(width: Space.xs),
          ],
        ],
      ),
      const SizedBox(height: Space.xs),
      Expanded(
        flex: 4,
        child: Container(
          decoration: BoxDecoration(color: Palette.bg.withValues(alpha: 0.78)),
          clipBehavior: Clip.antiAlias,
          child: mobileTab == 0
              ? BlockStackView(
                  program: run.program,
                  slots: run.slots,
                  activeBlock: frame?.activeBlock,
                  activeStmtId: frame?.activeStmtId,
                  onDiscardDraft: _editable ? _discardDraft : null,
                )
              : PaletteView(
                  draft: draft,
                  run: run,
                  enabled: _editable,
                  tab:
                      _paletteTabs[(mobileTab - 1).clamp(
                        0,
                        _paletteTabs.length - 1,
                      )],
                ),
        ),
      ),
      const SizedBox(height: Space.s),
      _controls(),
    ],
  );

  /// Onglet : un soulignement de lumière. Quatre rectangles bordés
  /// côte à côte fabriquaient une grille de boîtes pour rien.
  Widget _tabButton(String label, bool on, VoidCallback onTap) => Expanded(
    child: InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Space.s),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: on ? Palette.accent : Palette.line,
              width: on ? 2 : 1,
            ),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: Type.small.copyWith(
              fontSize: 10,
              color: on ? Palette.accent : Palette.dim,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ),
  );

  Widget _tab(int i, String label) =>
      _tabButton(label, mobileTab == i, () => setState(() => mobileTab = i));

  // ── Morceaux partagés ────────────────────────────────────────────

  bool get _editable => run.phase == RunPhase.editing && exec == null;

  void _discardDraft() => setState(() {
    run.removeDraft();
    draft.clear();
  });

  Widget _worldArea() {
    final room = run.room;
    if (room == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.l),
          child: Text(
            Tr.get('hint.genFailed'),
            style: Type.small,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(Space.s),
      child: WorldView(room: room, frame: frame),
    );
  }

  Widget _stackAndDraft() => Column(
    children: [
      Expanded(
        child: BlockStackView(
          program: run.program,
          slots: run.slots,
          activeBlock: frame?.activeBlock,
          activeStmtId: frame?.activeStmtId,
          onDiscardDraft: _editable ? _discardDraft : null,
        ),
      ),
      if (_editable)
        Container(
          height: 118,
          padding: const EdgeInsets.all(Space.s),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Palette.line)),
          ),
          child: _draftPreview(),
        ),
    ],
  );

  /// Le bloc en cours. Sur mobile c'est une zone fixe à part entière ;
  /// sur desktop il est en pied de la pile, au même endroit qu'il
  /// occupera une fois validé.
  Widget _currentBlockCard() {
    final f = frame;
    if (f != null && f.activeBlock != null) {
      final b = run.program.blocks[f.activeBlock!];
      final lines = renderBody(b.body);
      return Container(
        padding: const EdgeInsets.fromLTRB(Space.m, Space.s, Space.s, Space.s),
        decoration: BoxDecoration(
          color: Palette.accent.withValues(alpha: 0.10),
          border: Border(left: BorderSide(color: Palette.accent, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${Tr.get('block.when')} ${guardLabel(b.guard)}',
              style: Type.code.copyWith(fontWeight: FontWeight.w700),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (final l in lines)
                    Padding(
                      padding: EdgeInsets.only(left: l.depth * 14.0),
                      child: Text(
                        '${l.stmtId == f.activeStmtId ? '▸ ' : '  '}${l.text}',
                        style: Type.code.copyWith(
                          color: l.stmtId == f.activeStmtId
                              ? Palette.accent
                              : Palette.dim,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    // Le bloc en écriture : une tablette d'or en cours de gravure.
    return Container(
      padding: const EdgeInsets.fromLTRB(Space.m, Space.s, Space.s, Space.s),
      decoration: BoxDecoration(
        color: Palette.bg.withValues(alpha: 0.72),
        border: Border(left: BorderSide(color: Palette.gold, width: 3)),
      ),
      child: _draftPreview(),
    );
  }

  Widget _draftPreview() => DraftEditor(
    draft: draft,
    enabled: _editable,
    blocksAbove: run.program.blocks.where((b) => b.frozen).length,
  );

  Widget _controls() {
    final e = exec;
    final p = pending;

    if (p != null) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 260),
        child: SingleChildScrollView(
          child: OutcomePanel(
            result: p,
            actions: [
              ActionButton(Tr.get('run.replay'), () {
                setState(() => frameIndex = 0);
                _togglePlay();
              }),
              if (!p.exec.success)
                ActionButton(Tr.get('run.edit'), _backToEdit, primary: true),
              if (p.exec.success && !run.atExtraction)
                ActionButton(Tr.get('run.descend'), _descend, primary: true),
              if (p.exec.success && run.atExtraction)
                ActionButton(Tr.get('run.extract'), _extract, primary: true),
            ],
          ),
        ),
      );
    }

    if (e != null) {
      return TimelineBar(
        total: e.frames.length,
        index: frameIndex,
        playing: playing,
        speed: speed,
        onSeek: _seek,
        onTogglePlay: _togglePlay,
        onStep: (d) => _seek(frameIndex + d),
        onRestart: () => _seek(0),
        onSpeed: () {
          setState(() => speed = speed == 1 ? 4 : (speed == 4 ? 16 : 1));
          if (playing) _startTimer();
        },
      );
    }

    return AnimatedBuilder(
      animation: draft,
      builder: (context, _) => Row(
        children: [
          ActionButton(
            Tr.get('run.run'),
            (draft.isEmpty || !run.canAddBlock) ? null : _run,
            primary: true,
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: Text(
              !run.canAddBlock
                  ? Tr.get('block.noSlots')
                  : run.atExtraction
                  ? Tr.n('hint.extractionHere', Economy.extractionCost)
                  : Tr.n('hint.descendOrExtract', Economy.descentCost),
              style: Type.small,
            ),
          ),
        ],
      ),
    );
  }
}

class _EndScreen extends StatelessWidget {
  const _EndScreen({required this.run, required this.onRestart});

  final RunState run;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final dead = run.phase == RunPhase.dead;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(Space.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dead ? Tr.get('end.dead') : Tr.get('end.extracted'),
                style: Type.big.copyWith(
                  color: dead ? Palette.danger : Palette.good,
                ),
              ),
              const SizedBox(height: Space.m),
              Text(
                dead ? Tr.get('end.deadBody') : Tr.get('end.extractedBody'),
                style: Type.body.copyWith(color: Palette.dim),
              ),
              const SizedBox(height: Space.l),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(Tr.get('end.depth'), style: Type.small),
                  Text('${run.floor}', style: Type.title),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(Tr.get('hud.blocks'), style: Type.small),
                  Text('${run.blocksUsed}/${run.slots}', style: Type.title),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(Tr.get('hud.time'), style: Type.small),
                  Text('${run.budget}', style: Type.title),
                ],
              ),
              const SizedBox(height: Space.l),
              // Le replay de fin de run : toutes les traces sont déjà
              // en mémoire, il ne reste qu'à les rejouer à la suite.
              Text(
                '${Tr.get('end.replayAll')} — ${run.history.length}',
                style: Type.label,
              ),
              const SizedBox(height: Space.s),
              for (final h in run.history)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${Tr.get('hud.floor')} ${h.floor} · ${archetypeOf(h.floor)}',
                        style: Type.small,
                      ),
                      Text(
                        '${h.netCost >= 0 ? '−' : '+'}${h.netCost.abs()}',
                        style: Type.small.copyWith(
                          color: h.exec.success ? Palette.dim : Palette.danger,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: Space.xl),
              ActionButton(Tr.get('run.newRun'), onRestart, primary: true),
            ],
          ),
        ),
      ),
    );
  }
}
