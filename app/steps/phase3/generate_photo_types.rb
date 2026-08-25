module Steps
  module Phase3
    class GeneratePhotoTypes < Steps::Base
      step id: "P3_1b",
           mechanism: :image_gen,
           ownership: "[AGENT-ASSISTED — human confirms]"

      # context: { skip_types: [], provided_urls: { studio:, detail:, scale:, ... } }
      def perform
        return ok({ photos: piece.photos || {} }) if context[:confirmed]

        photo_rules = rules("etsy_photos").rules
        required    = photo_rules["required_types"]   # [studio, lifestyle, detail]
        photos      = piece.photos || {}
        # Lifestyle already exists from Phase 2
        photos["lifestyle"] ||= piece.composite_url

        # Merge any human-provided URLs
        photos.merge!(context.fetch(:provided_urls, {}))

        # Which required types are still missing?
        missing_required = required.map(&:to_s) - photos.keys.select { |k| photos[k].present? }
        skip = Array(context[:skip_types]).map(&:to_s)
        missing_required -= skip

        if missing_required.empty?
          piece.update!(photos: photos)
          return needs_human(
            "All required photo types present (studio, lifestyle, detail). Confirm before " \
            "moving to Step 2 (hero selection). If any provided URL is AI-generated, review " \
            "quality before publish.",
            { photos: photos }
          )
        end

        # Generate what's missing via the image-gen adapter (module 03)
        adapter = ImageGeneration::Adapter.build
        generated_urls = {}
        missing_required.each do |type|
          prompt = build_photo_prompt(type)
          result = adapter.generate(prompt: prompt, n: 1)
          generated_urls[type] = result.urls.first
        end

        photos.merge!(generated_urls.compact)
        piece.update!(photos: photos)

        needs_human(
          "Generated #{generated_urls.keys.join(', ')} via #{adapter.name}. " \
          "AI-generated studio/detail shots are still mixed — REVIEW quality before " \
          "confirming. If any is unusable, upload a real photo and re-run this step.",
          { photos: photos, generated_types: generated_urls.keys }
        )
      end

      private

      def build_photo_prompt(type)
        case type
        when "studio"
          "Studio product photo: a %s framed print (frame material: %s, contour: %s), " \
          "on a plain neutral background with soft even studio lighting. No room, no props." %
            [piece.content_type, piece.frame_material_category, piece.frame_contour]
        when "detail"
          "Close-up detail photo of the corner of a framed print — showing print texture, paper " \
          "grain, and frame edge/corner. Frame: %s. Sharp focus, natural lighting." %
            piece.frame_material_category
        else
          # scale, group, packaging: caller should provide, not generate
          raise "Unexpected photo type for generation: #{type}"
        end
      end
    end
  end
end
