require "rails_helper"

RSpec.describe PipelineRunRecord do
  describe "#name" do
    it "combines the style slug and the created time" do
      run = build(:pipeline_run_record, style_slug: "japandi",
                                        created_at: Time.zone.local(2026, 9, 11, 14, 30))

      expect(run.name).to eq("japandi · Sep 11, 2026 14:30")
    end

    it "falls back when style or time is missing" do
      expect(build(:pipeline_run_record, style_slug: nil, created_at: nil).name)
        .to eq("untitled · unstarted")
    end
  end

  describe "#mirror_step_results!" do
    it "rebuilds step_results from cells in order" do
      run = create(:pipeline_run_record)
      create(:run_step, pipeline_run_record: run, step_id: "A0", position: 1,
                        status: "done", output: { "a" => 1 })
      create(:run_step, pipeline_run_record: run, step_id: "B1", position: 2,
                        status: "awaiting_human", message: "review")

      run.mirror_step_results!

      expect(run.reload.step_results).to eq([
        { "step_id" => "A0", "status" => "ok", "data" => { "a" => 1 } },
        { "step_id" => "B1", "status" => "awaiting_human", "data" => {}, "message" => "review" }
      ])
    end

    it "mirrors automatically when a cell is saved" do
      run = create(:pipeline_run_record)
      create(:run_step, pipeline_run_record: run, step_id: "A0", status: "done", output: { "x" => true })

      expect(run.reload.step_results.first).to include("step_id" => "A0", "status" => "ok")
    end

    it "drops stale cells from the mirror" do
      run = create(:pipeline_run_record)
      step = create(:run_step, pipeline_run_record: run, step_id: "A0", status: "done")
      step.update!(status: "stale")

      expect(run.reload.step_results).to eq([])
    end

    it "preserves the entry shape Conductor#record_step! writes" do
      run = create(:pipeline_run_record)
      create(:run_step, pipeline_run_record: run, step_id: "A0", status: "done",
                        output: { "findings" => { "x" => 1 } }, message: "done",
                        verdict: "clean", disposition: "approve")

      entry = run.reload.step_results.first
      expect(entry.keys).to match_array(%w[step_id status data message verdict disposition])
    end
  end
end
