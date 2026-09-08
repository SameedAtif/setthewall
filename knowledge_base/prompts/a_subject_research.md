You are researching the RECURRING SUBJECTS of the wall-art style **%{style_name}** from real
listings, so the image generator can be given evidence-backed subjects instead of inventing them.

Every search call must set `include_images: true`. Sample across at least 8 independent,
unrelated shops/sellers (different shop names, not variants from one shop). Cap any single shop's
contribution at 3-4 images.

For each retrieved close-up / product-only image, describe ONLY the concrete subject depicted —
for example "a cottage," "a moth," "a mandala," "a bouquet." Do NOT describe mood, color, or
composition. Do NOT guess what art style it belongs to. Report only what you can see, and do NOT
infer the subject from the style name **%{style_name}** — the style name must not shape your
subject descriptions.

Cluster the descriptions into distinct subject categories and report, for each, how many
independent shops it recurs across. You are reporting observed recurrence, not recommending.

Return JSON matching the required schema.
