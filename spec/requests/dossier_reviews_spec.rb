require "rails_helper"

RSpec.describe "DossierReviews", type: :request do
  def run(status: "awaiting_dossier_review")
    PipelineRunRecord.create!(run_id: "run-#{SecureRandom.hex(4)}", kb_version: "abc",
                              status: status, style_slug: "japandi", scene_spec_id: "s1",
                              dossier_markdown: "# Run", dossier_ready_at: Time.current)
  end

  it "lists runs awaiting review" do
    run
    get dossier_reviews_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Dossier reviews")
  end

  it "shows a dossier" do
    r = run
    get dossier_review_path(r.run_id)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("# Run")
  end

  it "approves and enqueues a commit job" do
    r = run
    expect { patch dossier_review_path(r.run_id), params: { decision: "approve", notes: "ok" } }
      .to have_enqueued_job(CommitRunJob).with(run_id: r.run_id)
    expect(response).to redirect_to(dossier_reviews_path)
    expect(r.reload.status).to eq("approved")
  end

  it "abandons a run" do
    r = run
    patch dossier_review_path(r.run_id), params: { decision: "abandon" }
    expect(r.reload.status).to eq("abandoned")
  end

  it "reruns from a step" do
    r = run
    expect { patch dossier_review_path(r.run_id), params: { decision: "rerun", step_id: "A1", notes: "too many" } }
      .to have_enqueued_job(RerunFromStepJob).with(run_id: r.run_id, step_id: "A1", guidance: "too many")
    expect(r.reload.status).to eq("rerunning")
  end
end

RSpec.describe CommitRunJob do
  it "marks the run committed under the committed-mode guard" do
    run = PipelineRunRecord.create!(run_id: "run-x", kb_version: "abc", status: "approved")
    described_class.perform_now(run_id: run.run_id)
    expect(run.reload.mode).to eq("committed")
    expect(run.reload.status).to eq("committed")
  end
end

RSpec.describe RerunFromStepJob do
  it "marks the run rerunning with guidance" do
    run = PipelineRunRecord.create!(run_id: "run-x", kb_version: "abc")
    described_class.perform_now(run_id: run.run_id, step_id: "A1", guidance: "narrow")
    expect(run.reload.status).to eq("rerunning")
    expect(run.reload.reviewer_notes).to include("A1")
  end
end
