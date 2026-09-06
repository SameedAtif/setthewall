module Agents
  # C1, C2_finalists, P3_1b — image conformance. The knowledge base is silent on image *quality*,
  # so this agent judges CONFORMANCE only: does each candidate read as the locked axes, and does it
  # sit inside the visual range of A1's curated reference set. Merit stays at C2_chosen (Tier 3).
  class ImageQa < Base
    agent id: "image_qa", covers: %w[C1 C2 C2_finalists P3_1b]

    def evaluate
      urls = candidate_urls
      return [blocking("No candidate images to evaluate.", [cite("qa_rules.rules.image_qa.scope")])] if urls.empty?

      result = Pipeline::Json.normalize(
        RubyLLM.chat(model: Pipeline::VISION_MODEL)
               .with_schema(Schemas::Qa::ImageConformanceSchema)
               .ask(prompt_text, with: (urls + reference_urls).first(20)).content
      )

      findings = []
      Array(result["per_image"]).each do |img|
        mismatches = Array(img["axis_mismatches"])
        findings << if mismatches.empty?
          pass("Candidate #{img['index']} conforms to the locked axes.",
               [cite("qa_rules.rules.image_qa.conformance_axes")])
        else
          advisory("Candidate #{img['index']} does not read as #{mismatches.join(', ')}.",
                   [cite("qa_rules.rules.image_qa.conformance_axes")],
                   { index: img["index"], mismatches: mismatches })
        end
      end

      violations = Array(result["constraint_violations"])
      if violations.any?
        findings << blocking("Negative-prompt constraints violated: #{violations.join(', ')}.",
                             [cite("generation_constraints.rules.constraints.negative_prompt")],
                             { violations: violations })
      end

      conforming = Array(result["per_image"]).count { |i| Array(i["axis_mismatches"]).empty? }
      if conforming.zero? && Array(result["per_image"]).any?
        findings << blocking(
          "No candidate in the batch conforms to the locked axes. Regenerating is the correct " \
          "move, not culling the least-wrong one.",
          [cite("decision_rules.rules.steps.C2_finalists.on_unresolved_input")])
      end

      return [pass("All candidates conform to the locked axes.",
                   [cite("qa_rules.rules.image_qa.conformance_axes")])] if findings.empty?

      findings
    end

    private

    def prompt_text
      <<~P
        You are checking CONFORMANCE, not quality. Do not judge whether an image is good, beautiful,
        or marketable. Judge only whether it matches the locked specification.

        Locked axes: mood=#{piece_axis(:mood)}, content_type=#{piece_axis(:content_type)},
        color_role=#{piece_axis(:color_role)}, frame_form=#{piece_axis(:frame_form)}.

        The final images are the curated REFERENCE set for this style. Candidates should sit inside
        their visual range. For each candidate, list which of the locked axes it fails to read as
        (empty list means it conforms), and report any negative-prompt constraint violation.
        Aesthetic preference is out of scope.
      P
    end

    def candidate_urls
      case @step_id
      when "C1", "C2_finalists" then Array(@run.piece_record&.candidate_urls)
      when "P3_1b" then (@run.piece_record&.photos || {}).values.compact
      else []
      end
    end

    def reference_urls
      Array(@run.dossier_data.dig("A1", "curated_images")).first(4)
    end

    def piece_axis(axis)
      @run.piece_record&.public_send(axis)
    end
  end
end
