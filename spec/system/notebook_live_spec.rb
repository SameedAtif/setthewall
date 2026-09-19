require "rails_helper"

RSpec.describe "Notebook live updates", type: :system do
  it "streams a completed cell into the notebook without a reload" do
    run = create(:pipeline_run_record, run_id: "run_live_1", style_slug: "s",
                                       scene_spec_id: "sc", scope: "piece")
    create(:run_step, pipeline_run_record: run, step_id: "C1", position: 0, status: "pending")

    allow(Workflow::DecisionRules).to receive(:gated_step_ids).and_return([])
    allow(Agents::Registry).to receive(:for).and_return([])
    allow(Workflow::StepDispatcher).to receive(:call).and_return(
      Struct.new(:status, :data, :message, keyword_init: true)
            .new(status: :ok, data: { "ran" => true }, message: "C1 ran")
    )
    allow(Llm::CellSummarizer).to receive(:call).and_return("Cell C1 completed and streamed in.")

    visit run_path(run)
    expect(page).to have_text("Not run yet.")
    # Wait for the Turbo Streams subscription before triggering a broadcast.
    expect(page).to have_css("turbo-cable-stream-source[connected]", visible: :all, wait: 5)

    click_button "Run next"
    # The enqueue happens asynchronously with Turbo; wait for it before performing.
    Timeout.timeout(5) { sleep 0.05 until enqueued_jobs.any? }
    perform_enqueued_jobs

    expect(page).to have_css("p", text: "Cell C1 completed and streamed in.", visible: :all)
  end
end
