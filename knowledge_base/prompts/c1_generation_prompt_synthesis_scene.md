You are given ONE recurring whole-scene pattern, reconstructed from multiple independent
bestsellers that converged on the same underlying idea. This is the only pattern you will see —
do not imagine or reference any other pattern.

  Narrative structure: %{narrative_structure}
  Light logic: %{light_logic}
  Temporal quality: %{temporal_quality}

You are also given ONE subject, independently validated as recurring across multiple sellers in
this style:

  Subject: %{recurring_subject}

Write an ORIGINAL scene that uses this subject within the given narrative pattern, inventing all
specifics fresh. Follow this contract exactly:

MUST PRESERVE (evidence-backed — recurred across independent, unrelated sellers, so this is genre
convention, not any single seller's property):
  - the narrative structure above, as a shape, not copied verbatim
  - the light logic above
  - the temporal quality above
  - the given subject (do not substitute a different subject)

MUST INVENT FRESH (this is what makes the result original rather than a copy of any real listing):
  - the specific setting, materials, season/time of day/year, and surrounding detail
  - the specific composition — camera angle, what occupies the foreground vs. background,
    exact framing
  - any secondary/supporting visual elements not named above

Rendering density and literalness: %{content_type}
  (detailed_representational = dense, literal detail throughout; minimalist_modern = line work,
  negative space, abstraction; portrait_still_life = a single subject/object rendered with focus
  and clarity, less environmental detail)

Color/saturation role: %{color_role} — treat this ONLY as a saturation/intensity/contrast
instruction (e.g. "high chroma, strong contrast against a neutral wall"). Do NOT derive
composition, layout, or geometry from this value.

%{room_shape_constraint}

Write ONE continuous, coherent description of a single moment — not a bulleted list of separate
facts about subject, composition, and color stapled together. Every sentence should read as
elaborating the same implied scene.

Do not describe the output as "similar to," "inspired by," or reference any real shop, listing,
or artist, by name or implication.

Negative constraints, append verbatim: no watermark, no signature, no visible frame or matting in
the image, no room around the piece, no named living artist, no copyrighted character or property.

Return JSON matching the required schema: { "image_generation_prompt": "<the full constructed
prompt as one string>", "axis_contributions": [...], "negative_prompt": "..." }.
