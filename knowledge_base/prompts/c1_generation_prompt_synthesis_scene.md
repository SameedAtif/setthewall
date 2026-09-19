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

Describe an ORIGINAL composition that renders this subject through this pattern, inventing all
specifics fresh. Follow this contract exactly:

MUST PRESERVE (evidence-backed — recurred across independent, unrelated sellers, so this is genre
convention, not any single seller's property):
  - the narrative structure above, as a shape, not copied verbatim
  - the light logic above
  - the temporal quality above
  - the given subject (do not substitute a different subject)

MUST INVENT FRESH (this is what makes the result original rather than a copy of any real listing):
  - the surface treatment — the marks, ridges, layers, or material of the artwork itself
  - the composition within the artwork — where forms sit, foreground vs. field, framing
  - any secondary/supporting visual elements that are part of the artwork's own surface

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
