/// Aplatissement d'un corps de bloc en lignes affichables.
///
/// Chaque ligne porte l'id de son statement : c'est ce qui permet au
/// curseur d'exécution de se poser sur la bonne ligne. Le lien entre
/// l'instruction qui tourne et ce qu'elle produit dans le monde est la
/// seule chose que le joueur ne doit jamais perdre de vue.
library;

import '../../i18n/strings.dart';
import '../../vm/ast.dart';

class CodeLine {
  const CodeLine(
    this.depth,
    this.text,
    this.stmtId, {
    this.isKeyword = false,
    this.stmt,
    this.isCursor = false,
  });

  final int depth;
  final String text;
  final int? stmtId;
  final bool isKeyword;

  /// La ligne d'origine, pour pouvoir la supprimer d'un geste.
  final Stmt? stmt;

  /// Marque l'endroit où atterrira la prochaine action ajoutée.
  final bool isCursor;
}

String termLabel(GuardTerm t) {
  var base = Tr.get('guard.${t.kind.name}');
  if (t.kind == GuardKind.registerEquals) base = '$base ${t.arg}';
  return t.negated ? '${Tr.get('guard.not')} $base' : base;
}

/// Une garde composée se lit comme une phrase : les termes séparés par
/// leur opérateur, sans parenthèses — il n'y en a jamais.
String guardLabel(Guard g) {
  if (g.terms.isEmpty) return Tr.get('guard.always');
  final join = g.op == GuardOp.all
      ? ' ${Tr.get('guard.and')} '
      : ' ${Tr.get('guard.or')} ';
  return g.terms.map(termLabel).join(join);
}

String actionLabel(ActionKind a) => Tr.get('act.${a.name}');

int guardCost(Guard g) => g.cost;

/// Aplatit un corps en lignes. `cursorIn` : la liste où atterrira la
/// prochaine action — une ligne-curseur est insérée à sa fin. Sans ce
/// repère, on ne sait pas si on écrit dans la boucle ou après elle.
List<CodeLine> renderBody(
  List<Stmt> body, [
  int depth = 0,
  List<Stmt>? cursorIn,
]) {
  final out = <CodeLine>[];
  for (final s in body) {
    switch (s) {
      case ActionStmt():
        final label = s.kind == ActionKind.setRegister
            ? '${actionLabel(s.kind)} ← ${s.arg}'
            : actionLabel(s.kind);
        out.add(CodeLine(depth, label, s.id, stmt: s));
      case WhileStmt():
        out.add(
          CodeLine(
            depth,
            '${Tr.get('act.while')} ${guardLabel(s.cond)}',
            s.id,
            isKeyword: true,
            stmt: s,
          ),
        );
        out.addAll(renderBody(s.body, depth + 1, cursorIn));
      case IfStmt():
        out.add(
          CodeLine(
            depth,
            '${Tr.get('act.if')} ${guardLabel(s.cond)}',
            s.id,
            isKeyword: true,
            stmt: s,
          ),
        );
        out.addAll(renderBody(s.then, depth + 1, cursorIn));
        if (s.otherwise.isNotEmpty || identical(s.otherwise, cursorIn)) {
          out.add(CodeLine(depth, Tr.get('act.else'), null, isKeyword: true));
          out.addAll(renderBody(s.otherwise, depth + 1, cursorIn));
        }
      case RepeatStmt():
        out.add(
          CodeLine(depth, '× ${s.times}', s.id, isKeyword: true, stmt: s),
        );
        out.addAll(renderBody(s.body, depth + 1, cursorIn));
    }
  }
  if (cursorIn != null && identical(body, cursorIn)) {
    out.add(CodeLine(depth, Tr.get('editor.here'), null, isCursor: true));
  }
  return out;
}

/// Coût en cycles d'un passage « droit » du corps : ce que l'éditeur
/// affiche pour que le joueur sente le prix de ce qu'il écrit. Les
/// boucles sont comptées une itération — c'est une estimation, pas une
/// promesse.
int estimateBodyCost(List<Stmt> body) {
  var total = 0;
  for (final s in body) {
    switch (s) {
      case ActionStmt():
        total += s.kind.cycleCost;
      case WhileStmt():
        total += s.cond.cost + estimateBodyCost(s.body);
      case IfStmt():
        total += s.cond.cost + estimateBodyCost(s.then);
      case RepeatStmt():
        total += estimateBodyCost(s.body) * s.times;
    }
  }
  return total;
}
