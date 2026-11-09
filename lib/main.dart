/// DEPTH FIRST — prototype.
///
/// Parcours en profondeur d'abord : l'algorithme, et la descente.
///
/// Trois piliers portent tout le design, et rien ne doit être ajouté
/// qui n'en serve un :
///   1. APPEND-ONLY — les blocs écrits sont gelés et continuent de
///      s'évaluer : dette technique à intérêts composés
///   2. LE TEMPS EST LA MONNAIE UNIQUE — jamais de points de vie
///   3. EXTRACTION À RISQUE — le retour est un coût à prépayer
library;

import 'package:flutter/material.dart';

import 'i18n/strings.dart';
import 'ui/screens/game_screen.dart';
import 'ui/screens/main_menu.dart';
import 'ui/screens/sprite_gallery.dart';
import 'ui/theme/art.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Les sprites sont chargés une fois pour toutes. S'ils manquent, le
  // jeu démarre quand même en rendu procédural — voir SpriteSheet.
  await SpriteSheet.load();
  runApp(const DepthFirstApp());
}

class DepthFirstApp extends StatelessWidget {
  const DepthFirstApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Le changement de langue reconstruit tout l'arbre : il suffit de
    // basculer `Tr.locale` depuis n'importe où.
    return ValueListenableBuilder<AppLocale>(
      valueListenable: Tr.locale,
      builder: (context, locale, _) => MaterialApp(
        title: Tr.get('app.title'),
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: Palette.bg,
          colorScheme: ColorScheme.dark(
            surface: Palette.panel,
            primary: Palette.accent,
            error: Palette.danger,
          ),
          textTheme: TextTheme(
            bodyMedium: Type.body,
            bodySmall: Type.small,
            titleMedium: Type.title,
          ),
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
        ),
        // PAS de `const` : un widget const est canonicalisé, et Flutter
        // court-circuiterait le rebuild au changement de langue.
        // ignore: prefer_const_constructors
        home: _Shell(),
      ),
    );
  }
}

class _Shell extends StatefulWidget {
  const _Shell();

  @override
  State<_Shell> createState() => _ShellState();
}

/// Les trois écrans du prototype. La galerie est un outil de
/// développement, pas une destination de jeu.
enum _Route { menu, game, gallery }

class _ShellState extends State<_Shell> {
  _Route route = _Route.menu;
  _Route back = _Route.menu;

  void _go(_Route r) => setState(() {
    if (r == _Route.gallery) back = route;
    route = r;
  });

  @override
  Widget build(BuildContext context) {
    if (route == _Route.gallery) {
      return Scaffold(body: SpriteGallery(onClose: () => _go(back)));
    }
    if (route == _Route.menu) {
      return Scaffold(
        body: MainMenu(
          onStart: () => _go(_Route.game),
          onGallery: () => _go(_Route.gallery),
        ),
      );
    }
    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.m, Space.s, Space.m, 0),
              child: LayoutBuilder(
                builder: (context, box) {
                  // Sous cette largeur le tagline était tronqué et
                  // poussait les boutons hors de l'écran : on le retire.
                  final roomForTagline = box.maxWidth >= 520;
                  return Row(
                    children: [
                      // Flexible : l'en-tête porte jusqu'à trois
                      // boutons, le titre doit pouvoir céder.
                      Flexible(
                        child: Text(
                          Tr.get('app.title'),
                          style: Type.title.copyWith(letterSpacing: 3),
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                      ),
                      if (roomForTagline) ...[
                        const SizedBox(width: Space.m),
                        Expanded(
                          child: Text(
                            Tr.get('app.tagline'),
                            style: Type.small,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ] else
                        const Spacer(),
                      // Outil de dev : galerie de sprites.
                      _HeaderButton(
                        label: '\u2190',
                        onTap: () => _go(_Route.menu),
                      ),
                      const SizedBox(width: Space.xs),
                      _HeaderButton(
                        label: '\u25A3',
                        onTap: () => _go(_Route.gallery),
                      ),

                      const SizedBox(width: Space.xs),
                      // Bascule de langue : FR ⇄ EN, à chaud.
                      _HeaderButton(
                        label: Tr.get('lang.switch'),
                        onTap: Tr.toggle,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          Expanded(child: GameScreen()),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.label, required this.onTap});

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
