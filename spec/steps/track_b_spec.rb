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

  describe "LockSceneEntry (B7)" do
    let(:axes) do
      { wall_condition: "neutral", furniture_weight: "light", room_type: "seated_room",
        room_shape: "none", space_math: "single" }
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
      expect(KnowledgeBase::StyleSpec.load("b-test").scene("b-s1").room_type).to eq("seated_room")
    end
  end
end
