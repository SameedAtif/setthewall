require "rails_helper"

RSpec.describe Context::Assembler do
  def run_with(candidates)
    create(:pipeline_run_record,
           step_results: [{ "step_id" => "A1", "status" => "ok",
                            "data" => { "candidates" => candidates } }])
  end

  it "prefers close-up reference shots over in-situ room shots for C1" do
    candidates = { "images" => [
      { "url" => "room1.jpg", "shot_type" => "in_situ" },
      { "url" => "art1.jpg", "shot_type" => "closeup" },
      { "url" => "art2.jpg", "shot_type" => "closeup" }
    ] }

    context = described_class.for("C1", run_with(candidates))

    expect(context[:reference_images]).to eq(%w[art1.jpg art2.jpg])
  end

  it "falls back to every image when A1 has no close-ups" do
    candidates = { "images" => [{ "url" => "room1.jpg", "shot_type" => "in_situ" }] }

    context = described_class.for("C1", run_with(candidates))

    expect(context[:reference_images]).to eq(%w[room1.jpg])
  end

  it "carries A1's shared qualities and dominant mood as the reference essence" do
    candidates = { "images" => [], "shared_qualities" => ["flat printed surface"],
                   "dominant_mood" => "calm_ordered" }

    context = described_class.for("C1", run_with(candidates))

    expect(context[:reference_essence]).to eq(mood: "calm_ordered", qualities: ["flat printed surface"])
  end
end
