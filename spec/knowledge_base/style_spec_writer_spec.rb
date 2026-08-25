require "rails_helper"

RSpec.describe KnowledgeBase::StyleSpecWriter do
  it "creates and round-trips a style spec" do
    slug = "test-writer-#{SecureRandom.hex(4)}"
    spec = described_class.create_or_update_style_level(
      slug: slug, name: "T", mood: "calm_ordered",
      content_type: "minimalist_modern", frame_form: "angular"
    )
    track_kb_file(spec.path)

    expect(spec.slug).to eq(slug)
    reloaded = KnowledgeBase::StyleSpec.load(slug)
    expect(reloaded.style_level[:mood]).to eq("calm_ordered")
    expect(reloaded.style_level[:content_type]).to eq("minimalist_modern")
    expect(reloaded.style_level[:frame_form]).to eq("angular")
  end

  it "rejects an out-of-range style axis" do
    slug = "test-writer-bad-#{SecureRandom.hex(4)}"
    expect do
      described_class.create_or_update_style_level(
        slug: slug, name: "T", mood: "nonsense",
        content_type: "minimalist_modern", frame_form: "angular"
      )
    end.to raise_error(KnowledgeBase::IncompleteSpecError)
    expect(Pipeline::KB_ROOT.join("style_specs", "#{slug}.yml")).not_to exist
  end

  it "preserves existing scenes when updating the style level" do
    slug = "test-writer-#{SecureRandom.hex(4)}"
    build_test_spec(slug: slug)

    described_class.create_or_update_style_level(
      slug: slug, name: "T2", mood: "bold_active",
      content_type: "portrait_still_life", frame_form: "rounded"
    )

    reloaded = KnowledgeBase::StyleSpec.load(slug)
    expect(reloaded.style_level[:mood]).to eq("bold_active")
    expect(reloaded.scene_ids).to include("s1")
  end
end
