require "rails_helper"

RSpec.describe Workflow::TrackRunner do
  def validation_content
    { "breadth_assessment" => "single_coherent_style",
      "findings" => [],
      "cross_check_attempts" => ["Pinterest Trends search"],
      "single_recommended_focus" => "Ensō minimalist print",
      "recommendation_reasoning" => "best demand-to-competition ratio",
      "methodology_caveats" => "" }
  end

  def reference_set_content
    { "images" => [
      { "url" => "u1", "source_type" => "retailer", "source_name" => "s1",
        "attributing_sources" => %w[a b], "shot_type" => "in_situ" },
      { "url" => "u2", "source_type" => "retailer", "source_name" => "s1",
        "attributing_sources" => %w[a b], "shot_type" => "closeup" }
    ], "closeup_count" => 1, "total_count" => 2, "sources_used" => %w[a b] }
  end

  describe "Track A" do
    def start_track_a
      described_class.start(track: "track_a", style_slug: "coastal-minimal", style_name: "Coastal Minimal")
    end

    it "runs A0 and opens a gate" do
      stub_reasoned_runner(content: validation_content) do
        run = start_track_a
        expect(run.status).to eq("awaiting_human")
        expect(run.current_step).to eq("A0")
        expect(run.human_gates.open.count).to eq(1)
        expect(run.human_gates.open.first.step_id).to eq("A0")
      end
    end

    it "threads A0's narrowed pick forward as the style name" do
      fragmented = validation_content.merge(
        "breadth_assessment" => "fragments_into_substyles",
        "single_recommended_focus" => "Ensō print"
      )
      run = nil
      stub_reasoned_runner(content: fragmented) do
        run = start_track_a
        gate = run.human_gates.open.last
        gate.update!(status: "approved", reviewer_decision: gate.agent_proposal, closed_at: Time.current)
        stub_reasoned_runner(content: reference_set_content) do
          described_class.resume(gate)
        end
      end

      expect(run.reload.context["style_name"]).to eq("Ensō print")
      expect(run.current_step).to eq("A1")
    end

    it "routes a return_to_a1 A2 gate back to A1 instead of advancing" do
      run = create(:track_run, status: "awaiting_human", current_step: "A2",
                               context: { "style_slug" => "s", "style_name" => "X",
                                          "reference_images" => %w[u1 u2 u3] })
      gate = create(:human_gate, piece_record: nil, track_run: run, step_id: "A2", status: "approved",
                                 agent_proposal: { "result" => { "mood" => "mixed" },
                                                   "recommended_action" => "return_to_a1" }.to_json)

      stub_reasoned_runner(content: reference_set_content) do
        described_class.resume(gate)
      end

      expect(run.reload.current_step).to eq("A1")
      expect(run.context["mood"]).to be_nil
    end

    it "threads context through the full track to a locked spec" do
      slug = "coastal-minimal"
      stub_reasoned_runner(content: validation_content) do
        run = start_track_a

        # A0 → approve → A1
        gate = run.human_gates.open.last
        gate.update!(status: "approved", reviewer_decision: gate.agent_proposal, closed_at: Time.current)
        stub_reasoned_runner(content: reference_set_content) do
          described_class.resume(gate)
        end
        expect(run.reload.current_step).to eq("A1")

        # A1 → approve → A2 (mood)
        gate = run.human_gates.open.last
        gate.update!(status: "approved", reviewer_decision: gate.agent_proposal, closed_at: Time.current)
        stub_llm(content: { "mood" => "calm_ordered", "marker_scores" => [],
                           "markers_supporting_chosen_mood" => 3, "clearly_supporting_images" => 5 }) do
          described_class.resume(gate)
        end
        expect(run.reload.current_step).to eq("A2")

        # A2 → approve → A3 (content type)
        gate = run.human_gates.open.last
        gate.update!(status: "approved", reviewer_decision: gate.agent_proposal, closed_at: Time.current)
        stub_llm(content: { "content_type" => "minimalist_modern", "predicted_contour" => "flush_level_plane",
                            "observed_contour" => "flush_level_plane", "contour_cross_check_passed" => true, "reasoning" => "" }) do
          described_class.resume(gate)
        end
        expect(run.reload.current_step).to eq("A3")

        # A3 → approve → A4 (frame form)
        gate = run.human_gates.open.last
        gate.update!(status: "approved", reviewer_decision: gate.agent_proposal, closed_at: Time.current)
        stub_llm(content: { "frame_form" => "angular", "consistency" => "consistent",
                            "tiebreaker_used" => false, "reasoning" => "" }) do
          described_class.resume(gate)
        end
        expect(run.reload.current_step).to eq("A4")

        # A4 → approve → A5 (lock) → confirm → complete
        gate = run.human_gates.open.last
        gate.update!(status: "approved", reviewer_decision: gate.agent_proposal, closed_at: Time.current)
        described_class.resume(gate)
        expect(run.reload.current_step).to eq("A5")

        gate = run.human_gates.open.last
        gate.update!(status: "approved", reviewer_decision: gate.agent_proposal, closed_at: Time.current)
        described_class.resume(gate)

        expect(run.reload.status).to eq("complete")
        expect(KnowledgeBase::StyleSpec.load(slug).style_level[:mood]).to eq("calm_ordered")
        expect(KnowledgeBase::StyleSpec.load(slug).style_level[:content_type]).to eq("minimalist_modern")
        expect(KnowledgeBase::StyleSpec.load(slug).style_level[:frame_form]).to eq("angular")
      end
    ensure
      File.delete(Pipeline::KB_ROOT.join("style_specs/coastal-minimal.yml").to_s) rescue nil
    end
  end

  describe "Track B" do
    it "runs B0 through B7, threading scene axes" do
      slug = "tb-style"
      scene_id = "tb-scene"
      build_scene_template(scene_id)
      KnowledgeBase::StyleSpecWriter.create_or_update_style_level(
        slug: slug, name: "TB", mood: "calm_ordered",
        content_type: "minimalist_modern", frame_form: "angular"
      )

      run = described_class.start(track: "track_b", style_slug: slug, scene_template_id: scene_id,
                                  scene_image: "scene_templates/assets/#{scene_id}.png")
      expect(run.current_step).to eq("B0")
      expect(run.status).to eq("awaiting_human")

      # B0 → approve → B1…B5 auto-advance (stub vision), B6 needs content_type from the spec
      gate = run.human_gates.open.last
      gate.update!(status: "approved", reviewer_decision: gate.agent_proposal, closed_at: Time.current)

      vision_content = {
        Schemas::TrackB::WallConditionSchema => { "wall_condition" => "neutral", "borderline" => false, "reasoning" => "" },
        Schemas::TrackB::FurnitureWeightSchema => { "furniture_weight" => "light", "borderline" => false, "reasoning" => "" },
        Schemas::TrackB::RoomTypeSchema => { "room_type" => "no_furniture_wall", "reasoning" => "" },
        Schemas::TrackB::RoomShapeSchema => { "room_shape" => "none", "borderline" => false, "reasoning" => "" },
        Schemas::TrackB::SpaceMathSchema => { "space_math" => "split_wall", "reasoning" => "" },
        Schemas::TrackB::ColorRoleObservationSchema => { "candidate_role" => "line_only", "observed_color_state" => "monochrome", "reasoning" => "" }
      }
      stub_llm(contents: vision_content) do
        described_class.resume(gate)
      end

      # B1–B5 auto-advanced; B6 returns ok (candidate == line_only for minimalist_modern)
      expect(run.reload.current_step).to eq("B7")
      expect(run.status).to eq("awaiting_human")
      expect(run.context["wall_condition"]).to eq("neutral")
      expect(run.context["space_math"]).to eq("split_wall")

      # B7 → approve (confirm) → writes scene axes → complete
      gate = run.human_gates.open.last
      gate.update!(status: "approved", reviewer_decision: gate.agent_proposal, closed_at: Time.current)
      described_class.resume(gate)

      expect(run.reload.status).to eq("complete")
      scene = KnowledgeBase::StyleSpec.load(slug).scene(scene_id)
      expect(scene.wall_condition).to eq("neutral")
      expect(scene.space_math).to eq("split_wall")
    ensure
      File.delete(Pipeline::KB_ROOT.join("style_specs/tb-style.yml").to_s) rescue nil
    end
  end

  describe "failure handling" do
    it "marks the run failed when a step fails" do
      run = TrackRun.create!(track: "track_a", style_slug: "fail-style", status: "running",
                             context: { "style_slug" => "fail-style", "style_name" => "Fail" })
      stub_singleton(Search::ReasonedRunner, :call, ->(**) { raise Search::NoSearchPerformedError }) do
        described_class.advance(run)
      end
      expect(run.reload.status).to eq("failed")
    end
  end

  describe "terminal handling" do
    it "marks the run complete when a non-confirm step has no successor" do
      run = create(:track_run, status: "awaiting_human", current_step: "A4")
      gate = create(:human_gate, track_run: run, step_id: "A4", status: "approved")
      stub_singleton(described_class, :next_step, ->(*, **) { nil }) do
        described_class.resume(gate)
      end
      expect(run.reload.status).to eq("complete")
    end

    it "marks the run complete when the final step returns ok" do
      run = create(:track_run, status: "running", current_step: "A5")
      ok_result = Steps::StepResult.new(status: :ok, data: {}, message: nil)
      stub_singleton(Workflow::StepDispatcher, :call, ->(**) { ok_result }) do
        described_class.advance(run)
      end
      expect(run.reload.status).to eq("complete")
    end
  end
end
