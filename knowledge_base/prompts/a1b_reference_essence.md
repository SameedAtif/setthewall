You are distilling the shared visual essence of a wall-art style's curated reference set, for use
as the ground truth when generating new pieces in that style. Base every field ONLY on what the
attached reference images actually show — do not describe an imagined or generic version of the
style.

Return exactly these fields:

- medium: the physical medium/format the pieces are made as (for example a flat printed poster, a
  canvas print, a painted canvas, a framed print).
- palette: the colour range the pieces actually use — specific hues and their tonal range, not a
  vague mood word.
- surface_treatment: how the surface is worked (texture, marks, relief, finish) and how value and
  light behave across it.
- motif_vocabulary: the closed list of motifs/textures that recur. New pieces must use only these.
- styling: how the pieces are displayed or styled (framing, wall, surrounding objects). Report it
  for completeness, but it is not used for generation.
- field_evidence: for each of the fields above, the 1-based indices of the reference images that
  support it.

Be specific and literal. Do not name any real shop, artist, or listing. Return JSON matching the
required schema.
