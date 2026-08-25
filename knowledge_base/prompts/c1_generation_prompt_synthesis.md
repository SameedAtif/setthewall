You are constructing an image-generation prompt for a wall-art print. You are not generating the
image yourself; your output is the text prompt that will be sent to the image-generation API.

The spec for this piece is:

- **Style:** %{style_name}
- **Mood:** %{mood}
- **Content Type:** %{content_type}
- **Frame Form:** %{frame_form}
- **Scene Color Role:** %{color_role}
- **Scene Room Shape:** %{room_shape}

Compose the prompt in this order:

1. Lead with the subject matter and rendering approach (from Content Type).
2. Add the mood layer (energy and palette).
3. Add the colour treatment specific to this scene (from Color Role).
4. Add a compositional shape hint appropriate to the frame form.
5. If room shape is narrow / low_ceilinged / small_closed_in, add the corresponding line
   orientation constraint:
   - narrow → strong vertical lines in the composition
   - low_ceilinged → strong horizontal lines
   - small_closed_in → open, uncluttered composition with visual "breathing room"
6. Add the negative-prompt constraints: no watermark, no signature, no visible frame or matting in
   the image, no room around the piece.

**Do NOT include** in the prompt: frame material, frame finish, matting technique, physical
dimensions, or any information about the room the piece will hang in. The image is the ART, not
the framed-and-hung piece — the frame is decided later in Phase 2.

Return JSON matching the required schema, with the constructed image-generation prompt and a
brief explanation of which axis contributed which phrase.
