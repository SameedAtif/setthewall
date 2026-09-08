require "rails_helper"

RSpec.describe Steps::Phase3::DraftTitle do
  def validate(title)
    described_class.new(piece: nil, context: {}).send(:validate_title, title, {})
  end

  it "rejects a blank title" do
    expect(validate(nil)).to include("title blank")
  end

  it "rejects subjective adjectives" do
    expect(validate("Beautiful stunning japandi print")).to include(a_string_matching(/subjective/))
  end

  it "rejects a price signal" do
    expect(validate("Japandi print $30 wall art")).to include(a_string_matching(/price/))
  end

  it "rejects an ALL CAPS marketing phrase" do
    expect(validate("JAPANDI WALL ART PRINT stunning")).to include(a_string_matching(/ALL CAPS/))
  end

  it "rejects emoji" do
    expect(validate("Japandi wall art print 🎨")).to include(a_string_matching(/emoji/))
  end

  it "accepts a clean, literal descriptor-first title" do
    expect(validate("Japandi minimalist line art print")).to be_empty
  end

  it "retries once with the validator's message, then computes first_six_words in code" do
    piece = build_piece
    piece.save!

    calls = 0
    bad  = { "title" => "Beautiful stunning print", "occasion_word_included" => false, "reasoning" => "" }
    good = { "title" => "Japandi minimalist line art print", "occasion_word_included" => false, "reasoning" => "" }

    chat = Object.new
    chat.define_singleton_method(:with_schema) { |_s| chat }
    chat.define_singleton_method(:ask) do |_msg = nil, **_k|
      calls += 1
      Struct.new(:content).new(calls == 1 ? bad : good)
    end

    stub_singleton(RubyLLM, :chat, ->(*_a, **_k) { chat }) do
      result = described_class.call(piece: piece, context: {})
      expect(result).to be_ok
      expect(piece.reload.listing_title).to eq("Japandi minimalist line art print")
      expect(result.data[:first_six_words]).to eq("Japandi minimalist line art print")
    end
    expect(calls).to eq(2)
  end
end
