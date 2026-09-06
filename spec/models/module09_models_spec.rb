require "rails_helper"

RSpec.describe PipelineRunRecord do
  it "reports speculative and dossier-review state" do
    run = described_class.new(mode: "speculative", status: "awaiting_dossier_review", kb_version: "abc")
    expect(run.speculative?).to be(true)
    expect(run.awaiting_dossier_review?).to be(true)
  end
end

RSpec.describe QaFinding do
  it "reports severity" do
    expect(described_class.new(severity: "blocking").blocking?).to be(true)
    expect(described_class.new(severity: "advisory").advisory?).to be(true)
    expect(described_class.new(severity: "pass").pass?).to be(true)
  end
end
