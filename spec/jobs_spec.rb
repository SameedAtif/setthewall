require "rails_helper"

RSpec.describe ProcessPieceJob do
  it "refuses a dirty knowledge base" do
    piece = create(:piece_record, kb_version: "abc123")
    stub_singleton(Workflow::PreflightCheck, :call!, ->(*_a, **_k) { raise Workflow::DirtyKnowledgeBaseError, "dirty" }) do
      described_class.perform_now(piece_id: piece.id, step_id: "C1")
    end
    expect(piece.reload.status).to eq("failed")
    expect(piece.last_error).to eq("dirty")
  end

  it "skips preflight for an already-dirty run and advances on ok" do
    piece = create(:piece_record, kb_version: "dirty:test")
    ok_result = Steps::StepResult.new(status: :ok, data: {}, message: nil)
    stub_singleton(Workflow::StepDispatcher, :call, ->(**_k) { ok_result }) do
      stub_singleton(Workflow::PipelineRun, :next_step_after, ->(*_a, **_k) { "P2_1" }) do
        expect { described_class.perform_now(piece_id: piece.id, step_id: "C2") }
          .to have_enqueued_job(ProcessPieceJob).with(piece_id: piece.id, step_id: "P2_1")
      end
    end
  end

  it "does not advance when the step awaits a human" do
    piece = create(:piece_record, kb_version: "dirty:test")
    result = Steps::StepResult.new(status: :awaiting_human, data: {}, message: nil)
    stub_singleton(Workflow::StepDispatcher, :call, ->(**_k) { result }) do
      expect { described_class.perform_now(piece_id: piece.id, step_id: "C2") }
        .not_to have_enqueued_job(ProcessPieceJob)
    end
  end
end

RSpec.describe ResumePieceJob do
  it "no-ops on a rejected gate" do
    gate = create(:human_gate, status: "rejected")
    expect { described_class.perform_now(gate_id: gate.id) }.not_to have_enqueued_job(ProcessPieceJob)
  end

  it "enqueues the same step with a confirmed context on approve" do
    piece = create(:piece_record, :awaiting_human)
    gate = create(:human_gate, piece_record: piece, status: "approved", step_id: "P3_7",
                               context_snapshot: { "return_policy" => "x" })
    expect { described_class.perform_now(gate_id: gate.id) }
      .to have_enqueued_job(ProcessPieceJob).with(piece_id: piece.id, step_id: "P3_7",
                                                  context: hash_including(confirmed: true))
  end

  it "enqueues the same step for an edited gate" do
    piece = create(:piece_record, :awaiting_human)
    gate = create(:human_gate, piece_record: piece, status: "edited", step_id: "P3_2",
                               context_snapshot: {}, reviewer_edits: { "recommended_hero" => "u" })
    expect { described_class.perform_now(gate_id: gate.id) }
      .to have_enqueued_job(ProcessPieceJob).with(piece_id: piece.id, step_id: "P3_2",
                                                  context: hash_including(recommended_hero: "u"))
  end
end

RSpec.describe RefreshPerformanceSnapshotsJob do
  it "calls the stats fetcher for today" do
    captured = nil
    stub_singleton(Performance::EtsyStatsFetcher, :call, ->(**kwargs) { captured = kwargs }) do
      described_class.perform_now
    end
    expect(captured).to eq(date: Date.current)
  end
end
