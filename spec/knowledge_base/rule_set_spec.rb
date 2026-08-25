require "rails_helper"

RSpec.describe KnowledgeBase::RuleSet do
  it "raises MissingCitationError for an uncited rule file" do
    name = "test_uncited_#{SecureRandom.hex(4)}"
    path = Pipeline::KB_ROOT.join("rules", "#{name}.yml")
    path.write("meta:\n  source: x\nrules: {}\n")
    track_kb_file(path)
    KnowledgeBase::RuleSet.reset_cache!

    expect { described_class.load(name) }.to raise_error(KnowledgeBase::MissingCitationError)
  ensure
    KnowledgeBase::RuleSet.reset_cache!
  end

  it "raises RuleNotFoundError for a missing rule file" do
    expect { described_class.load("definitely-not-a-rule-#{SecureRandom.hex(4)}") }
      .to raise_error(KnowledgeBase::RuleNotFoundError)
  end

  it "returns a nested value via fetch" do
    expect(described_class.load("frame_material").fetch("metal_finish", "calm_warm", "finish")).to eq("gold")
  end

  it "raises on a missing fetch path rather than returning nil" do
    expect { described_class.load("frame_material").fetch("nope", "nope") }
      .to raise_error(KnowledgeBase::RuleNotFoundError)
  end

  it "reflects the volatility flag via live?" do
    expect(described_class.load("etsy_tags")).to be_live
    expect(described_class.load("frame_material")).not_to be_live
  end
end
