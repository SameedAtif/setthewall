require "rails_helper"

RSpec.describe "Notebook dossier", type: :system do
  it "renders the dossier, warns about stale cells, and disables approval" do
    run = create(:pipeline_run_record, run_id: "run_dossier_1", scope: "piece",
                                       dossier_markdown: "# Dossier\n\nWe propose a calm print.")
    create(:run_step, pipeline_run_record: run, step_id: "C1", position: 0, status: "stale")

    visit run_path(run)

    expect(page).to have_css(".markdown h1", text: "Dossier")
    expect(page).to have_text("We propose a calm print.")
    expect(page).to have_text("stale cell")
    expect(page).to have_button("Approve & commit", disabled: true)
  end
end
