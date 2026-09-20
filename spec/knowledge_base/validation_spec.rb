require "rails_helper"

RSpec.describe "scene axis validation" do
  def spec_with_scene_axes(axes)
    slug = "scene-val-#{SecureRandom.hex(4)}"
    path = Pipeline::KB_ROOT.join("style_specs", "#{slug}.yml")
    path.write(<<~YAML)
      slug: #{slug}
      name: "Test"
      style_level:
        mood: calm_ordered
        content_type: minimalist_modern
        frame_form: angular
      production_model:
        fulfillment_type: physical
        piece_count: 1
      scenes:
        s1:
          name: S1
          axes:
            wall_condition: #{axes.fetch(:wall_condition, "neutral")}
            furniture_weight: #{axes.fetch(:furniture_weight, "light")}
            room_type: #{axes.fetch(:room_type, "seated_room")}
            room_shape: #{axes.fetch(:room_shape, "none")}
            space_math: #{axes.fetch(:space_math, "single")}
    YAML
    track_kb_file(path)
    slug
  end

  it "rejects a blank scene axis" do
    slug = spec_with_scene_axes(room_type: "")
    expect { KnowledgeBase::StyleSpec.load(slug).validate! }
      .to raise_error(KnowledgeBase::IncompleteSpecError, /blank/)
  end

  it "rejects an out-of-range scene axis" do
    slug = spec_with_scene_axes(wall_condition: "invalid")
    expect { KnowledgeBase::StyleSpec.load(slug).validate! }
      .to raise_error(KnowledgeBase::IncompleteSpecError, /not in/)
  end
end

RSpec.describe KnowledgeBase::StyleSpec do
  it "enumerates all specs via .all" do
    spec, = build_test_spec
    expect(described_class.all.map(&:slug)).to include(spec.slug)
  end

  it "raises for an unknown scene id" do
    spec, = build_test_spec
    expect { spec.scene("nope") }.to raise_error(KnowledgeBase::IncompleteSpecError)
  end
end

RSpec.describe KnowledgeBase::SceneSpecWriter do
  it "refuses when the style level is blank" do
    slug = "nolevel-#{SecureRandom.hex(4)}"
    path = Pipeline::KB_ROOT.join("style_specs", "#{slug}.yml")
    path.write("slug: #{slug}\nname: X\n")
    track_kb_file(path)

    expect do
      described_class.write_scene_axes(
        style_slug: slug, scene_id: "s1", scene_name: "S1", template_ref: "t.yml",
        axes: { wall_condition: "neutral", furniture_weight: "light", room_type: "seated_room",
                room_shape: "none", space_math: "single", color_role: "line_only" }
      )
    end.to raise_error(KnowledgeBase::IncompleteSpecError, /style_level/)
  end
end

RSpec.describe PieceRecord do
  it "returns gate history scoped by step" do
    piece = create(:piece_record)
    create(:human_gate, piece_record: piece, step_id: "A1")
    create(:human_gate, piece_record: piece, step_id: "A2")

    expect(piece.gate_history.size).to eq(2)
    expect(piece.gate_history(step_id: "A1").map(&:step_id)).to eq(["A1"])
  end
end
