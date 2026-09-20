require "rails_helper"

RSpec.describe "Run steps", type: :request do
  let(:run) { create(:pipeline_run_record, scope: "piece") }
  let(:step) do
    create(:run_step, pipeline_run_record: run, step_id: "C2", position: 1, status: "awaiting_human")
  end

  describe "POST /runs/:run_id/steps/:id/run" do
    it "enqueues the cell re-run" do
      expect { post run_run_step_path(run, step) }
        .to have_enqueued_job(ExecuteRunJob).with(run_id: run.id, mode: "rerun", run_step_id: step.id)

      expect(response).to have_http_status(:accepted)
    end
  end

  describe "POST interpret" do
    it "renders the parsed decision preview and records feedback" do
      interp = Llm::FeedbackInterpreter::Result.new(
        intent: "edit", notes: "Make it calmer", reason: "tone",
        edits: { "mood" => "calm_ordered" }, raw: {}
      )
      allow(Llm::FeedbackInterpreter).to receive(:call).and_return(interp)

      post interpret_run_step_path(run, step), params: { feedback: "please calm it down" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Proposed decision")
      expect(response.body).to include("Make it calmer")
      expect(step.step_feedbacks.count).to eq(1)
    end

    it "returns the composer with an error for illegal feedback" do
      allow(Llm::FeedbackInterpreter).to receive(:call)
        .and_raise(Llm::FeedbackInterpreter::IllegalIntent, "that is not legal")

      post interpret_run_step_path(run, step), params: { feedback: "??" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("that is not legal")
    end
  end

  describe "POST decision" do
    it "applies the decision and marks the feedback applied" do
      feedback = create(:step_feedback, run_step: step, applied: false,
                                        parsed: { "intent" => "approve", "notes" => "ok",
                                                  "reason" => nil, "edits" => {} })
      expect(Workflow::GateApplier).to receive(:call)

      post decision_run_step_path(run, step), params: { feedback_id: feedback.id }

      expect(feedback.reload).to be_applied
      expect(response).to redirect_to(run_path(run, anchor: "run_step_#{step.id}"))
    end
  end

  describe "POST decide" do
    it "applies the chosen option through the gate applier" do
      step.update!(decision_options: [{ "label" => "Approve", "intent" => "approve", "edits" => {} }])
      expect(Workflow::GateApplier).to receive(:call)

      post decide_run_step_path(run, step), params: { option_index: 0 }

      expect(response).to redirect_to(run_path(run, anchor: "run_step_#{step.id}"))
    end

    it "falls back to the options the panel rendered when none are stored" do
      step.update!(decision_options: [], verdict: "clean")
      expect(Workflow::GateApplier).to receive(:call) do |run_step:, interpretation:|
        expect(interpretation.intent).to eq("approve")
      end

      post decide_run_step_path(run, step), params: { option_index: 0 }

      expect(response).to have_http_status(:found)
    end

    it "alerts when no valid option is chosen" do
      step.update!(decision_options: [])

      post decide_run_step_path(run, step), params: { option_index: 5 }

      expect(response).to redirect_to(run_path(run))
      expect(flash[:alert]).to be_present
    end
  end

  describe "POST note" do
    it "records a plain reviewer note without changing state" do
      expect { post note_run_step_path(run, step), params: { note: "Looks good" } }
        .to change(StepFeedback, :count).by(1)

      expect(step.reload.status).to eq("awaiting_human")
      expect(response).to redirect_to(run_path(run))
    end
  end

  describe "POST narrow" do
    it "stores the scope as a context override and enqueues a re-run" do
      expect { post narrow_run_step_path(run, step), params: { style_name: "Serene white-on-white" } }
        .to have_enqueued_job(ExecuteRunJob).with(run_id: run.id, mode: "rerun", run_step_id: step.id)

      expect(step.reload.context_override).to eq({ "style_name" => "Serene white-on-white" })
      expect(step.status).to eq("queued")
      expect(response).to redirect_to(run_path(run))
    end

    it "prefers a custom description over the selected cluster" do
      post narrow_run_step_path(run, step),
           params: { style_name: "ignored", custom_style_name: "cream wabi-sabi relief" }

      expect(step.reload.context_override).to eq({ "style_name" => "cream wabi-sabi relief" })
    end

    it "alerts when no scope is given" do
      post narrow_run_step_path(run, step)

      expect(response).to redirect_to(run_path(run))
      expect(flash[:alert]).to be_present
    end
  end

  describe "POST color_role_pick" do
    let(:step) do
      create(:run_step, pipeline_run_record: run, step_id: "A1b", position: 0, status: "awaiting_human")
    end

    it "stores the chosen role as a context override and re-runs A1b" do
      expect { post color_role_pick_run_step_path(run, step), params: { color_role: "saturator" } }
        .to have_enqueued_job(ExecuteRunJob).with(run_id: run.id, mode: "rerun", run_step_id: step.id)

      expect(step.reload.context_override).to eq("color_role_override" => "saturator")
      expect(step.status).to eq("queued")
      expect(response).to redirect_to(run_path(run))
    end

    it "rejects a blank role" do
      post color_role_pick_run_step_path(run, step), params: { color_role: "" }

      expect(response).to redirect_to(run_path(run))
      expect(flash[:alert]).to be_present
      expect(step.reload.context_override).to eq({})
    end
  end

  describe "POST references" do
    let(:step) do
      create(:run_step, pipeline_run_record: run, step_id: "C1", position: 0, status: "done")
    end

    it "stores the selected references and re-runs C1" do
      expect { post references_run_step_path(run, step),
                    params: { reference_images: %w[https://x/a.jpg https://x/b.jpg] } }
        .to have_enqueued_job(ExecuteRunJob).with(run_id: run.id, mode: "rerun", run_step_id: step.id)

      expect(step.reload.context_override).to eq("reference_images" => %w[https://x/a.jpg https://x/b.jpg])
      expect(step.status).to eq("queued")
    end

    it "merges pasted extra URLs and de-duplicates" do
      post references_run_step_path(run, step),
           params: { reference_images: "https://x/a.jpg",
                     extra_references: "https://x/b.jpg, https://x/a.jpg" }

      expect(step.reload.context_override["reference_images"]).to eq(%w[https://x/a.jpg https://x/b.jpg])
    end

    it "refuses an empty reference set" do
      post references_run_step_path(run, step), params: { reference_images: [] }

      expect(response).to redirect_to(run_path(run))
      expect(flash[:alert]).to be_present
      expect(step.reload.context_override).to eq({})
    end
  end

  describe "GET composer" do
    it "returns to the feedback composer" do
      get composer_run_step_path(run, step)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("step_feedback_#{step.id}")
      expect(response.body).to include("Interpret feedback")
    end
  end
end
