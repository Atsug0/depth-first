import 'package:depth_first/i18n/strings.dart';
import 'package:depth_first/main.dart';
import 'package:depth_first/vm/ast.dart';
import 'package:depth_first/ui/widgets/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _enterGame(WidgetTester tester) async {
  await tester.tap(find.text('DESCENDRE'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => Tr.locale.value = AppLocale.fr);

  group("Le modèle d'édition", () {
    test('la garde par défaut est vide, donc « toujours »', () {
      final d = BlockDraft();
      expect(d.guard.isAlways, isTrue);
      expect(d.guard.terms, isEmpty);
    });

    test('ajouter puis retirer une garde revient à « toujours »', () {
      final d = BlockDraft()..addGuardTerm(GuardKind.wallAhead);
      expect(d.guard.terms.length, 1);
      d.removeGuardTerm(0);
      expect(
        d.guard.isAlways,
        isTrue,
        reason: 'retirer le dernier terme rend la garde inconditionnelle',
      );
    });

    test('NON s\'arme avant le terme et se consomme après', () {
      final d = BlockDraft()..toggleNot();
      expect(d.pendingNot, isTrue);
      d.addGuardTerm(GuardKind.floorAhead);
      expect(d.guard.terms.single.negated, isTrue);
      expect(d.pendingNot, isFalse, reason: 'NON ne colle pas au suivant');
    });

    test('une ligne imbriquée se supprime individuellement', () {
      final d = BlockDraft()
        ..openWhile(Guard.of(GuardKind.floorAhead))
        ..addAction(ActionKind.forward)
        ..addAction(ActionKind.turnRight);
      final loop = d.body.single as WhileStmt;
      expect(loop.body.length, 2);
      d.removeStmt(loop.body.first);
      expect(loop.body.length, 1);
      expect((loop.body.single as ActionStmt).kind, ActionKind.turnRight);
    });

    test(
      'supprimer la boucle où l\'on écrit ramène le curseur à la racine',
      () {
        final d = BlockDraft()
          ..openWhile(Guard.of(GuardKind.floorAhead))
          ..addAction(ActionKind.forward);
        expect(d.depth, 1);
        d.removeStmt(d.body.single);
        expect(
          d.depth,
          0,
          reason: 'le curseur ne doit jamais pointer dans le vide',
        );
        // Et on peut continuer à écrire sans crasher.
        d.addAction(ActionKind.wait);
        expect(d.body.length, 1);
      },
    );

    test('le curseur pointe la liste où atterrira la prochaine action', () {
      final d = BlockDraft();
      expect(identical(d.focusedList, d.body), isTrue);
      d.openWhile(Guard.of(GuardKind.floorAhead));
      expect(
        identical(d.focusedList, (d.body.single as WhileStmt).body),
        isTrue,
      );
      d.closeNesting();
      expect(identical(d.focusedList, d.body), isTrue);
    });

    test('SINON bascule vers la branche fausse du SI courant', () {
      final d = BlockDraft()..openIf(Guard.of(GuardKind.wallAhead));
      expect(d.canElse, isTrue);
      d.addAction(ActionKind.turnRight);
      d.openElse();
      expect(d.canElse, isFalse, reason: 'on est déjà dans le SINON');
      d.addAction(ActionKind.forward);
      final ifs = d.body.single as IfStmt;
      expect(ifs.then.length, 1);
      expect(ifs.otherwise.length, 1);
    });
  });

  group("L'éditeur à l'écran", () {
    testWidgets('taper une garde puis une action construit le bloc', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const DepthFirstApp());
      await tester.pump();
      await _enterGame(tester);

      // La carte annonce la garde par défaut ET comment la changer.
      expect(find.textContaining('appuie sur une garde'), findsOneWidget);

      // L'onglet GARDES est ouvert par défaut.
      await tester.tap(find.text('mur devant').first);
      await tester.pump();
      // Le terme apparaît sur la carte, avec sa croix.
      expect(find.byIcon(Icons.close), findsWidgets);

      // Les actions vivent dans leur propre onglet.
      expect(find.text('AVANCER'), findsNothing);
      await tester.tap(find.text('ACTIONS').first);
      await tester.pump();
      await tester.tap(find.text('AVANCER').first);
      await tester.pump();
      expect(find.text('AVANCER'), findsWidgets);
    });

    testWidgets('« toujours » n\'est plus proposé comme garde', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const DepthFirstApp());
      await tester.pump();
      await _enterGame(tester);

      // Une garde vide est déjà « toujours » : le proposer ferait payer
      // un cycle pour un test constant.
      expect(find.widgetWithText(InkWell, 'toujours'), findsNothing);
    });

    testWidgets('les trois familles sont dans des onglets distincts', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const DepthFirstApp());
      await tester.pump();
      await _enterGame(tester);

      expect(find.text('GARDES'), findsOneWidget);
      expect(find.text('ACTIONS'), findsOneWidget);
      expect(find.text('CONTRÔLE'), findsOneWidget);

      // Une seule famille est visible à la fois.
      expect(find.text('mur devant'), findsOneWidget);
      await tester.tap(find.text('CONTRÔLE').first);
      await tester.pump();
      expect(find.text('mur devant'), findsNothing);
      expect(find.text('TANT QUE'), findsOneWidget);
    });
  });
}
