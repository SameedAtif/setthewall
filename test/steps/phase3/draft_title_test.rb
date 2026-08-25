require "test_helper"

class DraftTitleTest < ActiveSupport::TestCase
  def validator
    @validator ||= Steps::Phase3::DraftTitle.new(piece: nil, context: {})
  end

  def validate(title, first_six: title.to_s.split.first(6).join(" "))
    validator.send(:validate_title, title, { "first_six_words" => first_six }, {})
  end

  test "rejects a blank title" do
    assert_includes validate(nil), "title blank"
  end

  test "rejects subjective adjectives" do
    errors = validate("Beautiful stunning japandi print")
    assert errors.any? { |e| e.include?("subjective") }
  end

  test "rejects a price signal" do
    errors = validate("Japandi print $30 wall art")
    assert errors.any? { |e| e.include?("price") }
  end

  test "rejects an ALL CAPS marketing phrase" do
    errors = validate("JAPANDI WALL ART PRINT stunning")
    assert errors.any? { |e| e.include?("ALL CAPS") }
  end

  test "rejects emoji" do
    errors = validate("Japandi wall art print 🎨")
    assert errors.any? { |e| e.include?("emoji") }
  end

  test "rejects a mismatched first_six_words report" do
    errors = validate("Japandi minimalist line art print", first_six: "something else entirely")
    assert errors.any? { |e| e.include?("first_six_words") }
  end

  test "accepts a clean, literal descriptor-first title" do
    assert_empty validate("Japandi minimalist line art print")
  end
end
