require "rails_helper"

RSpec.describe Context::Assembler do
  def run_with(candidates)
    create(:pipeline_run_record,
           step_results: [{ "step_id" => "A1", "status" => "ok",
                            "data" => { "candidates" => candidates } }])
  end

  it "mixes close-up and in-situ reference shots for C1, close-ups first" do
    candidates = { "images" => [
      { "url" => "room1.jpg", "shot_type" => "in_situ" },
      { "url" => "art1.jpg", "shot_type" => "closeup" },
      { "url" => "art2.jpg", "shot_type" => "closeup" }
    ] }

    context = described_class.for("C1", run_with(candidates))

    expect(context[:reference_images]).to eq(%w[art1.jpg art2.jpg room1.jpg])
  end

  it "drops reference images A1 flagged as outliers" do
    candidates = { "images" => [
      { "url" => "art1.jpg", "shot_type" => "closeup" },
      { "url" => "odd.jpg", "shot_type" => "closeup", "is_outlier" => true }
    ] }

    context = described_class.for("C1", run_with(candidates))

    expect(context[:reference_images]).to eq(%w[art1.jpg])
  end

  it "falls back to every image when A1 has no close-ups" do
    candidates = { "images" => [{ "url" => "room1.jpg", "shot_type" => "in_situ" }] }

    context = described_class.for("C1", run_with(candidates))

    expect(context[:reference_images]).to eq(%w[room1.jpg])
  end

  it "reads the typed reference essence distilled by A1b" do
    essence = { "palette" => "warm bone to ash grey", "motif_vocabulary" => ["nested grooves"] }
    run = create(:pipeline_run_record,
                 step_results: [{ "step_id" => "A1b", "status" => "ok",
                                  "data" => { "essence" => essence } }])

    context = described_class.for("C1", run)

    expect(context[:reference_essence]).to eq(essence)
  end

  it "does not fall back to A1's prose shared_qualities" do
    candidates = { "images" => [], "shared_qualities" => ["flat printed surface"],
                   "dominant_mood" => "calm_ordered" }

    context = described_class.for("C1", run_with(candidates))

    expect(context[:reference_essence]).to eq({})
  end
end
