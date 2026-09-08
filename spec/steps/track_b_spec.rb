require "rails_helper"

RSpec.describe Steps::TrackB do
  def scene_ctx(overrides = {})
    { style_slug: "b-test", scene_template_id: "b-s1", scene_image: "scene_templates/assets/b-s1.png" }.merge(overrides)
  end

  describe "ConfirmSceneTemplate (B0)" do
    it "fails when the template is not set up" do
      result = described_class::ConfirmSceneTemplate.call(piece: nil, context: scene_ctx)
      expect(result).to be_failed
    end

    it "asks for confirmation when the template exists" do
      build_scene_template("b-s1")
      result = described_class::ConfirmSceneTemplate.call(piece: nil, context: scene_ctx)
      expect(result).to be_awaiting_human
    end
  end

  describe "WallCondition (B1)" do
    it "classifies the wall" do
      stub_llm(content: { "wall_condition" => "neutral", "borderline" => false, "reasoning" => "" }) do
        result = described_class::WallCondition.call(piece: nil, context: scene_ctx)
        expect(result).to be_ok
        expect(result.data[:wall_condition]).to eq("neutral")
      end
    end

    it "applies the neutral default on a borderline read" do
      stub_llm(content: { "wall_condition" => "busy", "borderline" => true, "reasoning" => "" }) do
        result = described_class::WallCondition.call(piece: nil, context: scene_ctx)
        expect(result.data[:wall_condition]).to eq("neutral")
      end
    end
  end

  describe "FurnitureWeight (B2)" do
    it "classifies furniture weight" do
      stub_llm(content: { "furniture_weight" => "dark", "borderline" => false, "reasoning" => "" }) do
        result = described_class::FurnitureWeight.call(piece: nil, context: scene_ctx)
        expect(result.data[:furniture_weight]).to eq("dark")
      end
    end

    it "applies the light default on a borderline read" do
      stub_llm(content: { "furniture_weight" => "dark", "borderline" => true, "reasoning" => "" }) do
        result = described_class::FurnitureWeight.call(piece: nil, context: scene_ctx)
        expect(result.data[:furniture_weight]).to eq("light")
      end
    end
  end

  describe "RoomType (B3)" do
    it "classifies the room" do
      stub_llm(content: { "room_type" => "seated_room", "reasoning" => "" }) do
        result = described_class::RoomType.call(piece: nil, context: scene_ctx)
        expect(result).to be_ok
        expect(result.data[:room_type]).to eq("seated_room")
      end
    end

    it "escalates on an ambiguous room" do
      stub_llm(content: { "room_type" => "ambiguous", "ambiguity_reason" => "could be either", "reasoning" => "" }) do
        result = described_class::RoomType.call(piece: nil, context: scene_ctx)
        expect(result).to be_awaiting_human
      end
    end
  end

  describe "RoomShape (B4)" do
    it "classifies the room shape" do
      stub_llm(content: { "room_shape" => "narrow", "borderline" => false, "reasoning" => "" }) do
        result = described_class::RoomShape.call(piece: nil, context: scene_ctx)
        expect(result.data[:room_shape]).to eq("narrow")
      end
    end

    it "applies the none default on a borderline read" do
      stub_llm(content: { "room_shape" => "narrow", "borderline" => true, "reasoning" => "" }) do
        result = described_class::RoomShape.call(piece: nil, context: scene_ctx)
        expect(result.data[:room_shape]).to eq("none")
      end
    end
  end

  describe "SpaceMath (B5)" do
    it "classifies the space math" do
      stub_llm(content: { "space_math" => "single", "reasoning" => "fills the space" }) do
        result = described_class::SpaceMath.call(piece: nil, context: scene_ctx)
        expect(result).to be_ok
        expect(result.data[:space_math]).to eq("single")
      end
    end

    it "escalates when the production model is multi-piece but the scene reads single" do
      slug = "b5-multi-#{SecureRandom.hex(4)}"
      KnowledgeBase::StyleSpecWriter.create_or_update_style_level(
        slug: slug, name: "T", mood: "calm_ordered", content_type: "minimalist_modern",
        frame_form: "angular", production_model: { "fulfillment_type" => "digital", "piece_count" => 6 }
      )
      track_kb_file(Pipeline::KB_ROOT.join("style_specs", "#{slug}.yml"))

      stub_llm(content: { "space_math" => "single", "reasoning" => "fills the space" }) do
        result = described_class::SpaceMath.call(piece: nil, context: scene_ctx(style_slug: slug))
        expect(result).to be_awaiting_human
        expect(result.message).to include("multi-piece")
      end
    end
  end

  describe "ColorRole (B6)" do
    let(:observation) { { "candidate_role" => "saturator", "observed_color_state" => "dominant theme", "reasoning" => "" } }

    it "returns the observation candidate for a non-minimalist style" do
      stub_llm(content: observation) do
        result = described_class::ColorRole.call(piece: nil, context: scene_ctx(content_type: "detailed_representational", wall_condition: "neutral", furniture_weight: "light"))
        expect(result).to be_ok
        expect(result.data[:color_role]).to eq("saturator")
      end
    end

    it "asks the human for the minimalist_modern override" do
      stub_llm(content: observation.merge("candidate_role" => "color_burst")) do
        result = described_class::ColorRole.call(piece: nil, context: scene_ctx(content_type: "minimalist_modern", wall_condition: "neutral", furniture_weight: "light"))
        expect(result).to be_awaiting_human
        expect(result.data[:default_override]).to eq("line_only")
      end
    end

    it "accepts a catalog-strategy override" do
      stub_llm(content: observation.merge("candidate_role" => "color_burst")) do
        result = described_class::ColorRole.call(piece: nil, context: scene_ctx(content_type: "minimalist_modern", wall_condition: "neutral", furniture_weight: "light", catalog_strategy_override: "seasonal color"))
        expect(result).to be_ok
        expect(result.data[:override_reason]).to include("catalog-strategy")
      end
    end

    it "flags a color_burst / busy-wall conflict" do
      stub_llm(content: observation.merge("candidate_role" => "color_burst")) do
        result = described_class::ColorRole.call(piece: nil, context: scene_ctx(content_type: "detailed_representational", wall_condition: "busy", furniture_weight: "light"))
        expect(result).to be_awaiting_human
        expect(result.data[:conflicts]).not_to be_empty
      end
    end

    it "flags a unifier / plain-scene conflict" do
      stub_llm(content: observation.merge("candidate_role" => "unifier")) do
        result = described_class::ColorRole.call(piece: nil, context: scene_ctx(content_type: "detailed_representational", wall_condition: "neutral", furniture_weight: "light"))
        expect(result).to be_awaiting_human
      end
    end

    it "marks the minimalist_modern override as pending" do
      stub_llm(content: observation.merge("candidate_role" => "color_burst")) do
        result = described_class::ColorRole.call(piece: nil, context: scene_ctx(content_type: "minimalist_modern", wall_condition: "neutral", furniture_weight: "light"))
        expect(result).to be_awaiting_human
        expect(result.data[:override_pending]).to be(true)
        expect(result.data[:conflicts]).to eq([])
      end
    end

    it "reports no conflicts and no override on a clean read" do
      stub_llm(content: observation) do
        result = described_class::ColorRole.call(piece: nil, context: scene_ctx(content_type: "detailed_representational", wall_condition: "neutral", furniture_weight: "light"))
        expect(result).to be_ok
        expect(result.data[:conflicts]).to eq([])
        expect(result.data[:override_pending]).to be(false)
      end
    end
  end

  describe "LockSceneEntry (B7)" do
    let(:axes) do
      { wall_condition: "neutral", furniture_weight: "light", room_type: "seated_room",
        room_shape: "none", space_math: "single", color_role: "line_only" }
    end

    it "asks for confirmation before locking" do
      result = described_class::LockSceneEntry.call(piece: nil, context: scene_ctx(axes: axes, scene_name: "S1", template_ref: "t.yml", confirmed: false))
      expect(result).to be_awaiting_human
    end

    it "writes scene axes when confirmed" do
      KnowledgeBase::StyleSpecWriter.create_or_update_style_level(
        slug: "b-test", name: "T", mood: "calm_ordered",
        content_type: "minimalist_modern", frame_form: "angular")
      track_kb_file(Pipeline::KB_ROOT.join("style_specs/b-test.yml"))

      result = described_class::LockSceneEntry.call(piece: nil, context: scene_ctx(axes: axes, scene_name: "S1", template_ref: "t.yml", confirmed: true))
      expect(result).to be_ok
      expect(KnowledgeBase::StyleSpec.load("b-test").scene("b-s1").color_role).to eq("line_only")
    end
  end
end
