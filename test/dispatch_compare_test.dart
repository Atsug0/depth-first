import 'package:depth_first/game/run.dart';
import 'package:depth_first/vm/ast.dart';
import 'package:depth_first/vm/generator.dart';
import 'package:depth_first/vm/trace.dart';
import 'package:depth_first/vm/vm.dart';
import 'package:flutter_test/flutter_test.dart';

/// POURQUOI « DERNIER MATCH GAGNE » ET PAS « TOUS LES BLOCS »
///
/// Le modèle a été remis en cause après qu'un joueur a écrit deux fois
/// de suite un programme qui « aurait dû » marcher : un bloc qui
/// avance tant qu'il peut, un bloc qui tourne quand c'est bloqué. Son
/// attente — les deux s'enchaînent — correspond au modèle
/// `allMatching`, pas au nôtre.
///
/// Ces tests mesurent le vrai coût de chaque modèle. Ils échoueront si
/// quelqu'un change le défaut : c'est voulu.
void main() {
  group('Modèle de dispatch', () {
    test('allMatching rend tout bloc de repli impossible', () {
      // Le solveur canonique repose sur un repli « QUAND toujours
      // FAIRE tourner à gauche », qui ne doit s'exécuter QUE si aucune
      // règle plus précise ne s'applique. En allMatching il tourne à
      // chaque tick, en plus de tout le reste, et plus rien ne marche.
      var lastMatch = 0;
      var allMatching = 0;
      for (var i = 0; i < campaign.length; i++) {
        final room = Generator(2000 + i).generate(campaign[i]);
        if (room == null) continue;
        if (Vm(room, canonicalSolver()).run().success) lastMatch++;
        if (Vm(
          room,
          canonicalSolver(),
          mode: DispatchMode.allMatching,
        ).run().success) {
          allMatching++;
        }
      }
      expect(lastMatch, campaign.length);
      expect(
        allMatching,
        0,
        reason:
            "« fais X sauf si un cas plus précis s'applique » est le "
            'motif le plus courant, et allMatching le rend inexprimable',
      );
    });

    test('le prix à payer : le modèle naïf du joueur ne marche pas', () {
      // Deux blocs sans garde : le second supplante le premier, qui ne
      // tourne jamais. C'est le coût assumé de la priorité — d'où
      // l'avertissement sur la carte et le diagnostic après coup.
      final run = RunState(seed: 4242);
      run.appendBlock(
        Block(
          guard: const Guard.always(),
          body: [
            WhileStmt(Guard.of(GuardKind.floorAhead), [
              ActionStmt(ActionKind.forward),
            ]),
          ],
          floorAdded: 1,
        ),
      );
      run.commit(run.execute());
      run.descend();
      run.appendBlock(
        Block(
          guard: const Guard.always(),
          body: [
            IfStmt(
              Guard(const [
                GuardTerm(GuardKind.wallAhead),
                GuardTerm(GuardKind.floorRight),
              ]),
              [ActionStmt(ActionKind.turnRight)],
            ),
          ],
          floorAdded: 2,
        ),
      );
      final r = run.execute();
      final gagnants = r.frames
          .map((f) => f.activeBlock)
          .whereType<int>()
          .toSet();
      expect(gagnants, {1}, reason: 'le bloc 0 ne tourne jamais');
      expect(r.success, isFalse);
    });

    test('la même intention, exprimée dans la GARDE, résout', () {
      // La condition appartient à la garde du bloc, pas à un SI dans
      // son corps : la garde décide QUEL bloc tourne, le SI ne branche
      // qu'à l'intérieur d'un bloc déjà élu.
      final run = RunState(seed: 4242);
      run.appendBlock(
        Block(
          guard: const Guard.always(),
          body: [
            WhileStmt(Guard.of(GuardKind.floorAhead), [
              ActionStmt(ActionKind.forward),
            ]),
          ],
          floorAdded: 1,
        ),
      );
      run.commit(run.execute());
      run.descend();
      run.appendBlock(
        Block(
          guard: Guard(const [
            GuardTerm(GuardKind.wallAhead),
            GuardTerm(GuardKind.floorRight),
          ]),
          body: [ActionStmt(ActionKind.turnRight)],
          floorAdded: 2,
        ),
      );
      final r = run.execute();
      expect(r.outcome, Outcome.solved);
    });
  });
}
