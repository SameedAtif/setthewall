module Steps
  module TrackA
    # A1b — a vision pass over A1's curated reference images that distils their typed essence
    # (medium, palette, surface treatment, motif vocabulary, styling). The result is stored in the
    # run and written into the style spec by A5, then consumed by C1 generation and ImageQa, so the
    # generator and the conformance check work from the same structured facts.
    class DistillReferenceEssence < Steps::Base
      step id: "A1b", mechanism: :llm_vision, ownership: "[AGENT-ASSISTED — human curates]"

      DEFAULT_IMAGE_LIMIT = 8

      def perform
        urls = Array(context[:reference_images]).first(image_limit)
        return fail_step("A1b has no reference images — run A1 first.", {}) if urls.empty?

        images = localize_images(urls)
        raw = Pipeline::Json.normalize(
          RubyLLM.chat(model: Pipeline::VISION_MODEL)
                .with_schema(Schemas::TrackA::ReferenceEssenceSchema)
                .ask(prompt("a1b_reference_essence"), with: images).content
        )
        essence = normalize_essence(raw)

        if essence["palette"].blank? && essence["surface_treatment"].blank? &&
           essence["motif_vocabulary"].empty?
          return fail_step("A1b could not read an essence from the reference images.", { result: raw })
        end

        ok({ essence: essence, image_count: images.size },
           message: "Reference essence distilled from #{images.size} image(s). Review the palette, " \
                    "surface treatment and motif vocabulary — this drives generation and QA.")
      end

      private

      def image_limit
        ENV.fetch("A1B_IMAGE_LIMIT", DEFAULT_IMAGE_LIMIT).to_i.clamp(1, 20)
      end

      def normalize_essence(raw)
        {
          "medium" => raw["medium"].to_s,
          "palette" => raw["palette"].to_s,
          "surface_treatment" => raw["surface_treatment"].to_s,
          "motif_vocabulary" => Array(raw["motif_vocabulary"]).map(&:to_s).reject(&:blank?),
          "styling" => raw["styling"].to_s,
          "outlier_indices" => Array(raw["outlier_indices"]).map(&:to_i),
          "field_evidence" => Array(raw["field_evidence"])
        }
      end
    end
  end
end
