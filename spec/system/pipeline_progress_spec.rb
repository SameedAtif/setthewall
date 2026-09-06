require "rails_helper"

RSpec.describe "Pipeline progress", type: :system do
  it "renders the surveys turbo frame with polling and running progress" do
    create(:ideation_survey, status: "running", progress: "researching")

    visit root_path

    expect(page).to have_selector("[data-controller='pipeline-progress']")
    expect(page).to have_selector("#surveys")
    expect(page).to have_selector("[data-status='running']", text: "researching")
  end

  it "shows completed candidates once the survey finishes" do
    create(:ideation_survey, status: "complete",
                             candidates: [{ "name" => "Warm minimal", "trend_signal" => "rising",
                                            "independent_source_count" => 2, "competition_read" => "low" }])

    visit root_path

    expect(page).to have_selector("[data-status='complete']")
    expect(page).to have_text("Warm minimal")
  end
end
