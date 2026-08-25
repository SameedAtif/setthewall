Measure the wall region this scene will use for placement. Classify the space math as one of:

- **single** — furniture-anchored, and one piece at 2/3-3/4 of the furniture's width fills the space
  well.
- **set** — furniture-anchored, but a single piece does not fill the space, OR the furniture beneath
  is minimal so a set is more appropriate.
- **split_wall** — wide-open wall with no furniture to anchor against (e.g. a hallway).
- **nook** — an architectural nook (window surround, chimney jog, built-in, or other wall quirk) that
  wants a piece shaped to it rather than a standard wall run.
- **surface** — a horizontal surface (mantel, shelf, console, windowsill), not a wall mount at all.

This is arithmetic against the actual scene dimensions, not preference. If you have the scene image
and can identify a rough furniture width or wall region, use those numbers to justify the call. If a
piece at 2/3-3/4 of furniture width would visibly fill the space, that is `single`; if it would leave
significant empty wall on either side, that is `set` (or `split_wall` if the wall is furniture-less
entirely).

Return JSON matching the required schema, including your reasoning about proportions.
