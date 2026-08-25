require "rails_helper"

RSpec.describe Steps::Phase3::DraftTitle do
  def validate(title, first_six: title.to_s.split.first(6).join(" "))
    described_class.new(piece: nil, context: {}).send(:validate_title, title, { "first_six_words" => first_six }, {})
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

  it "rejects a mismatched first_six_words report" do
    expect(validate("Japandi minimalist line art print", first_six: "something else")).to include(a_string_matching(/first_six_words/))
  end

  it "accepts a clean, literal descriptor-first title" do
    expect(validate("Japandi minimalist line art print")).to be_empty
  end
end
