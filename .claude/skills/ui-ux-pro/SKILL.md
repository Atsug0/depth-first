---
name: ui-ux-pro
description: Interface work — layout, motion, states, accessibility and visual polish. Use whenever the request touches a component, a screen, an animation, a loading or empty state, colour and contrast, or asks to make something look better, even if design is never named.
---

# Interface work

## Motion
- Animate to explain a change of state, never for decoration. If removing the
  animation loses no information, remove it.
- Respect `prefers-reduced-motion`: decorative motion must be disablable.
- Entrances 150–250ms, exits faster. Spring easing for anything that should feel
  physical; linear only for progress.

## States are not optional
- Every async surface needs four: empty, loading, error, loaded. An empty state
  that says only "No data" wastes the one moment the user is paying attention —
  say what would put data there.
- Never show a success affordance for an action that has not completed.

## Honesty
- A number with no unit or baseline is noise. Say what good looks like next to it.
- Do not display a figure the system cannot actually measure; show nothing instead.

## Accessibility
- Body text at 4.5:1 contrast, interactive targets 44×44pt minimum.
- Colour is never the only carrier of meaning — pair it with text or shape.
