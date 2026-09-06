module Agents
  # A2, A3, A4, B1–B6 — the classification steps. Its job is largely to *refuse*: catch a mixed
  # mood (unresolved_input), a failed contour cross-check, a no-safe-default room type, and the
  # B6 override/conflict signals, rather than letting a wrong value propagate downstream.
  class AxisQa < Base
    agent id: "axis_qa", covers: %w[A2 A3 A4 B1 B2 B3 B4 B5 B6]

    def evaluate
      d = data
      r = d["result"] || d
      case @step_id
      when "A2" then mood(r)
      when "A3" then content_type(r)
      when "A4" then frame_form(r)
      when "B3" then room_type(r)
      when "B6" then color_role(d)
      else           borderline(r)
      end
    end

    private

    def mood(r)
      cites = [cite("mood_markers.rules.scoring.mixed_result"), cite("mood_markers.rules.validation")]
      return [blocking(
        "Mood scorecard is mixed. Per the rule, a mixed scorecard means the reference set is not " \
        "focused enough — narrow it and return to A1. Do NOT pick the closer of the two moods.",
        cites)] if r["mood"] == "mixed"

      markers = r["markers_supporting_chosen_mood"].to_i
      images  = r["clearly_supporting_images"].to_i
      need_m  = qa_rules.dig("a2", "required_markers").to_i
      need_i  = qa_rules.dig("a2", "required_images").to_i
      return [blocking(
        "Mood proposed as #{r['mood']} but the validation bar was not met " \
        "(#{markers}/#{need_m} markers, #{images}/#{need_i} clearly supporting images).",
        cites, { markers: markers, images: images })] if markers < need_m || images < need_i

      [pass("Mood #{r['mood']} supported by #{images} images across #{markers} of the four markers.",
            cites)]
    end

    def content_type(r)
      c = [cite("content_type.rules.validation")]
      return [blocking(
        "Frame-contour cross-check failed (predicted #{r['predicted_contour']}, observed " \
        "#{r['observed_contour']}). Per the rule, a contour mismatch means the content-type call " \
        "is probably wrong.", c)] unless r["contour_cross_check_passed"]

      [pass("Content type #{r['content_type']} passes the contour cross-check.", c)]
    end

    def frame_form(r)
      c = [cite("frame_form.rules.determination.tiebreaker")]
      return [advisory("Framing was mixed across references; resolved by the mood tiebreaker. " \
                       "Any later change to mood invalidates this.", c)] if r["consistency"] == "mixed"

      [pass("Frame form #{r['frame_form']} was consistent across references.", c)]
    end

    def room_type(r)
      c = [cite("borderline_defaults.rules.room_type")]
      return [blocking(
        "Room type came back ambiguous and this axis has no safe default: the three eye-level " \
        "formulas are not interchangeable, so a wrong read produces a plausible-looking but " \
        "wrong composite at P2_6.", c)] if r["room_type"] == "ambiguous"

      [pass("Room type #{r['room_type']} read unambiguously.", c)]
    end

    def color_role(d)
      c = [cite("color_role_observation.rules"), cite("decision_rules.rules.steps.B6")]
      conflicts = Array(d["conflicts"])
      return [blocking("Cross-check conflicts: #{conflicts.join('; ')}. Resolve explicitly rather " \
                       "than defaulting to whichever was decided first.", c)] if conflicts.any?

      if d["override_pending"]
        return [blocking("The minimalist_modern default (line_only, p. 97) overrides the observed " \
                         "candidate. This is a catalog-strategy call the agent cannot make.", c)]
      end

      [pass("Colour role #{d['color_role']} clears the B6 cross-check.", c)]
    end

    def borderline(r)
      c = [cite("borderline_defaults.rules")]
      return [advisory("Axis was borderline; the safe-fail default was applied. This must surface " \
                       "at B7 before the scene is locked.", c, { resolved_by_default: true })] if r["borderline"]

      [pass("Axis read unambiguously.", c)]
    end
  end
end
