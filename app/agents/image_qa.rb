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

        if img["subject_conforms"] == false
          findings << advisory("Candidate #{img['index']} does not depict its specified subject.",
                               [cite("qa_rules.rules.image_qa.conformance_axes")],
                               { index: img["index"] })
        end

        essence_misses = %w[palette surface motif].select { |axis| img["#{axis}_conforms"] == false }
        if essence_misses.any?
          findings << advisory(
            "Candidate #{img['index']} does not match the reference essence (#{essence_misses.join(', ')}).",
            [cite("qa_rules.rules.image_qa.conformance_axes")],
            { index: img["index"], mismatches: essence_misses }
          )
        end

        similarity = img["max_reference_similarity"].to_i
        if similarity >= max_reference_similarity
          findings << blocking(
            "Candidate #{img['index']} is a near-replica of a single reference (#{similarity}% similar).",
            [cite("qa_rules.rules.image_qa.conformance_axes")],
            { index: img["index"], max_reference_similarity: similarity }
          )
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

      unless diverse_enough?(Array(result["per_image"]))
        findings << advisory(
          "The batch is not compositionally diverse — candidates repeat the same layout/transition.",
          [cite("qa_rules.rules.image_qa.conformance_axes")]
        )
      end

      write_scores(result)

      return [pass("All candidates conform to the locked axes.",
                   [cite("qa_rules.rules.image_qa.conformance_axes")])] if findings.empty?

      findings
    end

    private

    def max_reference_similarity = ENV.fetch("QA_MAX_REFERENCE_SIMILARITY", 80).to_i
    def min_diversity = ENV.fetch("QA_MIN_DIVERSITY", 0.3).to_f

    def diverse_enough?(images)
      return true if images.size < 2

      signatures = images.map { |img| descriptor_signature(img) }.reject { |s| s.delete("|").blank? }
      return true if signatures.empty?

      # 0 when every candidate shares one layout, 1 when they are all distinct.
      (signatures.uniq.size - 1).to_f / (signatures.size - 1) >= min_diversity
    end

    def descriptor_signature(img)
      d = img["descriptors"] || {}
      %w[transition_position transition_orientation seam_presence motif_region_shape]
        .map { |key| d[key].to_s }.join("|")
    end

    # Append the QA scores to the C1 prompt log so a batch's prompt, images and scores live in one
    # record. Best-effort — QA must never fail because the log is missing or unwritable.
    def write_scores(result)
      path = data["image_prompt_log"]
      return if path.blank? || !File.exist?(path)

      File.open(path, "a") do |file|
        Array(result["per_image"]).each do |img|
          file.puts(JSON.generate(
            "type" => "qa", "index" => img["index"],
            "max_reference_similarity" => img["max_reference_similarity"],
            "palette_conforms" => img["palette_conforms"],
            "surface_conforms" => img["surface_conforms"],
            "motif_conforms" => img["motif_conforms"],
            "descriptors" => img["descriptors"]
          ))
        end
      end
    rescue StandardError
      nil
    end

    def prompt_text
      <<~P
        You are checking CONFORMANCE, not quality. Do not judge whether an image is good, beautiful,
        or marketable. Judge only whether it matches the locked specification.

        Locked axes: mood=#{piece_axis(:mood)}, content_type=#{piece_axis(:content_type)},
        color_role=#{piece_axis(:color_role)}, frame_form=#{piece_axis(:frame_form)}.

        #{subject_lines}

        #{essence_lines}

        The final images are the curated REFERENCE set for this style. Candidates should sit inside
        their visual range. For each candidate, list which of the locked axes it fails to read as
        (empty list means it conforms), and report any negative-prompt constraint violation.
        Aesthetic preference is out of scope.
      P
    end

    # The typed reference essence (A1b) so palette/surface/motif conformance is judged against the
    # same structured facts the generator was grounded in.
    def essence_lines
      essence = @context[:reference_essence] || @context["reference_essence"] || {}
      return "No structured reference essence was available." if essence.blank?

      lines = []
      lines << "medium: #{essence['medium']}" if essence["medium"].present?
      lines << "palette: #{essence['palette']}" if essence["palette"].present?
      lines << "surface treatment: #{essence['surface_treatment']}" if essence["surface_treatment"].present?
      motifs = Array(essence["motif_vocabulary"]).reject(&:blank?)
      lines << "motif vocabulary: #{motifs.join('; ')}" if motifs.any?
      return "No structured reference essence was available." if lines.empty?

      "Reference essence to judge against (report per-candidate palette/surface/motif conformance):\n" +
        lines.map { |line| "  #{line}" }.join("\n")
    end

    def subject_lines
      subjects = Array(@run.piece_record&.candidate_subjects).compact
      return "No subject was specified per candidate." if subjects.empty?

      "Each candidate was specified a subject (1-based): " +
        subjects.each_with_index.map { |s, i| "##{i + 1}: #{s}" }.join(", ") +
        ". Report subject_conforms=false when a candidate does not depict its specified subject."
    end

    def candidate_urls
      case @step_id
      when "C1" then Array(@run.piece_record&.candidate_urls)
      when "C2", "C2_finalists"
        # At the cull, evaluate the finalists that carry forward (fall back to the batch).
        finalists = Array(@run.piece_record&.finalist_urls)
        finalists.presence || Array(@run.piece_record&.candidate_urls)
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
