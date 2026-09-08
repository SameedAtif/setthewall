require "rails_helper"

RSpec.describe Art::PrintResolution do
  it "computes the honest max inches per dimension from the generator ceiling" do
    stub_singleton(described_class, :max_output_px, -> { 7200 }) do
      expect(described_class.max_inches_per_dimension).to eq(24.0)
    end
  end

  it "flags a size exceeding the ceiling" do
    stub_singleton(described_class, :max_output_px, -> { 6000 }) do
      expect(described_class.oversized?(width_in: 20, height_in: 21)).to be(true)
    end
  end

  it "passes a size exactly at the ceiling" do
    stub_singleton(described_class, :max_output_px, -> { 6000 }) do
      expect(described_class.oversized?(width_in: 20, height_in: 20)).to be(false)
    end
  end

  it "flags a 24x36 poster as needing 7200x10800 (beyond a 4096px generator)" do
    expect(described_class.max_output_px).to eq(4096)
    expect(described_class.oversized?(width_in: 24, height_in: 36)).to be(true)
  end
end
