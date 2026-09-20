require "rails_helper"

RSpec.describe Workflow::NotebookBroadcaster do
  let(:run) { create(:pipeline_run_record) }
  let(:step) { create(:run_step, pipeline_run_record: run, step_id: "A1", position: 0) }

  it "broadcasts a cell update on success without refreshing" do
    expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
    expect(Turbo::StreamsChannel).not_to receive(:broadcast_refresh_to)

    described_class.cell(run, step)
  end

  it "refreshes clients when a cell update fails to render" do
    allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to).and_raise("boom")
    expect(Turbo::StreamsChannel).to receive(:broadcast_refresh_to).with(run)

    described_class.cell(run, step)
  end

  it "refreshes clients when a header update fails to render" do
    allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to).and_raise("boom")
    expect(Turbo::StreamsChannel).to receive(:broadcast_refresh_to).with(run)

    described_class.header(run)
  end

  it "does not refresh when only a log line fails" do
    allow(Turbo::StreamsChannel).to receive(:broadcast_append_to).and_raise("boom")
    expect(Turbo::StreamsChannel).not_to receive(:broadcast_refresh_to)

    described_class.log(run, step, { "message" => "x" })
  end
end
