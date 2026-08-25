module Steps
  module Phase2
    class LoadStyleSpec < Steps::Base
      step id: "P2_0", mechanism: :human, ownership: "[HUMAN ONLY]"

      # context: { style_slug: }
      def perform
        spec = KnowledgeBase::StyleSpec.load(context.fetch(:style_slug))
        spec.validate!    # raises IncompleteSpecError if any axis is blank or out-of-range

        ok({ style_slug: spec.slug, scenes: spec.scene_ids },
           message: "Style spec loaded and validated. #{spec.scene_ids.size} scene(s) ready.")
      rescue KnowledgeBase::IncompleteSpecError => e
        fail_step("Style spec is incomplete: #{e.message}. Cannot run daily pipeline against " \
                  "a spec with blank axes.", { style_slug: context[:style_slug] })
      end
    end
  end
end
