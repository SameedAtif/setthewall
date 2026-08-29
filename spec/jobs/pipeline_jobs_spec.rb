require "rails_helper"

RSpec.describe IdeateStylesJob do
  it "runs the ideation step and stores candidates" do
    content = {
      "candidates" => [{ "name" => "Warm minimal", "trend_signal" => "rising",
                         "independent_source_count" => 2, "sources" => [],
                         "competition_read" => "low" }],
      "survey_notes" => "sparse"
    }
    stub_reasoned_runner(content: content) do
      described_class.perform_now(direction: "calm", count: 3)
    end

    survey = IdeationSurvey.last
    expect(survey.status).to eq("complete")
    expect(survey.direction).to eq("calm")
    expect(survey.candidates.size).to eq(1)
    expect(survey.candidates.first["name"]).to eq("Warm minimal")
  end

  it "marks the survey failed when the step fails" do
    stub_singleton(Search::ReasonedRunner, :call, ->(**) { raise Search::NoSearchPerformedError }) do
      described_class.perform_now
    end
    expect(IdeationSurvey.last.status).to eq("failed")
  end

  it "marks the survey failed when an unexpected error is raised" do
    stub_singleton(Workflow::StepDispatcher, :call, ->(**) { raise "boom" }) do
      described_class.perform_now
    end
    survey = IdeationSurvey.last
    expect(survey.status).to eq("failed")
    expect(survey.last_error).to include("boom")
  end
end

RSpec.describe StartTrackJob do
  it "starts a Track A run" do
    stub_reasoned_runner(content: { "findings" => [], "recommended_style_focus" => "x", "methodology_caveats" => "" }) do
      described_class.perform_now(track: "track_a", style_slug: "x", style_name: "X")
    end
    run = TrackRun.last
    expect(run.style_slug).to eq("x")
    expect(run.status).to eq("awaiting_human")
    expect(run.current_step).to eq("A0")
  end
end

RSpec.describe ProposeJob do
  it "delegates to the proposer" do
    expect(KbEvolution::Proposer).to receive(:call).with(cycle_id: "cycle_x")
    described_class.perform_now(cycle_id: "cycle_x")
  end
end
