module Steps
  module TrackB
    class LockSceneEntry < Steps::Base
      step id: "B7", mechanism: :human, ownership: "[HUMAN ONLY]"

      # context: { style_slug:, scene_template_id:, scene_name:, template_ref:,
      #            axes: { wall_condition:, furniture_weight:, room_type:, room_shape:,
      #                    space_math: },
      #            confirmed: }
      def perform
        axes = context.fetch(:axes)

        unless context[:confirmed]
          return needs_human(
            "Lock these five values as final for this scene template?\n" \
            "  wall_condition:   #{axes[:wall_condition]}\n" \
            "  furniture_weight: #{axes[:furniture_weight]}\n" \
            "  room_type:        #{axes[:room_type]}\n" \
            "  room_shape:       #{axes[:room_shape]}\n" \
            "  space_math:       #{axes[:space_math]}\n\n" \
            "Validation (from the source doc): could someone who has never seen the scene photo " \
            "make correct placement/frame decisions from these five values alone? If not, a value " \
            "is under-specified — go back and sharpen it.",
            { axes: axes }
          )
        end

        scene = KnowledgeBase::SceneSpecWriter.write_scene_axes(
          style_slug:      context.fetch(:style_slug),
          scene_id:        context.fetch(:scene_template_id),
          scene_name:      context.fetch(:scene_name),
          template_ref:    context.fetch(:template_ref),
          axes:            axes
        )

        ok({ style_slug: context.fetch(:style_slug), scene_id: scene.id },
           message: "Scene axes locked. COMMIT knowledge_base/style_specs/" \
                    "#{context.fetch(:style_slug)}.yml to git before running any daily pipeline " \
                    "against it.")
      end
    end
  end
end
