require "rails_helper"

RSpec.describe PerformanceSnapshot do
  it "returns zero conversion rate when there are no views" do
    expect(build(:performance_snapshot, views: 0, orders: 5).conversion_rate).to eq(0.0)
  end

  it "divides orders by views for conversion rate" do
    expect(build(:performance_snapshot, views: 100, orders: 2).conversion_rate).to be_within(0.001).of(0.02)
  end

  it "enforces uniqueness of captured_on per piece" do
    piece = create(:piece_record)
    create(:performance_snapshot, piece_record: piece, captured_on: Date.current)
    dup = build(:performance_snapshot, piece_record: piece, captured_on: Date.current)
    expect(dup).not_to be_valid
    expect(dup.errors[:captured_on]).to include("has already been taken")
  end
end
