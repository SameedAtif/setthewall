require "rails_helper"

RSpec.describe Workflow::PreflightCheck do
  it "always returns a stamped version with allow_dirty and never raises" do
    result = described_class.call!(allow_dirty: true)
    expect(result.kb_version).to be_present
    expect(result.dirty).to eq(result.kb_version.start_with?("dirty:"))
  end

  it "stamps a dirty tree with allow_dirty" do
    marker = Pipeline::KB_ROOT.join("rules/.dirty_marker")
    File.write(marker, "x")
    begin
      result = described_class.call!(allow_dirty: true)
      expect(result.dirty).to be(true)
      expect(result.kb_version).to start_with("dirty:")
    ensure
      File.delete(marker) rescue nil
    end
  end

  it "refuses a dirty KB when allow_dirty is false" do
    marker = Pipeline::KB_ROOT.join("rules/.dirty_marker")
    File.write(marker, "x")
    begin
      expect { described_class.call! }.to raise_error(Workflow::DirtyKnowledgeBaseError)
    ensure
      File.delete(marker) rescue nil
    end
  end
end
