import 'package:depth_first/ui/theme/art.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PixelSprite', () {
    test('parse un SVG conforme', () {
      final s = PixelSprite.parse('''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" shape-rendering="crispEdges">
  <rect x="0" y="0" width="16" height="1" fill="#1A0C27"/>
  <rect x="3" y="2" width="1" height="1" fill="#FF0055"/>
</svg>''');
      expect(s, isNotNull);
      expect(s!.size, 16);
    });

    test('rejette un SVG contenant une courbe', () {
      final s = PixelSprite.parse('''
<svg viewBox="0 0 16 16"><path d="M0 0L4 4"/></svg>''');
      expect(s, isNull, reason: 'un <path> doit invalider le fichier');
    });

    test('rejette un SVG sans viewBox', () {
      expect(
        PixelSprite.parse(
          '<svg><rect x="0" y="0" '
          'width="1" height="1" fill="#FFFFFF"/></svg>',
        ),
        isNull,
      );
    });

    test('rejette des coordonnées non entières', () {
      expect(
        PixelSprite.parse(
          '<svg viewBox="0 0 16 16">'
          '<rect x="0.5" y="0" width="1" height="1" fill="#FFFFFF"/></svg>',
        ),
        isNull,
        reason: 'le pixel art exige un alignement entier strict',
      );
    });
  });

  group('Assets', () {
    test('chaque clé déclarée a bien son fichier SVG conforme', () async {
      final manquants = <String>[];
      for (final key in SpriteSheet.keys) {
        final path = 'assets/sprites/$key.svg';
        try {
          final svg = await rootBundle.loadString(path);
          if (PixelSprite.parse(svg) == null) {
            manquants.add('$path : non conforme');
          }
        } catch (_) {
          manquants.add('$path : introuvable');
        }
      }
      expect(manquants, isEmpty);
    });

    test('les sprites de superposition sont sur fond transparent', () async {
      // item, bonus et mark se dessinent PAR-DESSUS le sol : s'ils
      // portaient un fond, ils masqueraient la dalle.
      for (final key in ['item', 'bonus', 'mark']) {
        final svg = await rootBundle.loadString('assets/sprites/$key.svg');
        final sprite = PixelSprite.parse(svg)!;
        expect(
          sprite.coverage,
          lessThan(0.5),
          reason: '$key couvre trop de surface pour un overlay',
        );
      }
    });
  });
}
