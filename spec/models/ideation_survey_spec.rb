require "rails_helper"

RSpec.describe IdeationSurvey do
  it "validates status inclusion" do
    expect(build(:ideation_survey, status: "bogus")).not_to be_valid
  end

  it "is complete by default" do
    expect(build(:ideation_survey).status).to eq("complete")
  end
end
