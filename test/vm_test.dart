import 'package:depth_first/game/run.dart';
import 'package:depth_first/vm/ast.dart';
import 'package:depth_first/vm/generator.dart';
import 'package:depth_first/vm/room.dart';
import 'package:depth_first/vm/trace.dart';
import 'package:depth_first/vm/vm.dart';
import 'package:flutter_test/flutter_test.dart';

Room straightCorridor({int len = 6}) {
  const h = 3;
  final w = len + 2;
  final tiles = List<Tile>.filled(w * h, Tile.wall);
  for (var x = 1; x <= len; x++) {
    tiles[1 * w + x] = Tile.floor;
  }
  tiles[1 * w + len] = Tile.exitTile;
  return Room(
    width: w,
    height: h,
    tiles: tiles,
    startX: 1,
    startY: 1,
    startDir: Dir.east,
    items: const [],
    bonuses: const [],
    fog: false,
    cycleLimit: 500,
    referenceCost: 0,
    seed: 1,
    archetype: Archetype.corridor,
  );
}

void main() {
  group('VM', () {
    test('un programme trivial traverse un couloir', () {
      final p = Program([
        Block(
          guard: Guard.of(GuardKind.always),
          body: [ActionStmt(ActionKind.forward)],
          floorAdded: 1,
        ),
      ]);
      final r = Vm(straightCorridor(), p).run();
      expect(r.outcome, Outcome.solved);
      expect(r.frames, isNotEmpty);
    });

    test('la taxe de gardes est proportionnelle au nombre de blocs', () {
      Program withBlocks(int n) => Program([
        for (var i = 0; i < n; i++)
          Block(
            guard: Guard.of(GuardKind.always),
            body: i == n - 1 ? [ActionStmt(ActionKind.forward)] : [],
            floorAdded: 1,
          ),
      ]);
      final one = Vm(straightCorridor(), withBlocks(1)).run();
      final five = Vm(straightCorridor(), withBlocks(5)).run();
      expect(five.guardCycles, greaterThan(one.guardCycles));
      expect(five.cyclesSpent, greaterThan(one.cyclesSpent));
    });

    test('un bloc sans garde qui matche bloque et finit par expirer', () {
      final p = Program([
        Block(
          guard: Guard.of(GuardKind.pitAhead),
          body: [ActionStmt(ActionKind.forward)],
          floorAdded: 1,
        ),
      ]);
      final r = Vm(straightCorridor(), p).run();
      expect(r.outcome, Outcome.cycleLimit);
      expect(r.frames.any((f) => f.event == FrameEvent.blocked), isTrue);
    });

    test('marcher dans des pics interrompt et coûte la pénalité', () {
      final room = straightCorridor();
      final tiles = List<Tile>.of(room.tiles);
      tiles[1 * room.width + 3] = Tile.spike;
      final trapped = Room(
        width: room.width,
        height: room.height,
        tiles: tiles,
        startX: 1,
        startY: 1,
        startDir: Dir.east,
        items: const [],
        bonuses: const [],
        fog: false,
        cycleLimit: 500,
        referenceCost: 0,
        seed: 1,
        archetype: Archetype.spikes,
      );
      final reckless = Program([
        Block(
          guard: Guard.of(GuardKind.always),
          body: [ActionStmt(ActionKind.forward)],
          floorAdded: 1,
        ),
      ]);
      final r = Vm(trapped, reckless).run();
      expect(r.outcome, Outcome.hazard);
      expect(r.penalty, ExecResult.hazardPenalty);
      expect(r.totalCost, greaterThan(r.cyclesSpent));
    });

    test('un programme prudent survit là où le téméraire meurt', () {
      final room = straightCorridor();
      final tiles = List<Tile>.of(room.tiles);
      tiles[1 * room.width + 3] = Tile.spike;
      final trapped = Room(
        width: room.width,
        height: room.height,
        tiles: tiles,
        startX: 1,
        startY: 1,
        startDir: Dir.east,
        items: const [],
        bonuses: const [],
        fog: false,
        cycleLimit: 500,
        referenceCost: 0,
        seed: 1,
        archetype: Archetype.spikes,
      );
      // Ne bouge que si le sol devant est sûr : il s'arrête net.
      final careful = Program([
        Block(
          guard: Guard.of(GuardKind.floorAhead),
          body: [ActionStmt(ActionKind.forward)],
          floorAdded: 1,
        ),
      ]);
      final r = Vm(trapped, careful).run();
      expect(r.outcome, isNot(Outcome.hazard));
    });

    test('dernier match gagne : le bloc le plus récent a la priorité', () {
      final p = Program([
        Block(
          guard: Guard.of(GuardKind.always),
          body: [ActionStmt(ActionKind.turnLeft)],
          floorAdded: 1,
        ),
        Block(
          guard: Guard.of(GuardKind.always),
          body: [ActionStmt(ActionKind.forward)],
          floorAdded: 2,
        ),
      ]);
      final r = Vm(straightCorridor(), p).run();
      expect(
        r.outcome,
        Outcome.solved,
        reason: 'le second bloc doit primer sur le premier',
      );
    });

    test('exécution déterministe : deux runs donnent la même trace', () {
      Program p() => Program([
        Block(
          guard: Guard.of(GuardKind.always),
          body: [ActionStmt(ActionKind.forward)],
          floorAdded: 1,
        ),
      ]);
      final a = Vm(straightCorridor(), p()).run();
      final b = Vm(straightCorridor(), p()).run();
      expect(a.frames.length, b.frames.length);
      expect(a.cyclesSpent, b.cyclesSpent);
    });
  });

  group('Sérialisation', () {
    test('une salle survit à un aller-retour JSON', () {
      final room = straightCorridor();
      final back = Room.fromJson(room.toJson());
      expect(back.width, room.width);
      expect(back.tiles, room.tiles);
      expect(back.startDir, room.startDir);
    });

    test('un bloc survit à un aller-retour JSON', () {
      final b = Block(
        guard: Guard.of(GuardKind.hazardAhead),
        body: [
          WhileStmt(Guard.of(GuardKind.floorAhead), [
            ActionStmt(ActionKind.forward),
          ]),
          ActionStmt(ActionKind.turnRight),
        ],
        floorAdded: 3,
        frozen: true,
      );
      final back = Block.fromJson(b.toJson());
      expect(back.guard, b.guard);
      expect(back.body.length, 2);
      expect(back.frozen, isTrue);
    });
  });

  group('Générateur', () {
    test('chaque étage de la campagne produit une salle solvable', () {
      for (var i = 0; i < campaign.length; i++) {
        final room = Generator(1000 + i).generate(campaign[i]);
        expect(room, isNotNull, reason: 'étage ${i + 1} non généré');
        final check = Vm(room!, canonicalSolver()).run();
        expect(check.success, isTrue, reason: 'étage ${i + 1} insoluble');
        expect(room.referenceCost, greaterThan(0));
        expect(room.cycleLimit, greaterThan(room.referenceCost));
      }
    });

    test('le générateur rejette une salle que le joueur résout déjà', () {
      // Programme qui résout n'importe quel couloir droit.
      final solver = canonicalSolver();
      final spec = campaign[0];
      final room = Generator(42).generate(spec, playerProgram: solver);
      expect(
        room,
        isNull,
        reason: 'une salle déjà résolue ne doit jamais être proposée',
      );
    });

    test('les dangers ne sont jamais sur le chemin canonique', () {
      final room = Generator(77).generate(campaign[4]);
      expect(room, isNotNull);
      final r = Vm(room!, canonicalSolver()).run();
      expect(r.outcome, Outcome.solved);
    });
  });

  group('Enlisement et priorité', () {
    test("le scénario du joueur : avancer-tant-que puis tourner-si-droite", () {
      // Étage 2 « virage » : un couloir est-ouest, puis une descente.
      // Le programme naïf tourne à droite DEUX fois dans le coin, revient
      // sur ses pas, puis tourne à vide. C'est le piège central du jeu —
      // mais il doit être DIT, pas subi en silence jusqu'à la limite.
      final run = RunState(seed: 4242);
      run.appendBlock(
        Block(
          guard: Guard.of(GuardKind.always),
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
          guard: Guard.of(GuardKind.floorRight),
          body: [ActionStmt(ActionKind.turnRight)],
          floorAdded: 2,
        ),
      );
      final r = run.execute();

      expect(
        r.outcome,
        Outcome.stalled,
        reason: "l'impasse doit être nommée, pas maquillée en lenteur",
      );
      expect(
        r.cyclesSpent,
        lessThan(run.room!.cycleLimit),
        reason: "s'enliser ne doit pas coûter la jauge entière",
      );
      expect(
        r.frames.any((f) => f.activeBlock == 1),
        isTrue,
        reason: 'le second bloc A bien gagné le dispatch, au moins une fois',
      );
    });

    test('un bloc qui matche sans gagner est signalé comme supplanté', () {
      // Deux blocs `toujours` : le second gagne toujours, le premier
      // matche sans jamais l'emporter. Le joueur doit pouvoir le voir.
      final p = Program([
        Block(
          guard: Guard.of(GuardKind.always),
          body: [ActionStmt(ActionKind.turnLeft)],
          floorAdded: 1,
        ),
        Block(
          guard: Guard.of(GuardKind.always),
          body: [ActionStmt(ActionKind.forward)],
          floorAdded: 2,
        ),
      ]);
      final r = Vm(straightCorridor(), p).run();
      final dispatch = r.frames.firstWhere(
        (f) => f.event == FrameEvent.dispatch,
      );
      expect(dispatch.matched, containsAll([0, 1]));
      expect(dispatch.activeBlock, 1);
    });

    test('attendre indéfiniment est un enlisement, pas une lenteur', () {
      final p = Program([
        Block(
          guard: Guard.of(GuardKind.always),
          body: [ActionStmt(ActionKind.wait)],
          floorAdded: 1,
        ),
      ]);
      final r = Vm(straightCorridor(), p).run();
      expect(r.outcome, Outcome.stalled);
    });

    test('un programme qui progresse ne déclenche jamais l\'enlisement', () {
      final p = Program([
        Block(
          guard: Guard.of(GuardKind.always),
          body: [ActionStmt(ActionKind.forward)],
          floorAdded: 1,
        ),
      ]);
      final r = Vm(straightCorridor(len: 12), p).run();
      expect(r.outcome, Outcome.solved);
    });
  });

  group('Gardes composées', () {
    test('NON comble le trou : « je ne peux pas avancer »', () {
      // `mur devant` ne couvre ni le vide ni les pics. `NON sol libre
      // devant` couvre les trois d'un coup — c'est ce qui manquait au
      // vocabulaire, et aucune combinaison de gardes simples ne le
      // remplaçait.
      final room = straightCorridor();
      final tiles = List<Tile>.of(room.tiles);
      tiles[1 * room.width + 3] = Tile.pit;
      final chasm = Room(
        width: room.width,
        height: room.height,
        tiles: tiles,
        startX: 1,
        startY: 1,
        startDir: Dir.east,
        items: const [],
        bonuses: const [],
        fog: false,
        cycleLimit: 500,
        referenceCost: 0,
        seed: 1,
        archetype: Archetype.chasm,
      );

      // `mur devant` est faux devant un trou : le programme fonce.
      final naive = Program([
        Block(
          guard: Guard.of(GuardKind.wallAhead),
          body: [ActionStmt(ActionKind.turnRight)],
          floorAdded: 1,
        ),
        Block(
          guard: Guard.always(),
          body: [ActionStmt(ActionKind.forward)],
          floorAdded: 1,
        ),
      ]);
      expect(Vm(chasm, naive).run().outcome, Outcome.hazard);

      // `NON sol libre devant` l'arrête.
      final careful = Program([
        Block(
          guard: Guard([const GuardTerm(GuardKind.floorAhead, negated: true)]),
          body: [ActionStmt(ActionKind.wait)],
          floorAdded: 1,
        ),
        Block(
          guard: Guard.of(GuardKind.floorAhead),
          body: [ActionStmt(ActionKind.forward)],
          floorAdded: 1,
        ),
      ]);
      expect(Vm(chasm, careful).run().outcome, isNot(Outcome.hazard));
    });

    test('ET résout le virage là où une garde simple s\'annulait', () {
      final run = RunState(seed: 4242);
      run.appendBlock(
        Block(
          guard: Guard.always(),
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

      // « mur devant ET sol libre à droite » : précis, et il cesse
      // d'être vrai dès qu'on a tourné.
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

    test('OU regroupe deux dangers en une garde', () {
      final g = Guard(const [
        GuardTerm(GuardKind.pitAhead),
        GuardTerm(GuardKind.spikeAhead),
      ], op: GuardOp.any);
      expect(g.cost, 2, reason: 'chaque terme se paie à chaque tick');
      expect(g.isAlways, isFalse);
    });

    test('une garde composée survit à un aller-retour JSON', () {
      final g = Guard(const [
        GuardTerm(GuardKind.wallAhead),
        GuardTerm(GuardKind.floorRight, negated: true),
      ], op: GuardOp.any);
      expect(Guard.fromJson(g.toJson()), g);
    });

    test('une garde vide est toujours vraie', () {
      expect(const Guard.always().isAlways, isTrue);
      final p = Program([
        Block(
          guard: const Guard.always(),
          body: [ActionStmt(ActionKind.forward)],
          floorAdded: 1,
        ),
      ]);
      expect(Vm(straightCorridor(), p).run().outcome, Outcome.solved);
    });
  });

  group('Le piège du bloc sans garde', () {
    test('un bloc « toujours » ajouté en bas neutralise toute la pile', () {
      // Dernier match gagne : une garde vide matche à chaque tick, donc
      // le bloc du bas remporte TOUS les dispatches. C'est la cause la
      // plus fréquente de « mon programme ne fait rien ».
      final p = Program([
        Block(
          guard: Guard.of(GuardKind.floorAhead),
          body: [ActionStmt(ActionKind.forward)],
          floorAdded: 1,
        ),
        Block(
          guard: const Guard.always(),
          body: [ActionStmt(ActionKind.turnRight)],
          floorAdded: 2,
        ),
      ]);
      final r = Vm(straightCorridor(), p).run();
      final winners = r.frames
          .map((f) => f.activeBlock)
          .whereType<int>()
          .toSet();
      expect(winners, {1}, reason: 'le bloc 0 ne tourne jamais');
      expect(r.success, isFalse);
    });

    test(
      'une rotation sur place est détectée comme boucle, pas comme lenteur',
      () {
        // Tourner change l'orientation, donc l'état « bouge » : une
        // détection naïve de gel ne verrait rien. On détecte le RETOUR
        // à un état déjà visité, ce qui prouve la boucle.
        final p = Program([
          Block(
            guard: const Guard.always(),
            body: [ActionStmt(ActionKind.turnRight)],
            floorAdded: 1,
          ),
        ]);
        final r = Vm(straightCorridor(), p).run();
        expect(r.outcome, Outcome.stalled);
        expect(
          r.cyclesSpent,
          lessThan(40),
          reason: 'la boucle se prouve en quelques ticks',
        );
      },
    );
  });
}
