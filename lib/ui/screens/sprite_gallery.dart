/// Galerie de sprites — OUTIL DE DÉVELOPPEMENT.
///
/// Affiche tous les sprites chargés, agrandis, sur un damier qui rend
/// la transparence visible. Sert à juger le pixel art à la bonne
/// échelle plutôt que dans un explorateur de fichiers.
///
/// Accessible par le bouton ▣ de l'en-tête. À retirer avant une vraie
/// release, ou à garder derrière un flag de debug.
library;

import 'package:flutter/material.dart';

import '../theme/art.dart';

class SpriteGallery extends StatelessWidget {
  const SpriteGallery({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Palette.bg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(Space.m),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'SPRITES — ${SpriteSheet.keys.length} déclarés, '
                      '${SpriteSheet.loadedCount} chargés',
                      style: Type.label,
                    ),
                  ),
                  InkWell(
                    onTap: onClose,
                    child: Icon(Icons.close, color: Palette.dim),
                  ),
                ],
              ),
            ),
            if (SpriteSheet.failures.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.m),
                child: Text(
                  SpriteSheet.failures.join('\n'),
                  style: Type.small.copyWith(color: Palette.danger),
                ),
              ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(Space.m),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 86,
                  mainAxisSpacing: Space.m,
                  crossAxisSpacing: Space.m,
                  childAspectRatio: 0.82,
                ),
                itemCount: SpriteSheet.keys.length,
                itemBuilder: (context, i) {
                  final key = SpriteSheet.keys[i];
                  return Column(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Palette.line),
                          ),
                          child: CustomPaint(
                            painter: _SpritePainter(key),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                      const SizedBox(height: Space.xs),
                      Text(
                        key,
                        style: Type.small.copyWith(fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpritePainter extends CustomPainter {
  _SpritePainter(this.spriteKey);
  final String spriteKey;

  @override
  void paint(Canvas canvas, Size size) {
    // Damier : rend la transparence des overlays visible d'un coup d'œil.
    const n = 8;
    final cell = size.width / n;
    final a = Paint()..color = const Color(0xFF15151A);
    final b = Paint()..color = const Color(0xFF0C0C10);
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        canvas.drawRect(
          Rect.fromLTWH(x * cell, y * cell, cell, cell),
          (x + y).isEven ? a : b,
        );
      }
    }
    final sprite = SpriteSheet.of(spriteKey);
    if (sprite == null) {
      canvas.drawLine(
        Offset.zero,
        Offset(size.width, size.height),
        Paint()..color = Palette.danger,
      );
      canvas.drawLine(
        Offset(size.width, 0),
        Offset(0, size.height),
        Paint()..color = Palette.danger,
      );
      return;
    }
    final side = size.shortestSide;
    sprite.paint(
      canvas,
      Rect.fromLTWH(
        (size.width - side) / 2,
        (size.height - side) / 2,
        side,
        side,
      ),
    );
  }

  @override
  bool shouldRepaint(_SpritePainter old) => old.spriteKey != spriteKey;
}
