require "rails_helper"

RSpec.describe RunStep do
  it "validates status inclusion" do
    expect(build(:run_step, status: "bogus")).not_to be_valid
  end

  it "requires step_id to be unique per run" do
    run = create(:pipeline_run_record)
    create(:run_step, pipeline_run_record: run, step_id: "A0")
    expect(build(:run_step, pipeline_run_record: run, step_id: "A0")).not_to be_valid
  end

  it "orders by position then id" do
    run = create(:pipeline_run_record)
    create(:run_step, pipeline_run_record: run, step_id: "B", position: 2)
    create(:run_step, pipeline_run_record: run, step_id: "A", position: 1)

    expect(run.run_steps.reload.map(&:step_id)).to eq(%w[A B])
  end

  describe "#mood_clusters" do
    it "returns the labels of the reference-set mood clusters" do
      step = build(:run_step, output: { "candidates" => { "mood_clusters_found" => [
        { "label" => "calm", "image_indices" => [1] },
        { "label" => "bold", "image_indices" => [2] }
      ] } })

      expect(step.mood_clusters).to eq(%w[calm bold])
    end

    it "is empty when there is no reference set" do
      expect(build(:run_step, output: {}).mood_clusters).to eq([])
    end

    it "does not raise when a step stores `candidates` as an array (e.g. A_IDEATE)" do
      step = build(:run_step, output: { "candidates" => [{ "label" => "x" }] })

      expect(step.mood_clusters).to eq([])
      expect(step.dominant_mood).to be_nil
      expect(step.mood_unresolved?).to be(false)
    end
  end

  describe "#mood_unresolved?" do
    def step_with(candidates)
      build(:run_step, output: { "candidates" => candidates })
    end

    it "is false for a single cluster" do
      expect(step_with("mood_clusters_found" => [{ "label" => "calm" }]).mood_unresolved?).to be(false)
    end

    it "is false when camps reconcile to a dominant mood with shared qualities" do
      step = step_with("mood_clusters_found" => [{ "label" => "a" }, { "label" => "b" }],
                       "dominant_mood" => "calm_ordered", "shared_qualities" => ["warm neutral"])

      expect(step.mood_unresolved?).to be(false)
      expect(step.dominant_mood).to eq("calm_ordered")
    end

    it "is true when the dominant mood is mixed" do
      step = step_with("mood_clusters_found" => [{ "label" => "a" }, { "label" => "b" }],
                       "dominant_mood" => "mixed", "shared_qualities" => ["warm neutral"])

      expect(step.mood_unresolved?).to be(true)
    end

    it "is true for legacy cells with clusters but no reconciliation" do
      expect(step_with("mood_clusters_found" => [{ "label" => "a" }, { "label" => "b" }]).mood_unresolved?)
        .to be(true)
    end
  end

  describe "#mood_mixed?" do
    it "is true only when the model reported dominant_mood mixed" do
      mixed = build(:run_step, output: { "candidates" => {
        "mood_clusters_found" => [{ "label" => "a" }, { "label" => "b" }], "dominant_mood" => "mixed"
      } })
      resolved = build(:run_step, output: { "candidates" => {
        "mood_clusters_found" => [{ "label" => "a" }, { "label" => "b" }],
        "dominant_mood" => "calm_ordered", "shared_qualities" => ["warm neutral"]
      } })
      legacy = build(:run_step, output: { "candidates" => {
        "mood_clusters_found" => [{ "label" => "a" }, { "label" => "b" }]
      } })

      expect(mixed.mood_mixed?).to be(true)
      expect(resolved.mood_mixed?).to be(false)
      expect(legacy.mood_mixed?).to be(false)
    end
  end

  describe "#log!" do
    it "appends timestamped lines without touching the mirror" do
      run = create(:pipeline_run_record)
      step = create(:run_step, pipeline_run_record: run, step_id: "A_IDEATE", status: "done")
      run.update_column(:step_results, [{ "step_id" => "A_IDEATE", "status" => "ok", "data" => {} }])

      step.log!("Started A_IDEATE", level: "info")

      expect(step.reload.logs.size).to eq(1)
      expect(step.logs.last).to include("level" => "info", "message" => "Started A_IDEATE")
      expect(step.logs.last["at"]).to be_present
      expect(run.reload.step_results.size).to eq(1)
    end
  end

  describe "#result_entry" do
    it "maps done to ok and stringifies output keys" do
      step = build(:run_step, step_id: "A0", status: "done", output: { mood: "calm" }, message: "hi")

      expect(step.result_entry).to eq(
        "step_id" => "A0", "status" => "ok", "data" => { "mood" => "calm" }, "message" => "hi"
      )
    end

    it "includes verdict and disposition when present" do
      step = build(:run_step, step_id: "A2", status: "done", verdict: "clean", disposition: "approve")

      expect(step.result_entry).to include("verdict" => "clean", "disposition" => "approve")
    end

    it "returns nil for statuses that are not committed results" do
      %w[pending running stale skipped].each do |status|
        expect(build(:run_step, status: status).result_entry).to be_nil
      end
    end
  end
end
