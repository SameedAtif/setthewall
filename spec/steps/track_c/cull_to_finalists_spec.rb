require "rails_helper"

RSpec.describe Steps::TrackC::CullToFinalists do
  def piece_with(candidates)
    create(:piece_record, candidate_urls: candidates)
  end

  it "fails when there are no candidates" do
    expect(described_class.call(piece: piece_with([]), context: {})).to be_failed
  end

  it "asks the human to cull when no finalists are proposed" do
    result = described_class.call(piece: piece_with(%w[a b c]), context: {})
    expect(result).to be_awaiting_human
    expect(result.message).to include("Cull the batch")
  end

  it "rejects finalists not present in the candidate set" do
    result = described_class.call(piece: piece_with(%w[a b c]), context: { finalist_urls: %w[a x] })
    expect(result).to be_failed
  end

  it "rejects more finalists than the absolute max" do
    result = described_class.call(piece: piece_with(%w[a b c d e]), context: { finalist_urls: %w[a b c d e] })
    expect(result).to be_failed
    expect(result.message).to include("absolute maximum")
  end

  it "persists finalists and asks for the chosen one" do
    piece = piece_with(%w[a b c d])
    result = described_class.call(piece: piece, context: { finalist_urls: %w[a b c] })
    expect(result).to be_awaiting_human
    expect(piece.reload.finalist_urls).to eq(%w[a b c])
  end

  it "completes when a chosen url is provided" do
    piece = piece_with(%w[a b c])
    result = described_class.call(piece: piece, context: { finalist_urls: %w[a b], chosen_url: "a" })
    expect(result).to be_ok
    expect(piece.reload.chosen_url).to eq("a")
  end

  it "rejects a chosen url not in finalists" do
    piece = piece_with(%w[a b c])
    result = described_class.call(piece: piece, context: { finalist_urls: %w[a b], chosen_url: "c" })
    expect(result).to be_failed
  end

  it "logs the chosen candidate's subject and pattern" do
    piece = create(:piece_record, candidate_urls: %w[a b c],
                                  candidate_subjects: %w[cottage moth moon],
                                  candidate_patterns: %w[p1 p2 p1])
    result = described_class.call(piece: piece, context: { finalist_urls: %w[a b], chosen_url: "b" })
    expect(result).to be_ok
    expect(piece.reload.chosen_subject).to eq("moth")
    expect(piece.reload.chosen_pattern).to eq("p2")
  end
end
