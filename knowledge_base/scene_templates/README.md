# Scene Templates

Each scene template is a mockup image + calibrated measurements. Track B (module 02) classifies each
template on the six per-scene axes. Phase 2 Step 6 (module 04) uses the measurements to place art at
correct eye level, spacing, and coverage.

## File format

One YAML per template: `knowledge_base/scene_templates/<template_id>.yml`

```yaml
id: behind_sofa_light_neutral
name: "Behind sofa — light neutral"
image_path: "scene_templates/assets/behind_sofa_light_neutral.png"

# Physical measurements in the scene image, in pixels.
# These are populated by the human who builds the template, before Track B runs.
# Track B does NOT infer or measure these — it classifies the scene's axis values only.
measurements:
  image_width_px: 2400
  image_height_px: 1600
  # Pixels per inch, calibrated against a known-size object in the scene.
  # Required for Phase 2 Step 6 to translate the book's inch-based rules into pixel math.
  pixels_per_inch: 24

  # Anchor rectangles used by Step 6. Only include the ones relevant to this scene type.
  furniture_top_edge_y_px: 900      # top of the sofa/table/etc. — for the 8-10" gap rule
  wall_zone: { x: 200, y: 100, width: 2000, height: 800 }   # placement region
  seated_eye_level_y_px: 850        # only for room_type: seated_room
  standing_eye_level_y_px: 720      # only for room_type: hallway or no_furniture_wall

  # Furniture width in pixels — for the 2/3-3/4 fill rule and the group-width rule.
  furniture_width_px: 1600
```

## What Track B does with these

Track B loads each template's image, classifies the six axes against it, and writes the classification
back into `style_specs/<style>.yml` under `scenes.<template_id>.axes`. Measurements are read but not
modified. Track B never edits a scene_template file.
