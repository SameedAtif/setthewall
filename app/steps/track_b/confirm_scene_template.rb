module Steps
  module TrackB
    class ConfirmSceneTemplate < Steps::Base
      step id: "B0", mechanism: :human, ownership: "[HUMAN ONLY]"

      def perform
        template_path = Pipeline::KB_ROOT.join(context.fetch(:scene_image))
        template_yml  = Pipeline::KB_ROOT.join("scene_templates",
                                               "#{context.fetch(:scene_template_id)}.yml")

        missing = []
        missing << "image asset (#{template_path})" unless template_path.exist?
        missing << "template metadata (#{template_yml})" unless template_yml.exist?

        if missing.any?
          return fail_step(
            "Scene template is not fully set up. Missing: #{missing.join(', ')}. Track B cannot " \
            "run against a template that hasn't been built and calibrated first — see " \
            "scene_templates/README.md.",
            { missing: missing }
          )
        end

        needs_human(
          "Confirm this scene template is a REUSABLE mockup you will use across many pieces — " \
          "not a one-off generated room. Validation: template files exist and are versioned; the " \
          "measurement metadata (pixels_per_inch, furniture edges, etc.) is filled in.",
          { template_id: context.fetch(:scene_template_id) }
        )
      end
    end
  end
end
