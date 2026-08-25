Classify the room in this scene as one of:

- **seated_room** — a living or dining room with couches/chairs where people sit at length.
- **hallway** — a passageway or corridor, no seated furniture.
- **no_furniture_wall** — a wall with no furniture directly beneath it (entry wall, stairwell wall,
  a bare wall in any room).

If the scene is genuinely ambiguous — for example, a hallway with a bench, or a seated space with
minimal furniture off to one side — do NOT guess. Report the classification as `ambiguous` and
explain what makes it ambiguous.

This is the ONE per-scene axis with no safe default: the three eye-level formulas that follow are not
interchangeable (a wrong guess silently produces wrong eye-level math downstream). The correct
behaviour on ambiguity is to escalate to a human, not to pick.

Return JSON matching the required schema.
