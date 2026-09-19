require "rails_helper"

RSpec.describe "Runs", type: :request do
  def preflight_result
    Workflow::PreflightCheck::Result.new(kb_version: "abc", dirty: false)
  end

  describe "GET /runs" do
    it "renders the notebook for the latest run" do
      run = create(:pipeline_run_record, style_slug: "japandi", scene_spec_id: "s1")
      create(:run_step, pipeline_run_record: run, step_id: "A_IDEATE", position: 0,
                        status: "done", summary: "Surveyed styles.",
                        logs: [{ "at" => "2026-09-13T15:08:30Z", "level" => "info", "message" => "started" }])

      get runs_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(run.run_id)
      expect(response.body).to include("Surveyed styles.")
      expect(response.body).to include("tailwind")
      # Log timestamps render as client-convertible UTC <time> elements.
      expect(response.body).to include('datetime="2026-09-13T15:08:30Z"')
      expect(response.body).to include('data-controller="local-time"')
      # The human-readable text is collapsible, like the prompt and raw JSON.
      expect(response.body).to include("See more")
      expect(response.body).to include("Hide")
    end

    it "renders an empty state with no runs" do
      get runs_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No runs yet")
    end
  end

  describe "POST /runs" do
    it "creates a full run and prepares its first cell" do
      allow(Workflow::PreflightCheck).to receive(:call!).and_return(preflight_result)

      expect {
        post runs_path, params: { style_slug: "japandi", scene_spec_id: "s1", style_name: "Japandi" }
      }.to change(PipelineRunRecord, :count).by(1)

      run = PipelineRunRecord.last
      expect(run.scope).to eq("full")
      expect(run.status).to eq("pending")
      expect(run.run_steps.map(&:step_id)).to eq(%w[A_IDEATE])
      expect(run.run_steps.first).to be_pending
      expect(response).to redirect_to(run_path(run))
    end

    it "requires style and scene" do
      post runs_path, params: { style_slug: "", scene_spec_id: "" }

      expect(response).to redirect_to(runs_path)
    end
  end

  describe "member actions" do
    let(:run) { create(:pipeline_run_record) }

    it "enqueues the next cell" do
      expect { post run_next_run_path(run) }
        .to have_enqueued_job(ExecuteRunJob).with(run_id: run.id, mode: "next")

      expect(response).to have_http_status(:accepted)
    end

    it "enqueues a run to the next decision" do
      expect { post run_to_decision_run_path(run) }
        .to have_enqueued_job(ExecuteRunJob).with(run_id: run.id, mode: "to_decision")

      expect(response).to have_http_status(:accepted)
    end

    it "approves, refreshes the dossier, and enqueues the commit" do
      allow(Workflow::DossierRefresher).to receive(:call).and_call_original

      expect { post approve_run_path(run) }
        .to have_enqueued_job(CommitRunJob).with(run_id: run.run_id)

      expect(run.reload.status).to eq("approved")
      expect(Workflow::DossierRefresher).to have_received(:call).with(run: run)
    end

    it "refuses to approve while cells are stale" do
      create(:run_step, pipeline_run_record: run, step_id: "C1", position: 0, status: "stale")

      expect { post approve_run_path(run) }.not_to have_enqueued_job(CommitRunJob)

      expect(response).to redirect_to(run_path(run))
      expect(run.reload.status).not_to eq("approved")
    end

    it "abandons the run" do
      post abandon_run_path(run)

      expect(run.reload.status).to eq("abandoned")
    end
  end
end
