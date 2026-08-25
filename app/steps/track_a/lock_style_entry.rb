module Steps
  module TrackA
    class LockStyleEntry < Steps::Base
      step id: "A5", mechanism: :human, ownership: "[HUMAN ONLY]"

      # context: { style_slug:, style_name:, mood:, content_type:, frame_form:, confirmed: }
      def perform
        unless context[:confirmed]
          return needs_human(
            "Lock these three values as final for this style?\n" \
            "  mood:         #{context[:mood]}\n" \
            "  content_type: #{context[:content_type]}\n" \
            "  frame_form:   #{context[:frame_form]}\n\n" \
            "Validation: could someone unfamiliar with the style read these three values alone " \
            "and generate a reasonably on-style prompt? If not, they are too vague — return to A1 " \
            "and narrow the reference set.",
            context.slice(:mood, :content_type, :frame_form)
          )
        end

        spec = KnowledgeBase::StyleSpecWriter.create_or_update_style_level(
          slug:         context.fetch(:style_slug),
          name:         context.fetch(:style_name),
          mood:         context.fetch(:mood),
          content_type: context.fetch(:content_type),
          frame_form:   context.fetch(:frame_form)
        )

        ok({ style_spec_path: spec.path.to_s, slug: spec.slug },
           message: "Style-level axes locked. COMMIT knowledge_base/style_specs/#{spec.slug}.yml " \
                    "to git before running any pipeline against it.")
      end
    end
  end
end
