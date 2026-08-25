Classify the visible furniture in this scene as light or dark.

Weight is driven by colour AND size together, not colour alone. A large pale wooden table can carry
more visual weight than a small dark stool — read both signals before deciding.

If the furniture is a mid-tone or the read is genuinely ambiguous, classify as light. This is the
safe-fail direction: the weight-balance rule this axis feeds requires art lighter than dark
furniture, but only allows (does not require) art heavier than light furniture — defaulting to light
turns the check into a permission rather than a mandate in the ambiguous case.

Report `borderline: true` whenever you invoke this fallback. Return JSON matching the required schema.
