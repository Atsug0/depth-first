/// Le fond : on est DANS le donjon, pas devant un tableau de bord.
///
/// Le premier prototype empilait des panneaux bordés — « boîte boîte
/// boîte ». Chaque cadre ajoutait une frontière que rien ne justifiait
/// et le tout jurait avec la nécromancie.
///
/// Parti pris : une seule surface continue. Le mur de pierre couvre
/// tout l'écran, une vignette ramène l'œil au centre, et l'interface
/// ne pose plus de cadres mais des VOILES — de la pierre assombrie
/// sur laquelle on a gravé. Une seule ligne de contour, jamais quatre.
library;

import 'package:flutter/material.dart';

import '../theme/art.dart';

class DungeonBackdrop extends StatelessWidget {
  const DungeonBackdrop({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _BackdropPainter(), child: child);
}

class _BackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Palette.bg);

    final stone = SpriteSheet.of('bg_stone');
    if (stone != null) {
      const tile = 96.0;
      for (var y = 0.0; y < size.height; y += tile) {
        for (var x = 0.0; x < size.width; x += tile) {
          stone.paint(canvas, Rect.fromLTWH(x, y, tile, tile), opacity: 0.5);
        }
      }
    }

    // Vignette : le donjon est éclairé au centre, pas aux bords.
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.9,
          colors: [Colors.transparent, Palette.bg],
          stops: const [0.4, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => false;
}

/// Un voile de pierre assombrie. Remplace les panneaux bordés : une
/// seule arête haute, pas de cadre fermé, pas d'angles arrondis.
class Scrim extends StatelessWidget {
  const Scrim({
    super.key,
    required this.child,
    this.label,
    this.trailing,
    this.glow = false,
    this.padding = const EdgeInsets.all(Space.m),
  });

  final Widget child;
  final String? label;
  final Widget? trailing;

  /// Une lueur spectrale sur l'arête : réservée à ce qui est actif.
  final bool glow;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Palette.bg.withValues(alpha: 0.78),
        border: Border(
          top: BorderSide(
            color: glow ? Palette.accent : Palette.line,
            width: glow ? 1.4 : 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (label != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.m, Space.s, Space.m, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label!,
                      style: Type.label.copyWith(
                        letterSpacing: 2.5,
                        color: glow ? Palette.accent : Palette.dim,
                      ),
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
          Expanded(
            child: Padding(padding: padding, child: child),
          ),
        ],
      ),
    );
  }
}

/// La jauge de temps : un filet de lumière spectrale, pas un cadre
/// avec un chiffre dedans.
class SpectralGauge extends StatelessWidget {
  const SpectralGauge({super.key, required this.ratio, required this.low});

  final double ratio;
  final bool low;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 2,
    child: Stack(
      children: [
        Container(color: Palette.line.withValues(alpha: 0.5)),
        FractionallySizedBox(
          widthFactor: ratio.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              color: low ? Palette.danger : Palette.accent,
              boxShadow: [
                BoxShadow(
                  color: (low ? Palette.danger : Palette.accent).withValues(
                    alpha: 0.55,
                  ),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
