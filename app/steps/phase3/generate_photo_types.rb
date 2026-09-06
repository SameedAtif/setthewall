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
        candidates = {}
        missing_required.each do |type|
          prompt = build_photo_prompt(type)
          result = adapter.generate(prompt: prompt, n: 2, style_reference: [piece.chosen_url])
          urls = result.urls.compact
          generated_urls[type] = urls.first
          candidates[type] = urls
        end

        photos.merge!(generated_urls.compact)
        piece.update!(photos: photos)

        needs_human(
          "Generated #{generated_urls.keys.join(', ')} via #{adapter.name}. " \
          "AI-generated studio/detail shots are still mixed — REVIEW quality before " \
          "confirming. If any is unusable, upload a real photo and re-run this step.",
          { photos: photos, generated_types: generated_urls.keys, candidates: candidates }
        )
      end

      private

      def build_photo_prompt(type)
        prompt("p3_step1b_photo_types",
               photo_type: type,
               photo_type_instructions: photo_type_instructions(type),
               frame_material_category: piece.frame_material_category,
               frame_contour: piece.frame_contour)
      end

      def photo_type_instructions(type)
        case type
        when "studio"
          "Dead-on product shot: camera facing the print squarely, print centered and filling " \
          "roughly 70% of the frame, plain light-neutral background, soft even studio lighting. " \
          "No room, no props."
        when "detail"
          "Extreme close-up macro on ONE corner of the framed print, camera at a 3/4 angle to " \
          "catch the frame edge and corner joint. Show print/paper texture. The full print must " \
          "NOT be visible — this is a corner crop. Sharp focus, natural side light."
        else
          # scale, group, packaging: caller should provide, not generate
          raise "Unexpected photo type for generation: #{type}"
        end
      end
    end
  end
end
