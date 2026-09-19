require "rails_helper"

RSpec.describe Workflow::GateApplier do
  let(:run) { create(:pipeline_run_record, scope: "piece") }

  def interpretation(intent, edits: {}, notes: "note", reason: nil)
    Llm::FeedbackInterpreter::Result.new(intent: intent, notes: notes, edits: edits,
                                         reason: reason, raw: {})
  end

  it "approves a gate, marks the cell done, and advances" do
    step = create(:run_step, pipeline_run_record: run, step_id: "C2", position: 1,
                             status: "awaiting_human", verdict: "clean")
    gate = create(:human_gate, piece_record: nil, step_id: "C2", status: "open",
                               opened_at: Time.current)
    allow(Workflow::CellRunner).to receive(:reveal_next)

    described_class.call(run_step: step, interpretation: interpretation("approve"))

    expect(gate.reload.status).to eq("approved")
    expect(step.reload.status).to eq("done")
    expect(Workflow::CellRunner).to have_received(:reveal_next)
  end

  it "merges requested edits into the cell output" do
    step = create(:run_step, pipeline_run_record: run, step_id: "B3", position: 0,
                             status: "awaiting_human", output: { "room_type" => "ambiguous" })
    allow(Workflow::CellRunner).to receive(:reveal_next)

    described_class.call(run_step: step,
                         interpretation: interpretation("edit", edits: { "room_type" => "seated_room" }))

    expect(step.reload.output).to eq({ "room_type" => "seated_room" })
  end

  it "raises when the disposition is illegal for the verdict" do
    step = create(:run_step, pipeline_run_record: run, step_id: "B3", position: 0,
                             status: "awaiting_human", verdict: "contradicted")
    allow(Workflow::DecisionRules).to receive(:legal_dispositions)
      .with(step_id: "B3", verdict: "contradicted")
      .and_return(%w[retry rewind abandon])

    expect {
      described_class.call(run_step: step, interpretation: interpretation("approve"))
    }.to raise_error(Workflow::DecisionRules::IllegalDisposition)
  end

  it "abandons the run" do
    step = create(:run_step, pipeline_run_record: run, step_id: "P2_0", position: 0,
                             status: "awaiting_human", verdict: "clean")

    described_class.call(run_step: step, interpretation: interpretation("abandon"))

    expect(run.reload.status).to eq("abandoned")
  end

  it "enqueues a re-run on retry instead of running inline" do
    step = create(:run_step, pipeline_run_record: run, step_id: "B3", position: 0,
                             status: "awaiting_human", verdict: "clean")

    expect { described_class.call(run_step: step, interpretation: interpretation("retry")) }
      .to have_enqueued_job(ExecuteRunJob).with(run_id: run.id, mode: "rerun", run_step_id: step.id)

    expect(step.reload.status).to eq("queued")
  end

  it "enqueues a re-run of the rewind target" do
    target = create(:run_step, pipeline_run_record: run, step_id: "A0", position: 0, status: "done")
    step = create(:run_step, pipeline_run_record: run, step_id: "A1", position: 1,
                             status: "awaiting_human", verdict: "clean")

    expect { described_class.call(run_step: step, interpretation: interpretation("rewind")) }
      .to have_enqueued_job(ExecuteRunJob).with(run_id: run.id, mode: "rerun", run_step_id: target.id)

    expect(target.reload.status).to eq("queued")
  end

  it "refuses an A1 retry when the model reported an unreconcilable split" do
    step = create(:run_step, pipeline_run_record: run, step_id: "A1", position: 0,
                             status: "awaiting_human",
                             output: { "candidates" => {
                               "mood_clusters_found" => [{ "label" => "a" }, { "label" => "b" }],
                               "dominant_mood" => "mixed"
                             } })

    expect { described_class.call(run_step: step, interpretation: interpretation("retry")) }
      .to raise_error(Workflow::GateApplier::IdenticalRetry)
  end

  it "allows a legacy A1 retry when no dominant mood was reported" do
    step = create(:run_step, pipeline_run_record: run, step_id: "A1", position: 0,
                             status: "awaiting_human",
                             output: { "candidates" => { "mood_clusters_found" => [
                               { "label" => "a" }, { "label" => "b" }
                             ] } })

    expect { described_class.call(run_step: step, interpretation: interpretation("retry")) }
      .to have_enqueued_job(ExecuteRunJob).with(run_id: run.id, mode: "rerun", run_step_id: step.id)
  end

  it "allows an A1 retry once a scoping override is present" do
    step = create(:run_step, pipeline_run_record: run, step_id: "A1", position: 0,
                             status: "awaiting_human",
                             context_override: { "style_name" => "a" },
                             output: { "candidates" => { "mood_clusters_found" => [
                               { "label" => "a" }, { "label" => "b" }
                             ] } })

    expect { described_class.call(run_step: step, interpretation: interpretation("retry")) }
      .to have_enqueued_job(ExecuteRunJob).with(run_id: run.id, mode: "rerun", run_step_id: step.id)
  end

  it "allows an A1 retry when the camps reconcile to a dominant mood" do
    step = create(:run_step, pipeline_run_record: run, step_id: "A1", position: 0,
                             status: "awaiting_human",
                             output: { "candidates" => {
                               "mood_clusters_found" => [{ "label" => "a" }, { "label" => "b" }],
                               "dominant_mood" => "calm_ordered",
                               "shared_qualities" => ["warm neutral"]
                             } })

    expect { described_class.call(run_step: step, interpretation: interpretation("retry")) }
      .to have_enqueued_job(ExecuteRunJob).with(run_id: run.id, mode: "rerun", run_step_id: step.id)
  end
end
