module Steps
  module Phase2
    class AssignFrame < Steps::Base
      step id: "P2_4", mechanism: :lookup, ownership: "[AGENT-READY]"

      # context: { palette: (warm|cool|pastel|abstract|neutral|monochrome) }
      def perform
        material_rules  = rules("frame_material")
        form_rules      = rules("frame_form_contour")
        match_rules     = rules("match_contrast")
        matting_rules   = rules("matting")

        # === Category (§2.1 Step A) ===
        category = pick_material_category(material_rules)

        # === Finish (§2.1 Step B) — only if metal ===
        finish = category == "metal" ? pick_metal_finish(material_rules) : nil

        # === Contour (§2.2, per-piece by content_type) ===
        contour = form_rules.fetch("contour", piece.content_type, "contour")

        # === Match vs. contrast (§2.3) — governing principle overrides table on conflict ===
        match_or_contrast = match_rules.fetch("by_wall_condition", piece.wall_condition, "approach")

        # === Matting technique (§2.4b) — needs human context, so record a default and flag ===
        # Default to standard_single_mat; a human can pick a specific condition-driven technique
        # via context. Not silently guessing color/depth intent.
        matting_technique = context.fetch(:matting_technique, "standard_single_mat")

        piece.update!(
          frame_material_category: category,
          frame_material_finish: finish,
          frame_contour: contour,
          matting_technique: matting_technique
        )

        ok({
          category: category, finish: finish, contour: contour,
          match_or_contrast: match_or_contrast,
          matting_technique: matting_technique,
          # Governing principle from §2.3 as a reminder for downstream reviewers:
          governing_principle: match_rules.fetch("governing_principle", "rule")
        })
      end

      private

      # Content Type + Mood → material category. Uses the "best_fit" column of §2.1 Step A.
      def pick_material_category(material_rules)
        cats = material_rules.rules["material_category"]
        # Direct rules from the source doc's "best fit" column:
        return "metal" if piece.content_type == "minimalist_modern"
        return "ornate_carved" if piece.mood == "bold_active" &&
                                  %w[detailed_representational portrait_still_life].include?(piece.content_type)
        return "wood"  if piece.mood == "calm_ordered"
        "metal"        # documented default
      end

      def pick_metal_finish(material_rules)
        palette = context.fetch(:palette, "neutral")

        return "follows_accent_color" if piece.mood == "bold_active"
        case palette
        when "warm"                        then "gold"
        when "cool", "pastel", "abstract"  then "silver_aluminum"
        when "neutral", "monochrome"       then "black_metal"
        else "black_metal"
        end
      end
    end
  end
end
