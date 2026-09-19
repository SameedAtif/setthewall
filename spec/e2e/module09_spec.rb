require "rails_helper"

# End-to-end: a speculative run walks the pipeline, produces a dossier, the human reviews it, and
# approving commits the run. LLM/vision calls are stubbed — this exercises the orchestration, not
# the models.
RSpec.describe "Module 09 speculative run → dossier → commit", type: :request do
  Result = Struct.new(:status, :data, :message, keyword_init: true) do
    def failed? = status == :failed
  end
  Finding = Struct.new(:severity, :claim, :citations, :payload, keyword_init: true) do
    def blocking? = severity == "blocking"
    def advisory? = severity == "advisory"
    def pass?     = severity == "pass"
  end

  def stub_pipeline
    allow(Workflow::PreflightCheck).to receive(:call!)
      .and_return(Workflow::PreflightCheck::Result.new(kb_version: "abc", dirty: false))
    allow(Workflow::StepDispatcher).to receive(:call)
      .and_return(Result.new(status: :ok, data: {}))
    fake = Class.new do
      define_singleton_method(:call) do |**_k|
        [Finding.new(severity: "pass", claim: "ok", citations: [{ "rule_path" => "coverage_cap.rules" }], payload: {})]
      end
    end
    allow(Agents::Registry).to receive(:for).and_return([fake])
  end

  it "produces a reviewable dossier and commits on approval" do
    stub_pipeline

    run = Agents::Conductor.run_speculative(style_slug: "japandi", scene_spec_id: "s1")

    expect(run.mode).to eq("speculative")
    expect(run.status).to eq("awaiting_dossier_review")
    expect(run.dossier_markdown).to include("## Open questions")
    expect(run.step_results.size).to eq(Agents::Conductor::ORDER.size)

    # Human approves from the notebook.
    post approve_run_path(run), params: { notes: "ship it" }
    perform_enqueued_jobs

    expect(run.reload.status).to eq("committed")
    expect(run.reload.mode).to eq("committed")
  end

  it "never writes to knowledge_base in speculative mode" do
    stub_pipeline

    before = Dir[Pipeline::KB_ROOT.join("**/*")].to_h { |f| [f, File.mtime(f)] }
    Agents::Conductor.run_speculative(style_slug: "japandi", scene_spec_id: "s1")
    after = Dir[Pipeline::KB_ROOT.join("**/*")].to_h { |f| [f, File.mtime(f)] }

    expect(before).to eq(after)
  end
end
