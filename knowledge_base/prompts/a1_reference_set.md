You are assembling a reference image set for the WALL-ART style: **%{style_name}**. You are
searching for wall art only — framed prints, posters, canvases, and paintings. "Wall art" does NOT
mean tableware, dinnerware, plates/dishes, textiles, vases, or any physical object. If a word in
the style name reads as an object (e.g. "plate", "plaque", "tapestry"), it refers to an
illustration or display style, never to a physical item — search for the wall-art medium, not the
object.

**Every search call in this task must set `include_images: true`.** Text-only search results
contain no usable image URLs — without this flag you will have nothing to build a candidate
list from. Do not report or invent an image URL you did not actually receive from a call made
with `include_images: true`; if a query returns no images, try a different query rather than
fabricating one.

Run this search process in order:

1. Search retailer style guides first — "West Elm %{style_name} wall art", "CB2 %{style_name} wall
   art", "IKEA %{style_name} wall art". These are authoritative named-style descriptions rather
   than merely visually-similar-but-mislabeled content.
2. Search Pinterest with three separate queries: "%{style_name} wall art", "%{style_name} gallery
   wall", "%{style_name} living room". Three separate queries, not one — this catches both
   product-only and in-situ shots.
3. Search 1-2 interior design blogs or magazines for written characteristic descriptions of the
   style (palette, materials, mood words), to cross-check what the images show against what is
   explicitly named.
4. Cap any single source (one shop, one blog, one Pinterest board) at roughly 3-4 images.

An image qualifies for the set only if it meets ALL of these:

- It's a real URL returned by a search call — never a URL you constructed, guessed, or recalled
  from training data.
- It depicts a piece of WALL ART — a framed print, poster, canvas, or painting — not tableware, a
  physical plate/dish, a vase, or a textile.
- Shows the piece actually framed and/or hung in a room, not just a flat product photo on white.
- Attributed to %{style_name} by at least one independent source (two or more is preferred) — it
  appears under that style's name in the searches above, not just one shop's own product tagging.
- Source is a retailer, a design publication, or a Pinterest pin with a real originating source
  (not an unattributed re-post).

Additionally, at least a third of the final set must be close-up / product-only shots of the art
itself — these are needed later to judge subject matter and rendering style, which is hard to read
in a full room shot.

Return candidates as JSON matching the required schema. Return 4 to 8 candidate images (never more
than 8) so the downstream mood/content-type checks have enough to work from. Prefer images with two
independent sources, but if that would leave you under 4 candidates, include the best single-source
images and reflect the single source in `attributing_sources`.

Also report `mood_clusters_found`: group the images into the distinct mood camps the set actually
spans (for example "calm botanical" vs "bold celestial"), with the 1-based image indices in each. If
the set is one coherent mood, report a single camp. Catching a split here is much cheaper than
discovering it after A2's full scoring pass.
