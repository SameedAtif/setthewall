module Steps
  module TrackB
    class ColorRole < Steps::Base
      step id: "B6",
           mechanism: :llm_vision,
           ownership: "[AGENT-READY for steps 1 & 3 — human confirms the override call in step 2]"

      # context additions expected:
      #   content_type:            the style's content_type (from Track A / style spec)
      #   wall_condition:          B1's confirmed value
      #   furniture_weight:        B2's confirmed value
      #   catalog_strategy_override: nil, or a human-supplied reason to override the
      #                              minimalist_modern → line_only default in step 2
      def perform
        # === Step 1 — observation ===
        step1 = RubyLLM.chat(model: Pipeline::VISION_MODEL)
                      .with_schema(Schemas::TrackB::ColorRoleObservationSchema)
                      .ask(prompt("b6_color_role"), with: context.fetch(:scene_image))
                      .content

        candidate = step1["candidate_role"]

        # === Step 2 — Content Type override (human-decided) ===
        # Rule from color_role_observation.yml: if content_type is minimalist_modern, line_only
        # OVERRIDES the observation candidate UNLESS the human has a specific catalog-strategy
        # reason to keep the observation-driven role. This is the one non-mechanical call in B6.
        content_type   = context.fetch(:content_type)
        override_role  = nil
        override_reason = nil

        if content_type == "minimalist_modern"
          if context[:catalog_strategy_override].present?
            override_reason = "human catalog-strategy override: #{context[:catalog_strategy_override]}"
          elsif candidate != "line_only"
            # The default fires — but this is exactly where the human confirms, per ownership tag.
            return needs_human(
              "B6 Content Type override: content_type is minimalist_modern, so the documented " \
              "default (line_only, p.97) OVERRIDES the observation-driven candidate " \
              "(#{candidate}). Confirm the override, OR provide a catalog-strategy reason to " \
              "keep #{candidate} instead. This is the one strategic call in B6 that cannot be " \
              "made by the agent.",
              { observation_candidate: candidate,
                default_override: "line_only",
                override_citation: "p. 97, module 04 §2.2a",
                override_pending: true, conflicts: [] }
            )
          end
        end

        chosen_role = override_role || candidate

        # === Step 3 — cross-check against B1/B2 ===
        conflicts = cross_check(chosen_role, context.fetch(:wall_condition),
                                context.fetch(:furniture_weight))

        if conflicts.any?
          return needs_human(
            "B6 step-3 cross-check flagged conflicts: #{conflicts.join('; ')}. Per the source " \
            "rule, resolve the conflict explicitly rather than defaulting to whichever was " \
            "decided first.",
            { chosen_role: chosen_role, conflicts: conflicts, override_pending: false }
          )
        end

        ok({ color_role: chosen_role, candidate_role: candidate,
             override_reason: override_reason, override_pending: false, conflicts: [],
             observed_color_state: step1["observed_color_state"] })
      end

      private

      def cross_check(role, wall_condition, furniture_weight)
        conflicts = []
        # Color-burst assumes a neutral backdrop — a busy wall contradicts that
        if role == "color_burst" && wall_condition == "busy"
          conflicts << "color_burst assumes a neutral backdrop, but wall_condition is busy"
        end
        # Unifier assumes visible scattered accents — flag against very-plain scenes
        # (heuristic: busy wall + light furniture is a common no-accent combination)
        if role == "unifier" && wall_condition == "neutral" && furniture_weight == "light"
          conflicts << "unifier assumes visible scattered accents, but this scene reads as " \
                       "very plain (neutral wall + light furniture)"
        end
        conflicts
      end
    end
  end
end
