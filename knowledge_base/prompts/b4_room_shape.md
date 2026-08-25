Classify the room shape/proportion in this scene as one of:

- **narrow** — a room significantly deeper than it is wide.
- **low_ceilinged** — a room whose ceiling reads as low relative to its floor area.
- **small_closed_in** — a small room that feels enclosed or cramped.
- **none** — none of the above conditions apply.

"None" is a legitimate, common answer — do not force a fit. Most standard rooms are "none". This axis
only adds an optional space-tip constraint on art generation; a false positive forces an unnecessary
constraint, while "none" simply skips it.

If the read is genuinely borderline between a category and "none", classify as `none`. This is the
safe-fail direction.

Report `borderline: true` whenever you invoke this fallback. Return JSON matching the required schema.
