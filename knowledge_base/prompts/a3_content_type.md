Classify this style's reference imagery into exactly one content type, based on the actual subject
matter and rendering style shown:

- **detailed_representational** — landscapes, dense imagery, representational subject matter
  carrying detail.
- **minimalist_modern** — line work, negative space, abstract composition.
- **portrait_still_life** — portrait or still-life subject matter.

Then perform this cross-check: each content type predicts a frame contour —
detailed_representational predicts inward-sloping/beveled framing; minimalist_modern predicts
flush/level-plane; portrait_still_life predicts outward-sloping.

Look at how the reference pieces are ACTUALLY framed. If the framing you observe does not match the
contour predicted by your classification, the classification is probably wrong — report the
mismatch rather than ignoring it.

Return JSON matching the required schema.
