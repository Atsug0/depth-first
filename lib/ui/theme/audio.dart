/// Crochets de sound design. AUCUN son n'est joué pour l'instant :
/// chaque appel est un no-op tracé, pour que brancher l'audio plus tard
/// ne demande AUCUNE modification du gameplay.
///
/// ┌────────────────────────────────────────────────────────────────┐
/// │ POUR BRANCHER LE SON                                           │
/// │  1. ajouter `audioplayers` (ou équivalent) au pubspec           │
/// │  2. déposer les fichiers dans `assets/audio/` aux noms ci-bas   │
/// │  3. remplacer le corps de `Sfx._emit` et `Music.play`           │
/// │ Rien d'autre à toucher : tous les points d'appel sont déjà      │
/// │ posés dans le code de jeu.                                      │
/// └────────────────────────────────────────────────────────────────┘
library;

import 'package:flutter/foundation.dart';

/// Chaque valeur correspond à un fichier attendu dans `assets/audio/`.
/// La liste complète est reprise dans ASSETS_TODO.md.
enum SfxEvent {
  uiTap('ui_tap'),
  uiBack('ui_back'),
  blockAdd('block_add'),
  blockFreeze('block_freeze'),
  runStart('run_start'),
  step('step'),
  turn('turn'),
  pickUp('pick_up'),
  bonus('bonus'),
  scan('scan'),
  mark('mark'),
  jump('jump'),
  dispatch('dispatch'),
  hazardSpike('hazard_spike'),
  hazardPit('hazard_pit'),
  cycleLimit('cycle_limit'),
  blocked('blocked'),
  roomSolved('room_solved'),
  descend('descend'),
  extract('extract'),
  runDead('run_dead');

  const SfxEvent(this.asset);

  /// Nom de fichier attendu, sans extension.
  final String asset;
}

class Sfx {
  Sfx._();

  static bool enabled = true;
  static bool logToConsole = false;

  static void play(SfxEvent e) {
    if (!enabled) return;
    _emit(e);
  }

  /// POINT DE REMPLACEMENT : brancher le lecteur audio ici.
  static void _emit(SfxEvent e) {
    if (logToConsole && kDebugMode) {
      debugPrint('[sfx] ${e.asset}');
    }
  }
}

enum MusicTrack {
  menu('menu_loop'),
  surface('surface_loop'),
  descent('descent_loop'),
  deep('deep_loop'),
  extraction('extraction_loop');

  const MusicTrack(this.asset);
  final String asset;
}

class Music {
  Music._();

  static MusicTrack? current;

  /// POINT DE REMPLACEMENT : brancher la musique ici, avec un fondu.
  static void play(MusicTrack t) {
    current = t;
  }

  static void stop() => current = null;
}
