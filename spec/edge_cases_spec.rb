require "rails_helper"

RSpec.describe Compositor::Runner do
  it "downloads a remote art URL" do
    build_scene_template("dl-scene")
    piece = build_piece(scene_id: "dl-scene")
    piece.save!
    runner = described_class.new(piece: piece)

    stub_singleton(Faraday, :get, ->(*) { double("resp", body: "pngdata") }) do
      path = runner.send(:local_path_for, "http://example.com/art.png")
      expect(File.exist?(path)).to be(true)
    end
  end
end

RSpec.describe Steps::Phase2::AssignFrame do
  it "has a defensive metal default for an unknown content type" do
    step = described_class.new(piece: double(content_type: "unknown", mood: "unknown"), context: {})
    expect(step.send(:pick_material_category, KnowledgeBase::RuleSet.load("frame_material"))).to eq("metal")
  end

  it "defaults to black metal for an unknown palette" do
    step = described_class.new(piece: double(mood: "calm_ordered"), context: { palette: "foo" })
    expect(step.send(:pick_metal_finish, KnowledgeBase::RuleSet.load("frame_material"))).to eq("black_metal")
  end
end

RSpec.describe "KbProposals read guard", type: :request do
  it "shows a proposal whose target file is missing" do
    proposal = create(:kb_proposal, target_path: "knowledge_base/rules/nonexistent_#{SecureRandom.hex(4)}.yml")
    get kb_proposal_path(proposal)
    expect(response).to have_http_status(:ok)
  end
end
