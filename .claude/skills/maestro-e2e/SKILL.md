---
name: maestro-e2e
description: Maestro end-to-end flows — scenario YAML, subflows, the userNumber/baseUserNumber fixture graph, and assertions on literal French copy. Use whenever the request touches a flow or subflow file, a test scenario, device automation, or the generated dependency graph, even if Maestro is never named.
---

# Maestro

## Fixtures are a graph
- Every scenario declares `userNumber`, and optionally `baseUserNumber` to clone from.
  That chain **is** the dependency graph used by `run.sh` and the README diagram.
- Cloning is one backoffice call regardless of depth. To reach a state, clone from the
  closest scenario already in it — do not re-walk the UI to rebuild it.
- After adding or renaming a scenario: `node scripts/generate_graph.js` and commit the diff.

## Assertions
- Flows assert on **literal French copy** owned by the API repo. Read the exact string
  from the source; watch straight (') versus curly (’) apostrophes.
- Multi-sentence messages joined by `\n` render as one widget — assert with a `|-` block.
- `assertVisible` matches widget text, not rendered line wrap.

## Never claim a flow works from syntax alone
- `maestro check-syntax` proves the YAML parses, nothing more.
- Run it: `./run.sh android staging path/to/flow.yaml`. With no booted device, say so
  rather than reporting the scenario as verified.
