/// LE MONDE. Zone invariante : jamais recouverte, sur aucun format.
library;

import 'package:flutter/material.dart';

import '../../vm/room.dart';
import '../../vm/trace.dart';
import '../theme/art.dart';

class WorldView extends StatelessWidget {
  const WorldView({super.key, required this.room, required this.frame});

  final Room room;
  final Frame? frame;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final cell = (box.maxWidth / room.width).clamp(
          0.0,
          box.maxHeight / room.height,
        );
        final w = cell * room.width;
        final h = cell * room.height;
        return Center(
          child: SizedBox(
            width: w,
            height: h,
            child: CustomPaint(
              painter: _WorldPainter(room: room, frame: frame, cell: cell),
            ),
          ),
        );
      },
    );
  }
}

class _WorldPainter extends CustomPainter {
  _WorldPainter({required this.room, required this.frame, required this.cell});

  final Room room;
  final Frame? frame;
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    final f = frame;
    final collected = f?.collected ?? const <int>{};
    final revealedSet = f?.revealed ?? const <int>{};

    for (var y = 0; y < room.height; y++) {
      for (var x = 0; x < room.width; x++) {
        final i = room.idx(x, y);
        final rect = Rect.fromLTWH(x * cell, y * cell, cell, cell);
        // Hors brouillard, tout est révélé : un piège invisible dans une
        // salle éclairée n'existe pas.
        final revealed = !room.fog || revealedSet.contains(i);
        TileArt.paint(canvas, rect, room.tiles[i], revealed: revealed);
        if (!revealed) continue;

        if (room.bonuses.contains(i) && !collected.contains(i)) {
          TileArt.paintBonus(canvas, rect);
        }
        if (room.items.contains(i) && !collected.contains(i)) {
          TileArt.paintItem(canvas, rect);
        }
        if (f != null && f.marks.contains(i)) {
          TileArt.paintMark(canvas, rect);
        }
      }
    }

    // Hors exécution, l'agent est dessiné à sa position de départ :
    // le joueur doit voir d'où il part AVANT d'écrire son bloc.
    final ax = f?.x ?? room.startX;
    final ay = f?.y ?? room.startY;
    final adir = f?.dir ?? room.startDir;
    {
      final rect = Rect.fromLTWH(ax * cell, ay * cell, cell, cell);
      // Le moment de l'échec, figé et surligné : on met en évidence la
      // case où ça a mal tourné.
      if (f != null &&
          (f.event == FrameEvent.hazardSpike ||
              f.event == FrameEvent.hazardPit)) {
        canvas.drawRect(
          rect,
          Paint()..color = Palette.danger.withValues(alpha: 0.45),
        );
      }
      TileArt.paintAgent(canvas, rect, adir);
    }

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..color = Palette.line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_WorldPainter old) =>
      old.frame != frame || old.room != room || old.cell != cell;
}
