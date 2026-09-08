module Steps
  module Phase2
    class LoadStyleSpec < Steps::Base
      step id: "P2_0", mechanism: :human, ownership: "[HUMAN ONLY]"

      # context: { style_slug: }
      def perform
        spec = KnowledgeBase::StyleSpec.load(context.fetch(:style_slug))
        spec.validate!    # raises IncompleteSpecError if any axis is blank or out-of-range

        if (mismatch = fulfillment_mismatch(spec))
          return fail_step(mismatch[:message], mismatch)
        end

        ok({ style_slug: spec.slug, scenes: spec.scene_ids },
           message: "Style spec loaded and validated. #{spec.scene_ids.size} scene(s) ready.")
      rescue KnowledgeBase::IncompleteSpecError => e
        fail_step("Style spec is incomplete: #{e.message}. Cannot run daily pipeline against " \
                  "a spec with blank axes.", { style_slug: context[:style_slug] })
      end

      private

      def fulfillment_mismatch(spec)
        expected = spec.production_model["fulfillment_type"]
        actual   = piece&.fulfillment_type
        return nil if actual.blank? || actual == expected

        { message: "production_model.fulfillment_type (#{expected}) does not match the piece's " \
                   "fulfillment_type (#{actual}).",
          expected: expected, actual: actual }
      end
    end
  end
end
