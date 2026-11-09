---
name: flutter-expert
description: Flutter and Dart work in this repo — widgets, Riverpod state, repositories, codegen and tests. Use whenever the request touches a .dart file, mentions a widget, provider, rebuild, freezed/json codegen, or a Flutter test, even if Flutter is never named and even if the change looks trivial.
---

# Flutter

## Layering
- Logic lives in `cashbee_engine/lib/src/{data,domain,presentation}`. `consumer/` is a thin shell.
- Widgets stay dumb: no Dio calls, no repository access inside `build()`.
- State goes through Riverpod providers; navigation through Beamer locations.

## Rebuild discipline
- Prefer `const` constructors; the analyzer treats const lints as errors here.
- Watch the narrowest provider that does the job — `select` over whole-object `watch`.
- A `ListView` of non-const children is a rebuild smell; hoist what does not change.

## Codegen
- `*.g.dart` and `*.freezed.dart` are generated. Change the source annotation and rerun:
  `dart run build_runner build --delete-conflicting-outputs`
- Never hand-edit generated output.

## Tests
- Mirror the `lib/src/...` path under `test/`. `mocktail` for doubles, `http_mock_adapter` for Dio.
- Run one file: `flutter test test/src/path/to/foo_test.dart`
