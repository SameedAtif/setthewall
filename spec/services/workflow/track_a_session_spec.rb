require "rails_helper"

RSpec.describe Workflow::TrackASession do
  let(:slug) { "test-style-#{SecureRandom.hex(4)}" }

  after { described_class.reset!(slug) }

  it "returns a fresh session when no file exists" do
    session = described_class.load(slug)
    expect(session["decisions"]).to eq({})
    expect(session["last_completed_step"]).to be_nil
    expect(session["style_slug"]).to eq(slug)
  end

  it "records a step result and reloads it" do
    described_class.record_step_result!(slug, "A0", { "style_name_used" => "Ensō Ink" })

    session = described_class.load(slug)
    expect(session["decisions"]["A0"]["style_name_used"]).to eq("Ensō Ink")
    expect(session["last_completed_step"]).to eq("A0")
  end

  it "resets by deleting the session file" do
    described_class.record_step_result!(slug, "A0", { "x" => 1 })
    expect(described_class.path_for(slug).exist?).to be(true)

    described_class.reset!(slug)
    expect(described_class.path_for(slug).exist?).to be(false)
  end
end
