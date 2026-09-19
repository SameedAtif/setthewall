require "rails_helper"

RSpec.describe Workflow::DossierRefresher do
  it "rebuilds the dossier markdown and broadcasts" do
    run = create(:pipeline_run_record)
    allow(Dossier::Builder).to receive(:call).and_return("# Fresh dossier")
    expect(Workflow::NotebookBroadcaster).to receive(:dossier).with(run)

    described_class.call(run: run)

    expect(run.reload.dossier_markdown).to eq("# Fresh dossier")
  end

  it "logs and does not raise when the builder fails" do
    run = create(:pipeline_run_record)
    allow(Dossier::Builder).to receive(:call).and_raise("boom")

    expect { described_class.call(run: run) }.not_to raise_error
  end
end
