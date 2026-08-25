Classify this scene's wall as neutral/plain or busy/patterned.

Apply this specific test: would a frame need to "read distinctly" against this wall to avoid
disappearing? If yes, the wall is busy/patterned. If a frame in almost any material would sit clearly
against the wall, the wall is neutral/plain.

If the wall is genuinely borderline — a subtle texture, a very low-contrast pattern, or a colour close
to what a common frame would be — classify as neutral/plain. This is the safe-fail direction: the
match-vs-contrast rule this axis feeds is more forgiving of a false "neutral" than a false "busy".

Report `borderline: true` whenever you invoke this fallback, so the pipeline knows the classification
was ambiguous. Return JSON matching the required schema.
