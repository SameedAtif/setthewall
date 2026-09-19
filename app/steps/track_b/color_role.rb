module Steps
  module TrackB
    class ColorRole < Steps::Base
      step id: "B6",
           mechanism: :llm_vision,
           ownership: "[AGENT-READY for steps 1 & 3 — human confirms the override call in step 2]"

      # context additions expected:
      #   content_type:               the style's content_type (from Track A / style spec)
      #   wall_condition:             B1's confirmed value
      #   furniture_weight:           B2's confirmed value
      #   color_role_override:        nil, or the role the human explicitly chose ("line_only" to
      #                               confirm the default, or the observed candidate to keep it)
      #   catalog_strategy_override:  nil, or a human-supplied reason to keep the observed role
      def perform
        # === Step 1 — observation ===
        step1 = Pipeline::Json.normalize(
          RubyLLM.chat(model: Pipeline::VISION_MODEL)
                .with_schema(Schemas::TrackB::ColorRoleObservationSchema)
                .ask(prompt("b6_color_role"), with: Pipeline::KB_ROOT.join(context.fetch(:scene_image)))
                .content
        )

        candidate = step1["candidate_role"]
        if candidate.blank?
          return needs_human(
            "B6 got no colour-role candidate back from the vision model. Re-run B6.",
            { result: step1, recommended_action: "reconsider" }
          )
        end

        # === Step 2 — the one strategic call: the run proposes, the human confirms ===
        # color_role is a room-relationship decision, not a style fact, so the run proposes the
        # role it observed and the human confirms it (or overrides with a catalog-strategy reason).
        # Nothing is hardcoded per content_type — every style/scene proposes from its own
        # observation.
        chosen_role = context[:color_role_override].presence || candidate

        # === Step 3 — cross-check against B1/B2 ===
        conflicts = cross_check(chosen_role, context.fetch(:wall_condition),
                                context.fetch(:furniture_weight))

        if context[:color_role_override].blank?
          return needs_human(
            "B6 proposes color_role=#{chosen_role} (observed candidate: #{candidate}). Confirm it, " \
            "or choose a different role with a catalog-strategy reason." \
            "#{conflicts.any? ? " Cross-check conflicts: #{conflicts.join('; ')}." : ''}",
            { observation_candidate: candidate, proposed_role: chosen_role,
              conflicts: conflicts, override_pending: true }
          )
        end

        override_reason =
          if chosen_role != candidate && context[:catalog_strategy_override].present?
            "human catalog-strategy override: #{context[:catalog_strategy_override]}"
          end

        ok({ color_role: chosen_role, candidate_role: candidate,
             override_reason: override_reason, override_pending: false, conflicts: conflicts,
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
