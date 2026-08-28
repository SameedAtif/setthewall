module Steps
  module Phase2
    class SetGroupingAndCount < Steps::Base
      step id: "P2_2b", mechanism: :lookup, ownership: "[AGENT-READY]"

      # context: { piece_count:, subject_energy: (dynamic|formal), staircase_scene: (bool) }
      def perform
        # A "set" branch is only meaningful once the human specifies how many pieces and
        # what form — the pipeline can't guess a set's cardinality.
        if context[:piece_count].blank?
          return needs_human(
            "Multi-piece set: specify the set in context — piece_count (int), " \
            "base_form (one of the 6 standard arrangement forms), subject_energy " \
            "(dynamic|formal), and anchor_url when piece_count is odd.",
            {}
          )
        end

        forms = rules("arrangement_forms")
        count = context.fetch(:piece_count, 1).to_i

        # Base form choice — human/orchestrator selects from the 6 standard forms; agent
        # rejects stair_stepping unless the scene is a staircase.
        base_form = context.fetch(:base_form, "tops_bottoms_alignment")
        if base_form == "stair_stepping" && !context[:staircase_scene]
          return fail_step("stair_stepping is scenario-specific — allowed only on a staircase wall.",
                           { requested: base_form })
        end

        mood_mod = forms.fetch("mood_modifier", piece.mood)

        # Subject-energy override on symmetry — supersedes mood if they conflict
        subject_energy = context.fetch(:subject_energy, "formal")
        symmetry_call, override_applied = resolve_symmetry(piece.mood, subject_energy)

        # Odd vs. even count — anchor logic
        count_rule = rules("count_focal").fetch("by_desired_effect",
                                                count.odd? ? "one_dominant_anchor" : "no_hierarchy_unified_block")
        anchor_required = count.odd?

        piece.update!(
          arrangement_form: base_form,
          piece_count: count,
          anchor_piece_ref: anchor_required ? context[:anchor_url] : nil
        )

        ok({ base_form: base_form, mood_modifier: mood_mod["modifier"],
             symmetry: symmetry_call, subject_energy_override: override_applied,
             anchor_required: anchor_required })
      end

      private

      def resolve_symmetry(mood, subject_energy)
        override = rules("arrangement_forms").fetch("subject_energy_override")
        # subject energy wins on symmetry only
        chosen = subject_energy == "dynamic" ? "off_kilter" : "symmetric"
        conflicts = (mood == "calm_ordered" && chosen == "off_kilter") ||
                    (mood == "bold_active"  && chosen == "symmetric")
        [chosen, conflicts]
      end
    end
  end
end
