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
        if context[:color_role_override].present?
          essence["color_role"] = context[:color_role_override].to_s
          essence["color_role_ambiguous"] = false
        end

        if essence["palette"].blank? && essence["surface_treatment"].blank? &&
           essence["motif_vocabulary"].empty?
          return fail_step("A1b could not read an essence from the reference images.", { result: raw })
        end

        ok({ essence: essence, image_count: images.size }, message: color_role_message(essence))
      end

      def color_role_message(essence)
        base = "Reference essence distilled from the reference images. Review the palette, surface " \
               "treatment and motif vocabulary — this drives generation and QA."
        if essence["color_role"].present?
          "#{base} Colour role: #{essence['color_role']} (votes: #{essence['color_role_tally'].inspect})."
        elsif essence["color_role_ambiguous"]
          "#{base} COLOUR ROLE IS AMBIGUOUS — the images split across " \
            "#{essence['color_role_tally'].inspect}; choose one at this gate."
        else
          base
        end
      end

      private

      def image_limit
        ENV.fetch("A1B_IMAGE_LIMIT", DEFAULT_IMAGE_LIMIT).to_i.clamp(1, 20)
      end

      def normalize_essence(raw)
        outliers = Array(raw["outlier_indices"]).map(&:to_i)
        image_roles = Array(raw["image_color_roles"]).filter_map do |entry|
          next unless entry.is_a?(Hash)

          index = entry["index"].to_i
          role = entry["color_role"].to_s
          next if role.blank? || outliers.include?(index)

          { "index" => index, "color_role" => role }
        end
        tally = image_roles.map { |role| role["color_role"] }.tally

        {
          "medium" => raw["medium"].to_s,
          "palette" => raw["palette"].to_s,
          "palette_character" => raw["palette_character"].to_s,
          "surface_treatment" => raw["surface_treatment"].to_s,
          "motif_vocabulary" => Array(raw["motif_vocabulary"]).map(&:to_s).reject(&:blank?),
          "styling" => raw["styling"].to_s,
          "outlier_indices" => outliers,
          "field_evidence" => Array(raw["field_evidence"]),
          "image_color_roles" => image_roles,
          "color_role_tally" => tally
        }.merge(derive_color_role(tally))
      end

      # A single most-common role wins; a tie for most-common is left for the human at the gate.
      def derive_color_role(tally)
        return { "color_role" => nil, "color_role_ambiguous" => true } if tally.empty?

        top = tally.values.max
        winners = tally.select { |_role, count| count == top }.keys
        return { "color_role" => winners.first, "color_role_ambiguous" => false } if winners.size == 1

        { "color_role" => nil, "color_role_ambiguous" => true }
      end
    end
  end
end
