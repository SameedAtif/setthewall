You are writing the SCENE description for a wall-art print's image-generation prompt. You are not
generating the image yourself and you are not writing the final prompt — you are describing what
the artwork itself depicts. This is a FLAT PRINTED WALL-ART IMAGE, not a photograph of a real place.

You are given ONE recurring whole-scene pattern, reconstructed from multiple independent
bestsellers that converged on the same underlying idea. This is the only pattern you will see —
do not imagine or reference any other pattern.

  Narrative structure: %{narrative_structure}
  Light logic: %{light_logic}
  Temporal quality: %{temporal_quality}

You are also given ONE subject, independently validated as recurring across multiple sellers in
this style:

  Subject: %{recurring_subject}

And you are given the reference set's documented traits. These are the ground truth for this style
— stay inside them:

  Medium: %{essence_medium}
  Palette: %{essence_palette}
  Surface treatment: %{essence_surface}
  Motif vocabulary (use ONLY these motifs/textures): %{essence_motifs}

Describe an ORIGINAL composition that renders this subject through this pattern. Follow this
contract exactly:

MUST PRESERVE (evidence-backed — recurred across independent, unrelated sellers, so this is genre
convention, not any single seller's property):
  - the narrative structure above, as a shape, not copied verbatim
  - the light logic above
  - the temporal quality above
  - the given subject (do not substitute a different subject)
  - the documented medium, palette, surface treatment and motif vocabulary above

MAY INVENT FRESH — ONLY the composition within those documented traits:
  - where the forms sit, the arrangement, balance and framing inside the artwork

DO NOT invent content outside the documented traits:
  - no subjects, objects, materials, colours or texture types beyond the motif vocabulary and
    surface treatment above; no crosshatching, no tight spiral coils

HARD CONSTRAINTS (the reference set is abstract surface art — staying abstract is the medium):
  - Describe ONLY the artwork's own surface and forms.
  - Do NOT depict or imply a real-world place, landscape, horizon, sky, mountain, field, sea,
    room, wall, furniture, person, animal, or any physical-world object. No photographic scenes.
  - Do NOT write camera, lens, or photography language — this is a print, not a photo.
  - No text, watermark, or signature.

%{room_shape_constraint}

Write ONE continuous, coherent description of a single moment on the artwork's surface — not a
bulleted list of separate facts stapled together.

Return JSON matching the required schema: { "scene_description": "<one continuous description>" }.
