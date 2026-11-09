/// TOUTE la direction artistique du jeu vit dans ce fichier.
///
/// Parti pris : **Nécropole** — dark fantasy, palette PICO-8 gothique,
/// violet nuit et lueur spectrale. Rien ici n'est structurant : un
/// autre DA se substitue sans toucher une ligne de gameplay.
///
/// ┌────────────────────────────────────────────────────────────────┐
/// │ OÙ REMPLACER QUOI                                              │
/// │                                                                │
/// │ Couleurs ......... le `_Scheme` `_necropolis`, une seule fois  │
/// │ Typo ............. `Type.family` + `fonts:` dans le pubspec    │
/// │ Dessin d'un sprite  `tools/gen_sprites.py`, puis relancer      │
/// │ Nouveau sprite ... idem + sa clé dans `SpriteSheet.keys`       │
/// │ Sons ............. `lib/ui/theme/audio.dart`                   │
/// │                                                                │
/// │ Les sprites manquants ou non conformes retombent sur le rendu  │
/// │ procédural des peintres plus bas : le jeu reste jouable sans   │
/// │ aucun asset, et un échec de chargement est listé dans la       │
/// │ galerie (bouton ▣) plutôt qu'avalé en silence.                 │
/// └────────────────────────────────────────────────────────────────┘
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../vm/room.dart';

// ══════════════════════════════════════════════════════════════════
// COULEURS — point de remplacement n°1
// ══════════════════════════════════════════════════════════════════

/// La direction artistique : **Nécropole**. Dark fantasy, palette
/// PICO-8 gothique, violet nuit et lueur spectrale.
///
/// Une seule couleur par signification — c'est ce qui rend la grille
/// lisible d'un coup d'œil sur un écran de 6 pouces. En particulier,
/// `accent` (le vert spectre) n'appartient QU'AU HÉROS et à
/// l'exécution : le donner à la sortie ou à un bonus ferait disparaître
/// le curseur d'exécution dans le décor.
///
/// Pour changer la DA : ce seul `_Scheme` suffit. Aucun autre fichier
/// ne connaît de couleur en dur.
class _Scheme {
  const _Scheme({
    required this.bg,
    required this.panel,
    required this.panelHi,
    required this.line,
    required this.ink,
    required this.dim,
    required this.faint,
    required this.accent,
    required this.gold,
    required this.danger,
    required this.good,
    required this.wall,
    required this.floor,
    required this.fogged,
    required this.leading,
  });

  final Color bg, panel, panelHi, line, ink, dim, faint;
  final Color accent, gold, danger, good;
  final Color wall, floor, fogged;

  /// Le cerne qui sépare deux cases.
  final Color leading;
}

const _necropolis = _Scheme(
  bg: Color(0xFF11061A),
  panel: Color(0xFF1A0C27),
  panelHi: Color(0xFF2A1B35),
  line: Color(0xFF4A3B52),
  ink: Color(0xFFD0C8D6),
  dim: Color(0xFF8B7D93),
  faint: Color(0xFF4A3B52),
  accent: Color(0xFF39FF14),
  gold: Color(0xFFFFB000),
  danger: Color(0xFFFF0055),
  good: Color(0xFF00E5FF),
  wall: Color(0xFF11061A),
  floor: Color(0xFF2A1B35),
  fogged: Color(0xFF0D0616),
  leading: Color(0xFF11061A),
);

class Palette {
  Palette._();

  static const _s = _necropolis;

  static Color get bg => _s.bg;
  static Color get panel => _s.panel;
  static Color get panelHi => _s.panelHi;
  static Color get line => _s.line;
  static Color get ink => _s.ink;
  static Color get dim => _s.dim;
  static Color get faint => _s.faint;
  static Color get accent => _s.accent;
  static Color get accentSoft => _s.accent.withValues(alpha: 0.14);
  static Color get gold => _s.gold;
  static Color get danger => _s.danger;
  static Color get good => _s.good;
  static Color get wall => _s.wall;
  static Color get floor => _s.floor;
  static Color get fogged => _s.fogged;
  static Color get leading => _s.leading;
}

// ══════════════════════════════════════════════════════════════════
// TYPO — point de remplacement n°2
// ══════════════════════════════════════════════════════════════════

class Type {
  Type._();

  /// Pour une vraie police : la déposer dans `assets/fonts/`, la
  /// déclarer dans `pubspec.yaml` sous `fonts:`, puis changer cette
  /// seule constante.
  static const String? family = null;

  static final mono = TextStyle(
    fontFamily: family,
    fontFamilyFallback: ['Menlo', 'Consolas', 'Courier New', 'monospace'],
    color: Palette.ink,
    fontSize: 13,
    height: 1.35,
  );

  static TextStyle get code => mono;
  static TextStyle get body => mono.copyWith(fontSize: 13);
  static TextStyle get small => mono.copyWith(fontSize: 11, color: Palette.dim);
  static TextStyle get label =>
      mono.copyWith(fontSize: 11, color: Palette.dim, letterSpacing: 1.2);
  static TextStyle get title =>
      mono.copyWith(fontSize: 15, fontWeight: FontWeight.w700);
  static TextStyle get big => mono.copyWith(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: 2,
  );
}

// ══════════════════════════════════════════════════════════════════
// SPRITES — point de remplacement n°3
// ══════════════════════════════════════════════════════════════════

/// Un sprite pixel art chargé depuis un SVG.
///
/// CONTRAT DU FORMAT — le SVG doit ne contenir QUE des `<rect>` alignés
/// sur des entiers, avec un `fill` hexadécimal. Pas de `<path>`, pas de
/// `<circle>`, pas de gradient, pas de transform. C'est exactement ce
/// que produit `tools/gen_sprites.py`.
///
/// Pourquoi parser nous-mêmes plutôt que rastériser : les rectangles
/// sont redessinés à la taille d'affichage, donc le rendu reste net à
/// n'importe quelle résolution, sans rééchantillonnage ni dépendance.
/// Un SVG non conforme est rejeté au chargement et le jeu retombe sur
/// le rendu procédural — jamais d'écran vide.
class PixelSprite {
  PixelSprite(this.size, this._rects);

  final int size;
  final List<_PixelRect> _rects;

  static final RegExp _rectTag = RegExp(r'<rect\s([^>]*?)/?>');
  static final RegExp _viewBox = RegExp(r'viewBox="0 0 (\d+) (\d+)"');

  static String? _attr(String tag, String name) =>
      RegExp('$name="([^"]*)"').firstMatch(tag)?.group(1);

  /// Renvoie null si le SVG ne respecte pas le contrat de format.
  static PixelSprite? parse(String svg) {
    final vb = _viewBox.firstMatch(svg);
    if (vb == null) return null;
    final size = int.tryParse(vb.group(1)!);
    if (size == null || size <= 0) return null;

    // Tout élément dessinant qui n'est pas un <rect> invalide le fichier.
    for (final forbidden in const [
      '<path',
      '<circle',
      '<ellipse',
      '<polygon',
      '<polyline',
      '<image',
      '<use',
      '<linearGradient',
    ]) {
      if (svg.contains(forbidden)) return null;
    }

    final rects = <_PixelRect>[];
    for (final m in _rectTag.allMatches(svg)) {
      final tag = m.group(1)!;
      final x = int.tryParse(_attr(tag, 'x') ?? '');
      final y = int.tryParse(_attr(tag, 'y') ?? '');
      final w = int.tryParse(_attr(tag, 'width') ?? '');
      final h = int.tryParse(_attr(tag, 'height') ?? '');
      final fill = _attr(tag, 'fill');
      if (x == null || y == null || w == null || h == null || fill == null) {
        return null;
      }
      final color = _parseHex(fill);
      if (color == null) return null;
      rects.add(_PixelRect(x, y, w, h, color));
    }
    return rects.isEmpty ? null : PixelSprite(size, rects);
  }

  static Color? _parseHex(String s) {
    if (!s.startsWith('#') || s.length != 7) return null;
    final v = int.tryParse(s.substring(1), radix: 16);
    return v == null ? null : Color(0xFF000000 | v);
  }

  /// Part de la case réellement peinte, entre 0 et 1. Sert à vérifier
  /// qu'un sprite de superposition ne masque pas la dalle sous lui.
  double get coverage {
    final painted = _rects.fold<int>(0, (sum, r) => sum + r.w * r.h);
    return painted / (size * size);
  }

  /// Les bords sont calculés en coordonnées absolues : deux pixels
  /// voisins partagent exactement une arête, donc aucune couture claire
  /// n'apparaît quand la case est agrandie.
  void paint(Canvas c, Rect dst, {double opacity = 1}) {
    final sx = dst.width / size;
    final sy = dst.height / size;
    final paint = Paint()..isAntiAlias = false;
    for (final r in _rects) {
      paint.color = opacity >= 1 ? r.color : r.color.withValues(alpha: opacity);
      c.drawRect(
        Rect.fromLTRB(
          dst.left + r.x * sx,
          dst.top + r.y * sy,
          dst.left + (r.x + r.w) * sx,
          dst.top + (r.y + r.h) * sy,
        ),
        paint,
      );
    }
  }
}

class _PixelRect {
  const _PixelRect(this.x, this.y, this.w, this.h, this.color);
  final int x, y, w, h;
  final Color color;
}

/// Registre des sprites. Tant qu'il est vide, tout est dessiné en
/// procédural : le jeu reste jouable sans aucun asset.
///
/// AJOUTER UN SPRITE : le définir dans `tools/gen_sprites.py`, relancer
/// le script, puis ajouter sa clé à `keys` ci-dessous. Rien d'autre.
class SpriteSheet {
  SpriteSheet._();

  static const List<String> keys = [
    // Cases
    'floor',
    'floor_rune',
    'wall',
    'wall_lichen',
    'spike',
    'pit',
    'exit',
    'corrupted',
    'door_locked',
    // Superpositions : fond transparent, dessinées par-dessus la dalle
    'item',
    'bonus',
    'mark',
    // Brouillard
    'fog',
    'fog_eyes',
    // Héros — E/S/O dérivées du nord par rotation dans le générateur
    'agent_n',
    'agent_e',
    'agent_s',
    'agent_w',
    // Décor animé du menu — cadences documentées dans ASSETS_TODO.md
    'bg_stone',
    'bg_sigil_1',
    'bg_sigil_2',
    'bg_sigil_3',
    'bg_torch_1',
    'bg_torch_2',
    'bg_torch_3',
    'bg_wisp_1',
    'bg_wisp_2',
    'bg_wisp_3',
    'bg_wisp_4',
    'bg_ember',
  ];

  static final Map<String, PixelSprite> _sprites = {};

  /// Les fichiers qui n'ont pas pu être chargés ou parsés. Affiché en
  /// debug plutôt que silencieusement ignoré : un asset qui ne
  /// s'affiche pas sans rien dire coûte des heures.
  static final List<String> failures = [];

  static bool get ready => _sprites.isNotEmpty;
  static int get loadedCount => _sprites.length;
  static PixelSprite? of(String key) => _sprites[key];

  static Future<void> load() async {
    for (final key in keys) {
      final path = 'assets/sprites/$key.svg';
      try {
        final sprite = PixelSprite.parse(await rootBundle.loadString(path));
        if (sprite == null) {
          failures.add('$path : format non conforme (voir PixelSprite)');
        } else {
          _sprites[key] = sprite;
        }
      } catch (_) {
        failures.add('$path : introuvable');
      }
    }
    if (failures.isNotEmpty && kDebugMode) {
      debugPrint('[sprites] ${failures.length} échec(s) :');
      for (final f in failures) {
        debugPrint('  $f');
      }
    }
  }
}

// ══════════════════════════════════════════════════════════════════
// PEINTRES — sprites si disponibles, procédural en repli
// ══════════════════════════════════════════════════════════════════

class TileArt {
  TileArt._();

  static void paint(Canvas c, Rect r, Tile tile, {required bool revealed}) {
    if (!revealed) {
      // Hors brouillard tout est révélé : un piège invisible dans une
      // salle éclairée n'existe pas.
      if (_blit(c, r, 'fog')) return;
      c.drawRect(r, Paint()..color = Palette.fogged);
      return;
    }

    if (_blit(c, r, _keyFor(tile))) return;

    switch (tile) {
      case Tile.wall:
        c.drawRect(r, Paint()..color = Palette.wall);
        c.drawRect(
          r,
          Paint()
            ..color = Palette.leading
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      case Tile.floor:
        c.drawRect(r, Paint()..color = Palette.floor);
        // Le cerne : c'est lui qui sépare les cases sans ambiguïté, et
        // c'est ce qui rend la grille lisible à petite taille.
        c.drawRect(
          r,
          Paint()
            ..color = Palette.leading
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      case Tile.spike:
        c.drawRect(r, Paint()..color = Palette.floor);
        final p = Paint()
          ..color = Palette.danger
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6;
        const n = 3;
        for (var i = 0; i < n; i++) {
          final x = r.left + r.width * (i + 0.5) / n;
          c.drawPath(
            Path()
              ..moveTo(x - r.width / 8, r.bottom - r.height * 0.22)
              ..lineTo(x, r.top + r.height * 0.26)
              ..lineTo(x + r.width / 8, r.bottom - r.height * 0.22),
            p,
          );
        }
      case Tile.pit:
        c.drawRect(r, Paint()..color = const Color(0xFF05070A));
        c.drawRect(
          r.deflate(2),
          Paint()
            ..color = Palette.danger.withValues(alpha: 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      case Tile.exitTile:
        c.drawRect(r, Paint()..color = Palette.good.withValues(alpha: 0.16));
        c.drawRect(
          r.deflate(2),
          Paint()
            ..color = Palette.good
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
    }
  }

  static void paintItem(Canvas c, Rect r) {
    if (_blit(c, r, 'item')) return;
    final cx = r.center;
    c.drawPath(
      Path()
        ..moveTo(cx.dx, r.top + r.height * 0.28)
        ..lineTo(r.right - r.width * 0.28, cx.dy)
        ..lineTo(cx.dx, r.bottom - r.height * 0.28)
        ..lineTo(r.left + r.width * 0.28, cx.dy)
        ..close(),
      Paint()..color = Palette.gold,
    );
  }

  static void paintBonus(Canvas c, Rect r) {
    if (_blit(c, r, 'bonus')) return;
    c.drawCircle(
      r.center,
      r.width * 0.19,
      Paint()
        ..color = Palette.gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  static void paintMark(Canvas c, Rect r) {
    if (_blit(c, r, 'mark')) return;
    c.drawCircle(r.center, r.width * 0.1, Paint()..color = Palette.accent);
  }

  static void paintAgent(Canvas c, Rect r, Dir dir) {
    if (_blit(c, r, 'agent_${dir.name[0]}')) return;
    final cx = r.center;
    final s = r.width * 0.3;
    final path = Path();
    switch (dir) {
      case Dir.north:
        path
          ..moveTo(cx.dx, cx.dy - s)
          ..lineTo(cx.dx + s, cx.dy + s)
          ..lineTo(cx.dx - s, cx.dy + s);
      case Dir.south:
        path
          ..moveTo(cx.dx, cx.dy + s)
          ..lineTo(cx.dx + s, cx.dy - s)
          ..lineTo(cx.dx - s, cx.dy - s);
      case Dir.east:
        path
          ..moveTo(cx.dx + s, cx.dy)
          ..lineTo(cx.dx - s, cx.dy + s)
          ..lineTo(cx.dx - s, cx.dy - s);
      case Dir.west:
        path
          ..moveTo(cx.dx - s, cx.dy)
          ..lineTo(cx.dx + s, cx.dy + s)
          ..lineTo(cx.dx + s, cx.dy - s);
    }
    path.close();
    c.drawPath(path, Paint()..color = Palette.accent);
  }

  static String _keyFor(Tile t) => switch (t) {
    Tile.floor => 'floor',
    Tile.wall => 'wall',
    Tile.spike => 'spike',
    Tile.pit => 'pit',
    Tile.exitTile => 'exit',
  };

  /// Renvoie false si le sprite n'existe pas : l'appelant retombe alors
  /// sur le rendu procédural.
  static bool _blit(Canvas c, Rect dst, String key) {
    final sprite = SpriteSheet.of(key);
    if (sprite == null) return false;
    sprite.paint(c, dst);
    return true;
  }
}

/// Espacements. Une seule échelle pour tout le jeu.
class Space {
  Space._();
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
  static const radius = 4.0;
}
