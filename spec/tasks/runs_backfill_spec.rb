require "rails_helper"
require "rake"

RSpec.describe "runs:backfill_cells" do
  before(:all) { Rails.application.load_tasks }

  def invoke_backfill
    Rake::Task["runs:backfill_cells"].reenable
    Rake::Task["runs:backfill_cells"].invoke
  end

  it "creates cells from existing step_results" do
    run = create(:pipeline_run_record, step_results: [
      { "step_id" => "A0", "status" => "ok", "data" => { "a" => 1 }, "at" => Time.current.iso8601 },
      { "step_id" => "B1", "status" => "awaiting_human", "data" => {}, "message" => "review" }
    ])

    invoke_backfill

    steps = run.run_steps.reload.order(:position)
    expect(steps.map(&:step_id)).to eq(%w[A0 B1])
    expect(steps.find_by(step_id: "A0").status).to eq("done")
    expect(steps.find_by(step_id: "B1")).to be_awaiting_human
  end

  it "is idempotent" do
    create(:pipeline_run_record, step_results: [{ "step_id" => "A0", "status" => "ok", "data" => {} }])

    invoke_backfill
    expect { invoke_backfill }.not_to change { RunStep.count }
  end

  it "skips duplicate step_ids" do
    run = create(:pipeline_run_record, step_results: [
      { "step_id" => "A0", "status" => "ok", "data" => {} },
      { "step_id" => "A0", "status" => "ok", "data" => {} }
    ])

    invoke_backfill

    expect(run.run_steps.reload.count).to eq(1)
  end
end
