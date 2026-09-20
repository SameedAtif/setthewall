require "rails_helper"

RSpec.describe PieceRecord do
  it "requires the KB linkage fields" do
    piece = build(:piece_record, style_spec_slug: nil, scene_spec_id: nil, kb_version: nil)
    expect(piece).not_to be_valid
    expect(piece.errors[:style_spec_slug]).to include("can't be blank")
    expect(piece.errors[:kb_version]).to include("can't be blank")
  end

  it "validates status inclusion" do
    piece = build(:piece_record, status: "bogus")
    expect(piece).not_to be_valid
    expect(piece.errors[:status]).to include("is not included in the list")
  end

  it "is dirty only for dirty-prefixed KB versions" do
    expect(build(:piece_record, kb_version: "dirty:abc")).to be_dirty_run
    expect(build(:piece_record, kb_version: "abc123")).not_to be_dirty_run
  end

  it "excludes dirty runs from the trustworthy scope" do
    create(:piece_record, :complete, kb_version: "dirty:abc")
    clean = create(:piece_record, :complete, kb_version: "abc123")

    expect(described_class.trustworthy).to include(clean)
    expect(described_class.published.trustworthy.count).to eq(1)
  end

  it "denormalizes the axes via apply_spec!" do
    spec, scene = build_test_spec
    piece = build(:piece_record, style_spec_slug: spec.slug, scene_spec_id: "s1")
    piece.apply_spec!(spec, scene)

    expect(piece.mood).to eq("calm_ordered")
    expect(piece.content_type).to eq("minimalist_modern")
    expect(piece.frame_form).to eq("angular")
    expect(piece.wall_condition).to eq("neutral")
    expect(piece.room_type).to eq("seated_room")
  end

  it "sources color_role from the style spec's reference essence" do
    spec, scene = build_test_spec
    KnowledgeBase::StyleSpecWriter.create_or_update_style_level(
      slug: spec.slug, name: "Test", mood: "calm_ordered",
      content_type: "minimalist_modern", frame_form: "angular",
      reference_essence: { "color_role" => "saturator" }
    )
    piece = build(:piece_record, style_spec_slug: spec.slug, scene_spec_id: "s1")
    piece.apply_spec!(KnowledgeBase::StyleSpec.load(spec.slug), scene)

    expect(piece.color_role).to eq("saturator")
  end

  it "appends an audit entry via log_step!" do
    piece = create(:piece_record)
    piece.log_step!(step_id: "C1", mechanism: :image_gen, outcome: :ok, detail: { n: 3 })

    expect(piece.reload.step_log.size).to eq(1)
    expect(piece.step_log.first["step_id"]).to eq("C1")
    expect(piece.step_log.first["outcome"]).to eq("ok")
  end
end
