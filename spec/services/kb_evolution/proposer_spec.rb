require "rails_helper"

RSpec.describe KbEvolution::Proposer do
  def write_export(cycle)
    path = Rails.root.join("tmp", "evolution", "#{cycle}_data.json")
    FileUtils.mkdir_p(File.dirname(path))
    path.write(JSON.generate("piece_count" => 3))
    path
  end

  it "raises when the export is missing" do
    expect { described_class.new(cycle_id: "nonexistent-#{SecureRandom.hex(4)}") }
      .to raise_error(KbEvolution::ProposalGenerationError)
  end

  it "persists proposals returned by the model" do
    cycle = "cycle-#{SecureRandom.hex(4)}"
    path = write_export(cycle)

    content = {
      "proposal_count" => 1,
      "proposals" => [{ "target_path" => "knowledge_base/rules/x.yml", "change_type" => "edit_snippet",
                        "old_snippet" => "a", "new_snippet" => "b", "rationale" => "r",
                        "evidence" => { "piece_ids" => [1, 2, 3] } }],
      "summary_notes" => ""
    }

    stub_llm(content: content) do
      proposals = described_class.call(cycle_id: cycle)
      expect(proposals.size).to eq(1)
      expect(proposals.first.target_path).to eq("knowledge_base/rules/x.yml")
    end
  ensure
    File.delete(path) rescue nil
  end

  it "skips invalid proposals" do
    cycle = "cycle-#{SecureRandom.hex(4)}"
    path = write_export(cycle)

    content = {
      "proposal_count" => 1,
      "proposals" => [{ "target_path" => "app/models/x.rb", "change_type" => "edit_snippet",
                        "old_snippet" => "a", "new_snippet" => "b", "rationale" => "r",
                        "evidence" => {} }],
      "summary_notes" => ""
    }

    stub_llm(content: content) do
      expect(described_class.call(cycle_id: cycle)).to be_empty
    end
  ensure
    File.delete(path) rescue nil
  end
end
