You are constructing an image-generation prompt for a wall-art print. You are not generating the
image yourself; your output is the text prompt that will be sent to the image-generation API.

The spec for this piece is:

- **Style:** %{style_name}
- **Mood:** %{mood}
- **Content Type:** %{content_type}
- **Scene Color Role:** %{color_role}
- **Scene Room Shape:** %{room_shape}

Compose the prompt in this order:

1. Lead with the subject matter and rendering approach (from Content Type).
2. Add the mood layer (energy and palette).
3. Add the colour treatment this piece plays in the room (from Color Role) as a SATURATION and
   INTENSITY instruction — high chroma and strong contrast against a neutral wall where the role
   calls for it. Do NOT invent a compositional structure or geometry from the role name; the role
   describes the piece's job in the room, not its internal layout.
4. If room shape is narrow / low_ceilinged / small_closed_in, add the corresponding line
   orientation constraint:
   - narrow → strong vertical lines in the composition
   - low_ceilinged → strong horizontal lines
   - small_closed_in → open, uncluttered composition with visual "breathing room"
5. Add the negative-prompt constraints: no watermark, no signature, no visible frame or matting in
   the image, no room around the piece.

**Do NOT include** in the prompt: frame material, frame finish, matting technique, physical
dimensions, frame form, or any information about the room the piece will hang in. The image is the
ART, not the framed-and-hung piece — the frame is decided later in Phase 2.

Return JSON matching the required schema, with the constructed image-generation prompt and a
brief explanation of which axis contributed which phrase.
