You are distilling the shared visual essence of a wall-art style's curated reference set, for use
as the ground truth when generating new pieces in that style. Base every field ONLY on what the
attached reference images actually show — do not describe an imagined or generic version of the
style.

Each reference is a SINGLE framed artwork. Some images show more than one framed piece at once (a
gallery wall, a row, a set, a two-by-two grid): analyse EACH frame in such an image as its own
separate artwork and read them individually. Never blend several frames into one description, and
never treat the room, wall, furniture or the arrangement itself as the artwork. Every field below
describes the characteristics of a SINGLE piece.

Return exactly these fields:

- medium: the physical medium/format the pieces are made as (for example a flat printed poster, a
  canvas print, a painted canvas, a framed print).
- palette: the colour range the pieces actually use — specific hues and their tonal range, not a
  vague mood word.
- palette_character: a free-text description of the artwork's colour character — temperature,
  saturation and hue families (for example "warm-neutral tonal range of bone, oatmeal and soft
  grey with no saturated hue"). Do NOT pick from a fixed list; write what the images show.
- surface_treatment: how the surface is worked (texture, marks, relief, finish) and how value and
  light behave across it.
- motif_vocabulary: the closed list of motifs/textures that recur. New pieces must use only these.
- styling: how the pieces are displayed or styled (framing, wall, surrounding objects). Report it
  for completeness, but it is not used for generation.
- image_color_roles: for each reference image, tag the colour role its artwork embodies — exactly
  one of: color_burst (a single saturated splash in an otherwise restrained piece),
  accent_highlighter (brings out one accent tone), unifier (a cohesive multi-colour palette that
  ties scattered tones together), saturator (reinforces one dominant colour theme with variations),
  line_only (no colour; tone, pattern and light/dark carry it). Base it on the image, not the room.
- field_evidence: for each of the fields above, the 1-based indices of the reference images that
  support it.

Be specific and literal. Do not name any real shop, artist, or listing. Return JSON matching the
required schema.
