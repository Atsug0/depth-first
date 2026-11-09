---
name: delegation
description: Deciding whether to split work across parallel subagents, and how to brief them. Use whenever a task has several parts, spans multiple files or repos, involves investigating more than one question, or the user asks to go faster or parallelise — and also when tempted to delegate something sequential, to check that it is actually independent.
---

# Delegating work

## The test for whether to split
Delegate when the pieces are **independent** — they can run without seeing each
other's results. Reading six files to answer one question is independent. A
refactor where step two depends on what step one found is not; splitting that
produces two agents guessing at each other's work.

If you cannot state what each subagent returns without referring to another
subagent's output, do it yourself.

## What it costs
Each subagent re-establishes context from nothing, explores, and reports back —
then you read the report. That overhead is real. A task you could finish in a
handful of tool calls is cheaper done directly, every time.

## Good shapes
- **Fan-out over a known list**: one subagent per repo, per file, per failing test.
- **Independent investigation**: "why does X fail" and "where is Y configured"
  asked at the same time.
- **Reading-heavy work**: searching and summarising, where the findings matter
  but the intermediate reading does not need to reach the main context.

## Poor shapes
- Sequential steps dressed up as parallel ones.
- Splitting one modest job into pieces to look busy.
- Review or verification — keep that in the main loop, where you hold the context.

## How to brief one
Give it everything it needs in the first message: the paths, the constraint, and
the exact shape of the answer you want back. A subagent sees none of this
conversation. A vague brief comes back as a vague report and you pay twice.

Launch independent subagents in a single turn so they run concurrently; launching
them one at a time serialises the work and loses the only advantage.

## After they report
Commit to the delegation. Do not redo a subagent's work or re-derive its findings
— if the report is not trustworthy enough to act on, the brief was wrong, and the
fix is a better brief rather than a second pass.
