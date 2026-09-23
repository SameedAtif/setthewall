module Agents
  # P2_6 — the composite is a deterministic paste, but only a look at the finished image can catch
  # a placement that reads as wrong: art jammed against the ceiling, overlapping the furniture, or
  # off-centre. PlacementQa bounds the geometry numerically; this agent judges the result.
  class CompositeQa < Base
    agent id: "composite_qa", covers: %w[P2_6]

    def evaluate
      path = data["composite_url"]
      return [blocking("No composite image to inspect.",
                       [cite("eye_level.rules.ceiling_clearance")])] if path.blank?

      result = Pipeline::Json.normalize(
        RubyLLM.chat(model: Pipeline::VISION_MODEL)
               .with_schema(Schemas::Qa::CompositePlacementSchema)
               .ask(prompt_text, with: [path]).content
      )

      findings = []
      if result["overlaps_ceiling"]
        findings << blocking(
          "The artwork touches or crosses the ceiling in the composite — it reads as hung too high.",
          [cite("eye_level.rules.ceiling_clearance")], { overlaps_ceiling: true })
      end
      if result["overlaps_furniture"]
        findings << blocking(
          "The artwork touches or overlaps the furniture below it.",
          [cite("eye_level.rules.by_room_type.seated_room")], { overlaps_furniture: true })
      end
      if result["centered"] == false
        findings << advisory(
          "The artwork is not horizontally centered over the furniture.",
          [cite("eye_level.rules.by_room_type.seated_room")], { centered: false })
      end

      if findings.empty?
        findings << pass("Composite reads correctly: clear of the ceiling and furniture, centered.",
                         [cite("eye_level.rules.ceiling_clearance")])
      end
      findings
    end

    private

    def prompt_text
      <<~P
        A framed artwork has been pasted onto a room mockup. Judge ONLY its placement on the wall:
        - overlaps_ceiling: does the top edge of the artwork touch or cross the ceiling line?
        - overlaps_furniture: does the bottom edge touch or overlap the sofa/furniture below it?
        - centered: is the artwork horizontally centered over the furniture?
        Report false for overlaps_ceiling/overlaps_furniture when there is a clear gap. Do not
        judge the artwork's own quality or how photorealistic the mockup is.
      P
    end
  end
end
