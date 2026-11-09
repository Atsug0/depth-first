import 'package:depth_first/i18n/strings.dart';
import 'package:depth_first/main.dart';
import 'package:depth_first/ui/widgets/world_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le jeu s'ouvre sur le menu : les tests de jeu doivent le traverser.
Future<void> _enterGame(WidgetTester tester) async {
  await tester.tap(find.text('DESCENDRE'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => Tr.locale.value = AppLocale.fr);

  testWidgets('le jeu ouvre sur le menu animé', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const DepthFirstApp());
    await tester.pump();

    expect(find.text('DESCENDRE'), findsOneWidget);
    expect(
      find.byType(WorldView),
      findsNothing,
      reason: 'le jeu ne démarre pas avant que le joueur ne descende',
    );

    await _enterGame(tester);
    expect(find.byType(WorldView), findsOneWidget);
  });

  testWidgets('le jeu démarre et affiche le monde', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const DepthFirstApp());
    await tester.pump();
    await _enterGame(tester);

    expect(find.text('DEPTH FIRST'), findsOneWidget);
    expect(find.byType(WorldView), findsOneWidget);
    expect(find.text('LE PROGRAMME'), findsOneWidget);
  });

  testWidgets('la langue bascule à chaud', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const DepthFirstApp());
    await tester.pump();
    await _enterGame(tester);

    expect(find.text('LE PROGRAMME'), findsOneWidget);
    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();
    expect(find.text('THE PROGRAM'), findsOneWidget);
    expect(find.text('LE PROGRAMME'), findsNothing);
  });

  testWidgets('composer un bloc puis le lancer produit une exécution', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const DepthFirstApp());
    await tester.pump();
    await _enterGame(tester);

    // LANCER est désactivé tant que le bloc est vide.
    expect(find.text('LANCER'), findsOneWidget);

    // Les actions sont dans leur onglet depuis l'éclatement de la
    // palette.
    await tester.tap(find.text('ACTIONS').first);
    await tester.pump();
    await tester.tap(find.text('AVANCER').first);
    await tester.pump();
    await tester.tap(find.text('LANCER'));
    await tester.pump();

    // L'exécution a démarré : la timeline a remplacé le bouton.
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('le layout mobile garde monde et bloc courant visibles', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const DepthFirstApp());
    await tester.pump();
    await _enterGame(tester);

    // Les deux zones invariantes sont là. Le monde n'a plus d'étiquette
    // ni de cadre : il EST le fond, pas un panneau parmi d'autres.
    expect(find.byType(WorldView), findsOneWidget);
    expect(find.text('PILE'), findsOneWidget);
    // La palette est éclatée en trois onglets, au même niveau que la
    // pile : atteindre une action ne demande qu'un seul geste.
    expect(find.text('GARDES'), findsOneWidget);
    expect(find.text('ACTIONS'), findsOneWidget);
    expect(find.text('CONTRÔLE'), findsOneWidget);
  });

  testWidgets("l'agent est visible avant toute exécution", (tester) async {
    // Régression : le peintre ne dessinait l'agent que s'il existait
    // une trace, donc le joueur ne voyait pas d'où il partait tant
    // qu'il n'avait pas lancé — alors que c'est exactement ce qu'il
    // doit savoir pour écrire son premier bloc.
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const DepthFirstApp());
    await tester.pump();
    await _enterGame(tester);

    final view = tester.widget<WorldView>(find.byType(WorldView));
    expect(view.frame, isNull, reason: 'aucune exécution lancée');
    expect(view.room.startX, greaterThanOrEqualTo(0));
    expect(
      view.room.isSafe(view.room.startX, view.room.startY),
      isTrue,
      reason: 'le départ doit être une case praticable',
    );
  });
}
