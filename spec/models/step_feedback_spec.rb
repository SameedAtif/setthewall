require "rails_helper"

RSpec.describe StepFeedback do
  it "validates role inclusion" do
    expect(build(:step_feedback, role: "robot")).not_to be_valid
  end

  it "requires a body" do
    expect(build(:step_feedback, body: "")).not_to be_valid
  end

  it "reports its role" do
    expect(build(:step_feedback, role: "assistant")).to be_assistant
    expect(build(:step_feedback, role: "system")).to be_system
    expect(build(:step_feedback, role: "human")).to be_human
  end
end
