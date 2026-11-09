/// L'écran-titre et son décor animé.
///
/// Le menu n'a pas besoin d'une scène : il a besoin d'être VIVANT.
/// Quatre couches suffisent, de la plus lente à la plus rapide, et
/// toutes sont pilotées par un seul `AnimationController` — chaque
/// couche calcule son image à partir du temps écoulé plutôt que
/// d'avoir sa propre horloge.
///
///   1. le mur de pierre, tuilé, immobile
///   2. le sceau qui respire derrière le titre  (~2,4 s le cycle)
///   3. les torches qui vacillent               (~0,14 s par image)
///   4. les volutes et les braises qui montent  (~0,2 s)
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../i18n/strings.dart';
import '../theme/art.dart';
import '../theme/audio.dart';

/// Une particule du décor. Position et vitesse sont tirées UNE fois,
/// à la construction : le décor doit être stable, pas scintillant.
class _Mote {
  const _Mote(this.x, this.speed, this.phase, this.size, this.sway);
  final double x;
  final double speed;
  final double phase;
  final double size;
  final double sway;

  /// `band` non nul : les particules restent dans les marges
  /// latérales, hors de la colonne de texte.
  static List<_Mote> spawn(
    int n,
    int seed,
    double minSize,
    double maxSize, {
    double? band,
  }) {
    final rng = math.Random(seed);
    return List.generate(n, (i) {
      return _Mote(
        band == null
            ? rng.nextDouble()
            : (i.isEven
                  ? band + rng.nextDouble() * 0.18
                  : 1 - band - rng.nextDouble() * 0.18),
        0.02 + rng.nextDouble() * 0.05,
        rng.nextDouble(),
        minSize + rng.nextDouble() * (maxSize - minSize),
        4 + rng.nextDouble() * 18,
      );
    });
  }
}

class MainMenu extends StatefulWidget {
  const MainMenu({super.key, required this.onStart, required this.onGallery});

  final VoidCallback onStart;
  final VoidCallback onGallery;

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock;
  late final List<_Mote> _embers;
  late final List<_Mote> _wisps;

  @override
  void initState() {
    super.initState();
    // Une seule horloge de 24 s : assez longue pour que la boucle ne
    // s'entende pas, et tous les cycles s'y raccrochent par modulo.
    _clock = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();
    _embers = _Mote.spawn(22, 7, 6, 14);
    _wisps = _Mote.spawn(6, 31, 20, 34, band: 0.06);
    Music.play(MusicTrack.menu);
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Palette.bg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _clock,
            builder: (context, _) => CustomPaint(
              painter: _MenuBackdrop(
                t: _clock.value * 24,
                embers: _embers,
                wisps: _wisps,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(Space.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(flex: 4),
                  FittedBox(
                    child: Text(
                      Tr.get('app.title'),
                      style: Type.big.copyWith(
                        fontSize: 40,
                        letterSpacing: 10,
                        color: Palette.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.m),
                  Text(
                    Tr.get('app.tagline'),
                    style: Type.small,
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(flex: 2),
                  _MenuButton(
                    label: Tr.get('menu.start'),
                    onTap: () {
                      Sfx.play(SfxEvent.descend);
                      widget.onStart();
                    },
                    primary: true,
                  ),
                  const SizedBox(height: Space.m),
                  _MenuButton(
                    label: Tr.get('menu.gallery'),
                    onTap: widget.onGallery,
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [_Chip(Tr.get('lang.switch'), Tr.toggle)],
                  ),
                  const SizedBox(height: Space.s),
                  Text(Tr.get('menu.proto'), style: Type.small),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuBackdrop extends CustomPainter {
  _MenuBackdrop({required this.t, required this.embers, required this.wisps});

  final double t;
  final List<_Mote> embers;
  final List<_Mote> wisps;

  /// Une image de sprite parmi n, choisie par le temps.
  static int _frame(double t, double period, int n) =>
      ((t / period).floor()) % n;

  @override
  void paint(Canvas canvas, Size size) {
    _wall(canvas, size);
    _sigil(canvas, size);
    _torches(canvas, size);
    _wispLayer(canvas, size);
    _emberLayer(canvas, size);
    _vignette(canvas, size);
  }

  // 1. Le mur : immobile, il ne doit jamais attirer l'œil.
  void _wall(Canvas canvas, Size size) {
    final sprite = SpriteSheet.of('bg_stone');
    if (sprite == null) return;
    const tile = 72.0;
    for (var y = 0.0; y < size.height; y += tile) {
      for (var x = 0.0; x < size.width; x += tile) {
        sprite.paint(canvas, Rect.fromLTWH(x, y, tile, tile), opacity: 0.55);
      }
    }
  }

  // 2. Le sceau : trois intensités, il respire derrière le titre.
  void _sigil(Canvas canvas, Size size) {
    final n = _frame(t, 0.8, 3);
    final sprite = SpriteSheet.of(
      'bg_sigil_${[1, 2, 3, 2].elementAt(((t / 0.8).floor()) % 4)}',
    );
    if (sprite == null) return;
    final side = size.shortestSide * 0.52;
    // Une très légère respiration d'échelle, en plus de l'intensité.
    final breathe = 1 + 0.02 * math.sin(t * 1.4);
    final r = Rect.fromCenter(
      // Le sceau dégage entièrement le titre : il le surplombe,
      // il ne le traverse pas.
      center: Offset(size.width / 2, size.height * 0.24),
      width: side * breathe,
      height: side * breathe,
    );
    sprite.paint(canvas, r, opacity: 0.11 + 0.05 * n);
  }

  // 3. Les torches : le vacillement vient de la flamme, jamais du
  // support — sinon la torche « saute ». Les deux sont déphasées.
  void _torches(Canvas canvas, Size size) {
    const side = 88.0;
    final y = size.height * 0.20;
    for (final (i, x) in [size.width * 0.13, size.width * 0.87].indexed) {
      final sprite = SpriteSheet.of(
        'bg_torch_${1 + _frame(t + i * 0.07, 0.14, 3)}',
      );
      if (sprite == null) continue;
      sprite.paint(
        canvas,
        Rect.fromCenter(center: Offset(x, y), width: side, height: side),
        opacity: 0.9,
      );
    }
  }

  // 4a. Les volutes : dérive lente vers le haut + cycle d'images.
  void _wispLayer(Canvas canvas, Size size) {
    for (final (i, m) in wisps.indexed) {
      final sprite = SpriteSheet.of(
        'bg_wisp_${1 + _frame(t + m.phase, 0.2, 4)}',
      );
      if (sprite == null) continue;
      final prog = (m.phase + t * m.speed * 0.4) % 1.0;
      final y = size.height * (1.05 - prog * 1.1);
      final x = size.width * m.x + math.sin(t * 0.5 + i) * m.sway;
      // Les extrémités du trajet s'estompent : rien n'apparaît ni ne
      // disparaît brutalement.
      final fade = math.sin(prog * math.pi).clamp(0.0, 1.0);
      sprite.paint(
        canvas,
        Rect.fromCenter(center: Offset(x, y), width: m.size, height: m.size),
        opacity: 0.45 * fade,
      );
    }
  }

  // 4b. Les braises : UNE seule image. C'est le déplacement qui anime.
  void _emberLayer(Canvas canvas, Size size) {
    final sprite = SpriteSheet.of('bg_ember');
    if (sprite == null) return;
    for (final (i, m) in embers.indexed) {
      final prog = (m.phase + t * m.speed) % 1.0;
      final y = size.height * (1.02 - prog * 1.06);
      final x = size.width * m.x + math.sin(t * 1.1 + i * 2.3) * m.sway;
      final fade = math.sin(prog * math.pi).clamp(0.0, 1.0);
      sprite.paint(
        canvas,
        Rect.fromCenter(center: Offset(x, y), width: m.size, height: m.size),
        opacity: 0.8 * fade,
      );
    }
  }

  // Vignette : ramène l'œil au centre, où vit le titre.
  void _vignette(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.95,
          colors: [Colors.transparent, Palette.bg],
          stops: const [0.45, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_MenuBackdrop old) => old.t != t;
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final c = primary ? Palette.accent : Palette.dim;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Space.radius),
      child: Container(
        width: 260,
        padding: const EdgeInsets.symmetric(vertical: Space.m),
        decoration: BoxDecoration(
          color: primary
              ? Palette.accentSoft
              : Palette.panel.withValues(alpha: 0.8),
          border: Border.all(color: c, width: primary ? 1.6 : 1),
          borderRadius: BorderRadius.circular(Space.radius),
        ),
        child: Center(
          child: Text(
            label,
            style: Type.code.copyWith(
              color: c,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(Space.radius),
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.s,
        vertical: Space.xs,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: Palette.line),
        borderRadius: BorderRadius.circular(Space.radius),
      ),
      child: Text(label, style: Type.small),
    ),
  );
}
